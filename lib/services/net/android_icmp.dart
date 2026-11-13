import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ping_prober.dart';

// Linux "ping sockets" (SOCK_DGRAM + IPPROTO_ICMP): unprivileged ICMP echo,
// what Android's own /system/bin/ping uses. Replaces spawning a ping process
// per probe: Dart forks the whole app synchronously on the calling thread to
// start a process, which blocked the UI thread for ~50 ms and stalled the
// raster thread on every probe (a hitch once a second while pinging).

typedef _SocketC = Int32 Function(Int32 domain, Int32 type, Int32 protocol);
typedef _SocketDart = int Function(int domain, int type, int protocol);
typedef _SetSockOptC = Int32 Function(Int32 fd, Int32 level, Int32 name, Pointer<Void> value, Uint32 len);
typedef _SetSockOptDart = int Function(int fd, int level, int name, Pointer<Void> value, int len);
typedef _SendToC = IntPtr Function(
  Int32 fd,
  Pointer<Uint8> buf,
  Size len,
  Int32 flags,
  Pointer<Uint8> addr,
  Uint32 alen,
);
typedef _SendToDart = int Function(int fd, Pointer<Uint8> buf, int len, int flags, Pointer<Uint8> addr, int alen);
typedef _RecvMsgC = IntPtr Function(Int32 fd, Pointer<_MsgHdr> msg, Int32 flags);
typedef _RecvMsgDart = int Function(int fd, Pointer<_MsgHdr> msg, int flags);
typedef _PollC = Int32 Function(Pointer<_PollFd> fds, Size n, Int32 timeoutMs);
typedef _PollDart = int Function(Pointer<_PollFd> fds, int n, int timeoutMs);
typedef _CloseC = Int32 Function(Int32 fd);
typedef _CloseDart = int Function(int fd);

final class _PollFd extends Struct {
  @Int32()
  external int fd;
  @Int16()
  external int events;
  @Int16()
  external int revents;
}

final class _IoVec extends Struct {
  external Pointer<Void> base;
  @Size()
  external int len;
}

final class _MsgHdr extends Struct {
  external Pointer<Void> name;
  @Uint32()
  external int nameLen;
  external Pointer<_IoVec> iov;
  @Size()
  external int iovLen;
  external Pointer<Void> control;
  @Size()
  external int controlLen;
  @Int32()
  external int flags;
}

const _afInet = 2, _sockDgram = 2, _ipprotoIcmp = 1, _solIp = 0;
const _ipTtl = 2, _ipRecvErr = 11, _ipRecvTtl = 12;
const _msgErrQueue = 0x2000, _msgDontWait = 0x40;
const _pollIn = 0x1, _pollErr = 0x8;
const _eeOriginIcmp = 2;

/// ICMP echo over an unprivileged Linux ping socket (IPv4), used on Android.
class AndroidIcmp {
  AndroidIcmp._();

  /// False once the kernel refused a ping socket (ping_group_range excludes
  /// the app); callers then fall back to the system `ping` binary.
  static bool available = Platform.isAndroid;

  static final _seq = math.Random();

  /// Null when ping sockets aren't allowed on this device.
  static Future<ProbeResult?> echo(
    InternetAddress destination, {
    required Duration timeout,
    int packetSize = 56,
    int ttl = 64,
  }) async {
    final raw = destination.rawAddress;
    final timeoutMs = timeout.inMilliseconds;
    final seq = _seq.nextInt(0xFFFF);
    final r = await Isolate.run(() => _echoSync(raw, timeoutMs, packetSize, ttl, seq));
    if (r == null) available = false;
    return r;
  }

  static ProbeResult? _echoSync(Uint8List dest, int timeoutMs, int size, int ttl, int seq) {
    final libc = DynamicLibrary.open('libc.so');
    final socket = libc.lookupFunction<_SocketC, _SocketDart>('socket');
    final setsockopt = libc.lookupFunction<_SetSockOptC, _SetSockOptDart>('setsockopt');
    final sendto = libc.lookupFunction<_SendToC, _SendToDart>('sendto');
    final recvmsg = libc.lookupFunction<_RecvMsgC, _RecvMsgDart>('recvmsg');
    final poll = libc.lookupFunction<_PollC, _PollDart>('poll');
    final close = libc.lookupFunction<_CloseC, _CloseDart>('close');

    final fd = socket(_afInet, _sockDgram, _ipprotoIcmp);
    if (fd < 0) return null;

    final opt = calloc<Int32>();
    final addr = calloc<Uint8>(16);
    final packet = calloc<Uint8>(8 + size);
    final pfd = calloc<_PollFd>();
    final buf = calloc<Uint8>(2048);
    final control = calloc<Uint8>(512);
    final from = calloc<Uint8>(16);
    final iov = calloc<_IoVec>();
    final msg = calloc<_MsgHdr>();
    try {
      void setInt(int name, int v) {
        opt.value = v;
        setsockopt(fd, _solIp, name, opt.cast(), 4);
      }

      setInt(_ipTtl, ttl.clamp(1, 255));
      setInt(_ipRecvErr, 1);
      setInt(_ipRecvTtl, 1);

      // sockaddr_in { u16 family; u16 port; u8 addr[4]; u8 zero[8] }
      addr[0] = _afInet & 0xFF;
      addr[1] = _afInet >> 8;
      for (var i = 0; i < 4; i++) {
        addr[4 + i] = dest[i];
      }

      // Echo request: type 8, code 0, checksum, id (kernel sets it), seq, payload.
      packet[0] = 8;
      packet[6] = seq >> 8;
      packet[7] = seq & 0xFF;
      for (var i = 0; i < size; i++) {
        packet[8 + i] = 0x61 + (i % 23);
      }
      final sum = _checksum(packet, 8 + size);
      packet[2] = sum >> 8;
      packet[3] = sum & 0xFF;

      final watch = Stopwatch()..start();
      if (sendto(fd, packet, 8 + size, 0, addr, 16) < 0) {
        return const ProbeResult(status: ProbeStatus.unreachable, message: 'Network unreachable');
      }

      pfd.ref
        ..fd = fd
        ..events = _pollIn;
      while (true) {
        final left = timeoutMs - watch.elapsedMilliseconds;
        if (left <= 0) return const ProbeResult(status: ProbeStatus.timeout);
        pfd.ref.revents = 0;
        final n = poll(pfd, 1, left);
        if (n <= 0) return const ProbeResult(status: ProbeStatus.timeout);
        final rtt = watch.elapsedMicroseconds / 1000;
        final errored = pfd.ref.revents & _pollErr != 0;

        iov.ref
          ..base = buf.cast()
          ..len = 2048;
        msg.ref
          ..name = from.cast()
          ..nameLen = 16
          ..iov = iov
          ..iovLen = 1
          ..control = control.cast()
          ..controlLen = 512
          ..flags = 0;
        final got = recvmsg(fd, msg, errored ? _msgErrQueue | _msgDontWait : _msgDontWait);
        if (got < 8) continue;

        if (errored) {
          // The queued error carries our original request: check it's ours.
          if (((buf[6] << 8) | buf[7]) != seq) continue;
          final err = _findCmsg(control, msg.ref.controlLen, _ipRecvErr);
          if (err == null) continue;
          // sock_extended_err { u32 errno; u8 origin; u8 type; u8 code; u8 pad;
          //   u32 info; u32 data; } followed by the offender's sockaddr_in.
          final origin = control[err + 4], type = control[err + 5];
          final offender = _ipv4(control, err + 16 + 4);
          if (origin != _eeOriginIcmp) continue;
          if (type == 11) return ProbeResult(status: ProbeStatus.ttlExceeded, rttMs: rtt, from: offender);
          if (type == 3) {
            return ProbeResult(status: ProbeStatus.unreachable, from: offender, message: 'Destination unreachable');
          }
          continue;
        }

        // Echo reply (ICMP header only on a ping socket): type 0, our seq.
        if (buf[0] != 0 || ((buf[6] << 8) | buf[7]) != seq) continue;
        final ttlAt = _findCmsg(control, msg.ref.controlLen, _ipTtl);
        final replyTtl = ttlAt == null ? null : (control + ttlAt).cast<Int32>().value;
        return ProbeResult(status: ProbeStatus.ok, rttMs: rtt, ttl: replyTtl, from: _ipv4(from, 4));
      }
    } finally {
      close(fd);
      for (final p in <Pointer>[opt, addr, packet, pfd, buf, control, from, iov, msg]) {
        calloc.free(p);
      }
    }
  }

  /// Offset of the data of the first IPPROTO_IP control message of [type].
  static int? _findCmsg(Pointer<Uint8> control, int len, int type) {
    final word = sizeOf<Size>();
    int align(int n) => (n + word - 1) & ~(word - 1);
    final header = align(word + 8); // cmsghdr { size_t len; int level; int type; }
    var off = 0;
    while (off + header <= len) {
      final p = control + off;
      final cmsgLen = word == 8 ? p.cast<Uint64>().value : p.cast<Uint32>().value;
      if (cmsgLen < header) return null;
      final level = (p + word).cast<Int32>().value;
      final t = (p + word + 4).cast<Int32>().value;
      if (level == _solIp && t == type) return off + header;
      off += align(cmsgLen);
    }
    return null;
  }

  static String _ipv4(Pointer<Uint8> p, int at) => '${p[at]}.${p[at + 1]}.${p[at + 2]}.${p[at + 3]}';

  static int _checksum(Pointer<Uint8> p, int len) {
    var sum = 0;
    for (var i = 0; i + 1 < len; i += 2) {
      sum += (p[i] << 8) | p[i + 1];
    }
    if (len.isOdd) sum += p[len - 1] << 8;
    while (sum >> 16 != 0) {
      sum = (sum & 0xFFFF) + (sum >> 16);
    }
    return ~sum & 0xFFFF;
  }
}

import 'dart:async';
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
///
/// One long-lived worker isolate runs every outstanding probe and waits on all
/// their sockets with a single poll(). (An Isolate.run per probe blocked in
/// poll() meant a LAN scan parked dozens of isolates in native calls, and the
/// VM's cap on active isolates then held the UI isolate back ~120 ms.)
class AndroidIcmp {
  AndroidIcmp._();

  /// False once the kernel refused a ping socket (ping_group_range excludes
  /// the app); callers then fall back to the system `ping` binary.
  static bool available = Platform.isAndroid;

  static final _seq = math.Random();
  static final _pending = <int, Completer<ProbeResult?>>{};
  static var _nextId = 0;
  static Future<SendPort>? _worker;

  /// Null when ping sockets aren't allowed on this device.
  static Future<ProbeResult?> echo(
    InternetAddress destination, {
    required Duration timeout,
    int packetSize = 56,
    int ttl = 64,
  }) async {
    final SendPort port;
    try {
      port = await (_worker ??= _spawn());
    } on Object {
      return null;
    }
    final id = _nextId++;
    final done = Completer<ProbeResult?>();
    _pending[id] = done;
    port.send(_Request(id, destination.rawAddress, timeout.inMilliseconds, packetSize, ttl, _seq.nextInt(0xFFFF)));
    final r = await done.future;
    if (r == null) available = false;
    return r;
  }

  static Future<SendPort> _spawn() async {
    final inbox = ReceivePort();
    final ready = Completer<SendPort>();
    inbox.listen((m) {
      switch (m) {
        case SendPort p:
          ready.complete(p);
        case (int id, ProbeResult? r):
          _pending.remove(id)?.complete(r);
        default:
          // The worker died (onError / onExit): hand what's in flight to the
          // process fallback, and start a fresh worker next time.
          _worker = null;
          inbox.close();
          for (final c in _pending.values) {
            c.complete(null);
          }
          _pending.clear();
          if (!ready.isCompleted) ready.completeError(StateError('ICMP worker failed: $m'));
      }
    });
    await Isolate.spawn(_workerMain, inbox.sendPort, onError: inbox.sendPort, onExit: inbox.sendPort);
    return ready.future;
  }
}

final class _Request {
  const _Request(this.id, this.dest, this.timeoutMs, this.size, this.ttl, this.seq);
  final int id, timeoutMs, size, ttl, seq;
  final Uint8List dest;
}

class _Probe {
  _Probe(this.request, this.fd) : watch = Stopwatch()..start();
  final _Request request;
  final int fd;
  final Stopwatch watch;
}

void _workerMain(SendPort out) {
  final libc = DynamicLibrary.open('libc.so');
  final socket = libc.lookupFunction<_SocketC, _SocketDart>('socket');
  final setsockopt = libc.lookupFunction<_SetSockOptC, _SetSockOptDart>('setsockopt');
  final sendto = libc.lookupFunction<_SendToC, _SendToDart>('sendto');
  final recvmsg = libc.lookupFunction<_RecvMsgC, _RecvMsgDart>('recvmsg');
  final poll = libc.lookupFunction<_PollC, _PollDart>('poll');
  final close = libc.lookupFunction<_CloseC, _CloseDart>('close');

  // Scratch buffers, reused for every probe (the worker is single-threaded).
  final opt = calloc<Int32>();
  final addr = calloc<Uint8>(16);
  final buf = calloc<Uint8>(2048);
  final control = calloc<Uint8>(512);
  final from = calloc<Uint8>(16);
  final iov = calloc<_IoVec>();
  final msg = calloc<_MsgHdr>();
  const maxFds = 256;
  final fds = calloc<_PollFd>(maxFds);

  final live = <_Probe>[];
  var looping = false;

  void finish(_Probe p, ProbeResult? r) {
    close(p.fd);
    live.remove(p);
    out.send((p.request.id, r));
  }

  void start(_Request q) {
    final fd = socket(_afInet, _sockDgram, _ipprotoIcmp);
    if (fd < 0) {
      out.send((q.id, null));
      return;
    }
    void setInt(int name, int v) {
      opt.value = v;
      setsockopt(fd, _solIp, name, opt.cast(), 4);
    }

    setInt(_ipTtl, q.ttl.clamp(1, 255));
    setInt(_ipRecvErr, 1);
    setInt(_ipRecvTtl, 1);

    // sockaddr_in { u16 family; u16 port; u8 addr[4]; u8 zero[8] }
    for (var i = 0; i < 16; i++) {
      addr[i] = 0;
    }
    addr[0] = _afInet & 0xFF;
    addr[1] = _afInet >> 8;
    for (var i = 0; i < 4; i++) {
      addr[4 + i] = q.dest[i];
    }

    // Echo request: type 8, code 0, checksum, id (the kernel sets it), seq, payload.
    final len = 8 + q.size;
    final packet = calloc<Uint8>(len);
    packet[0] = 8;
    packet[6] = q.seq >> 8;
    packet[7] = q.seq & 0xFF;
    for (var i = 0; i < q.size; i++) {
      packet[8 + i] = 0x61 + (i % 23);
    }
    final sum = _checksum(packet, len);
    packet[2] = sum >> 8;
    packet[3] = sum & 0xFF;

    final p = _Probe(q, fd);
    live.add(p);
    final sent = sendto(fd, packet, len, 0, addr, 16);
    calloc.free(packet);
    if (sent < 0) {
      finish(p, const ProbeResult(status: ProbeStatus.unreachable, message: 'Network unreachable'));
    }
  }

  /// Reads one queued reply or error for [p]; non-null once the probe is done.
  ProbeResult? read(_Probe p, bool errored) {
    final rtt = p.watch.elapsedMicroseconds / 1000;
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
    final got = recvmsg(p.fd, msg, errored ? _msgErrQueue | _msgDontWait : _msgDontWait);
    if (got < 8) return null;
    final seq = p.request.seq;
    if (errored) {
      // The queued error carries our original request: check it's ours.
      if (((buf[6] << 8) | buf[7]) != seq) return null;
      final err = _findCmsg(control, msg.ref.controlLen, _ipRecvErr);
      if (err == null) return null;
      // sock_extended_err { u32 errno; u8 origin; u8 type; u8 code; u8 pad;
      //   u32 info; u32 data; } followed by the offender's sockaddr_in.
      final origin = control[err + 4], type = control[err + 5];
      if (origin != _eeOriginIcmp) return null;
      final offender = _ipv4(control, err + 16 + 4);
      if (type == 11) return ProbeResult(status: ProbeStatus.ttlExceeded, rttMs: rtt, from: offender);
      if (type == 3) {
        return ProbeResult(status: ProbeStatus.unreachable, from: offender, message: 'Destination unreachable');
      }
      return null;
    }
    // Echo reply (only the ICMP header on a ping socket): type 0, our seq.
    if (buf[0] != 0 || ((buf[6] << 8) | buf[7]) != seq) return null;
    final ttlAt = _findCmsg(control, msg.ref.controlLen, _ipTtl);
    final ttl = ttlAt == null ? null : (control + ttlAt).cast<Int32>().value;
    return ProbeResult(status: ProbeStatus.ok, rttMs: rtt, ttl: ttl, from: _ipv4(from, 4));
  }

  Future<void> loop() async {
    looping = true;
    while (live.isNotEmpty) {
      final batch = live.take(maxFds).toList();
      // Short waits, so requests that arrive between iterations start promptly.
      var wait = 10;
      for (var i = 0; i < batch.length; i++) {
        final p = batch[i];
        fds[i]
          ..fd = p.fd
          ..events = _pollIn
          ..revents = 0;
        wait = math.min(wait, math.max(0, p.request.timeoutMs - p.watch.elapsedMilliseconds));
      }
      final n = poll(fds, batch.length, wait);
      for (var i = 0; i < batch.length; i++) {
        final p = batch[i];
        final ev = n > 0 ? fds[i].revents : 0;
        if (ev & (_pollIn | _pollErr) != 0) {
          final r = read(p, ev & _pollErr != 0);
          if (r != null) {
            finish(p, r);
            continue;
          }
        }
        if (p.watch.elapsedMilliseconds >= p.request.timeoutMs) {
          finish(p, const ProbeResult(status: ProbeStatus.timeout));
        }
      }
      await Future<void>.delayed(Duration.zero);
    }
    looping = false;
  }

  final inbox = ReceivePort();
  inbox.listen((m) {
    start(m as _Request);
    if (!looping && live.isNotEmpty) loop();
  });
  out.send(inbox.sendPort);
}

/// Offset of the data of the first IPPROTO_IP control message of [type].
int? _findCmsg(Pointer<Uint8> control, int len, int type) {
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

String _ipv4(Pointer<Uint8> p, int at) => '${p[at]}.${p[at + 1]}.${p[at + 2]}.${p[at + 3]}';

int _checksum(Pointer<Uint8> p, int len) {
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

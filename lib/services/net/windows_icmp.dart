import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ping_prober.dart';

// iphlpapi.dll — IcmpCreateFile / IcmpSendEcho / IcmpCloseHandle.
typedef _IcmpCreateFileC = IntPtr Function();
typedef _IcmpCreateFileDart = int Function();
typedef _IcmpCloseHandleC = Int32 Function(IntPtr handle);
typedef _IcmpCloseHandleDart = int Function(int handle);
typedef _IcmpSendEchoC =
    Uint32 Function(
      IntPtr handle,
      Uint32 destination,
      Pointer<Uint8> requestData,
      Uint16 requestSize,
      Pointer<_IpOptionInformation> options,
      Pointer<Uint8> replyBuffer,
      Uint32 replySize,
      Uint32 timeout,
    );
typedef _IcmpSendEchoDart =
    int Function(
      int handle,
      int destination,
      Pointer<Uint8> requestData,
      int requestSize,
      Pointer<_IpOptionInformation> options,
      Pointer<Uint8> replyBuffer,
      int replySize,
      int timeout,
    );

final class _IpOptionInformation extends Struct {
  @Uint8()
  external int ttl;
  @Uint8()
  external int tos;
  @Uint8()
  external int flags;
  @Uint8()
  external int optionsSize;
  external Pointer<Uint8> optionsData;
}

final class _IcmpEchoReply extends Struct {
  @Uint32()
  external int address;
  @Uint32()
  external int status;
  @Uint32()
  external int roundTripTime;
  @Uint16()
  external int dataSize;
  @Uint16()
  external int reserved;
  external Pointer<Uint8> data;
  external _IpOptionInformation options;
}

// IP_STATUS codes (ipexport.h).
const _ipSuccess = 0;
const _ipDestNetUnreachable = 11002;
const _ipDestHostUnreachable = 11003;
const _ipDestProtUnreachable = 11004;
const _ipDestPortUnreachable = 11005;
const _ipReqTimedOut = 11010;
const _ipTtlExpiredTransit = 11013;
const _ipTtlExpiredReassem = 11014;

/// ICMP echo through the Windows ICMP API (IPv4). Gives exact round-trip
/// times for both echo replies and TTL-expired replies, without spawning a
/// `ping` process per probe.
class WindowsIcmp {
  WindowsIcmp._();

  static bool get available => Platform.isWindows;

  static Future<ProbeResult> echo(
    InternetAddress destination, {
    required Duration timeout,
    int packetSize = 32,
    int ttl = 128,
  }) {
    final bytes = destination.rawAddress;
    final dest = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    final timeoutMs = timeout.inMilliseconds;
    return Isolate.run(() => _echoSync(dest, timeoutMs, packetSize, ttl));
  }

  static ProbeResult _echoSync(int dest, int timeoutMs, int size, int ttl) {
    final lib = DynamicLibrary.open('iphlpapi.dll');
    final create = lib.lookupFunction<_IcmpCreateFileC, _IcmpCreateFileDart>('IcmpCreateFile');
    final close = lib.lookupFunction<_IcmpCloseHandleC, _IcmpCloseHandleDart>('IcmpCloseHandle');
    final send = lib.lookupFunction<_IcmpSendEchoC, _IcmpSendEchoDart>('IcmpSendEcho');

    final handle = create();
    if (handle == -1 || handle == 0) {
      return const ProbeResult(status: ProbeStatus.error, message: 'ICMP handle unavailable');
    }
    final request = calloc<Uint8>(size == 0 ? 1 : size);
    for (var i = 0; i < size; i++) {
      request[i] = 0x61 + (i % 23);
    }
    final options = calloc<_IpOptionInformation>();
    options.ref
      ..ttl = ttl.clamp(1, 255)
      ..tos = 0
      ..flags = 0
      ..optionsSize = 0
      ..optionsData = nullptr;
    final replySize = sizeOf<_IcmpEchoReply>() + size + 8 + 128;
    final reply = calloc<Uint8>(replySize);
    try {
      final count = send(handle, dest, request, size, options, reply, replySize, timeoutMs);
      if (count == 0) return const ProbeResult(status: ProbeStatus.timeout);
      final r = reply.cast<_IcmpEchoReply>().ref;
      final from = InternetAddress.fromRawAddress(
        Uint8List.fromList([
          r.address & 0xFF,
          (r.address >> 8) & 0xFF,
          (r.address >> 16) & 0xFF,
          (r.address >> 24) & 0xFF,
        ]),
      ).address;
      // The API reports whole milliseconds; 0 means "under a millisecond".
      final rtt = r.roundTripTime == 0 ? 0.5 : r.roundTripTime.toDouble();
      switch (r.status) {
        case _ipSuccess:
          return ProbeResult(status: ProbeStatus.ok, rttMs: rtt, ttl: r.options.ttl, from: from);
        case _ipTtlExpiredTransit:
        case _ipTtlExpiredReassem:
          return ProbeResult(status: ProbeStatus.ttlExceeded, rttMs: rtt, from: from);
        case _ipDestNetUnreachable:
        case _ipDestHostUnreachable:
        case _ipDestProtUnreachable:
        case _ipDestPortUnreachable:
          return ProbeResult(
            status: ProbeStatus.unreachable,
            from: from,
            message: 'Destination unreachable',
          );
        case _ipReqTimedOut:
          return const ProbeResult(status: ProbeStatus.timeout);
        default:
          return ProbeResult(status: ProbeStatus.error, message: 'ICMP status ${r.status}');
      }
    } finally {
      close(handle);
      calloc.free(request);
      calloc.free(options);
      calloc.free(reply);
    }
  }
}

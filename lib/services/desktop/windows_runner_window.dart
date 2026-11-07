import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _FindWindowExC = IntPtr Function(IntPtr parent, IntPtr after, Pointer<Utf16> className, Pointer<Utf16> title);
typedef _FindWindowExDart = int Function(int parent, int after, Pointer<Utf16> className, Pointer<Utf16> title);
typedef _GetWindowThreadProcessIdC = Uint32 Function(IntPtr hwnd, Pointer<Uint32> processId);
typedef _GetWindowThreadProcessIdDart = int Function(int hwnd, Pointer<Uint32> processId);
typedef _GetCurrentProcessIdC = Uint32 Function();
typedef _GetCurrentProcessIdDart = int Function();

/// Must match kWindowClassName in windows/runner/win32_window.cpp.
const _runnerWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

/// HWND of this process's Flutter window, or 0 if there is none.
///
/// Pulse's window stays hidden until Dart shows it (and for good when launched
/// at login), which nativeapi cannot see: `WindowManager.getCurrent()` asks for
/// the active window and `getAll()` skips hidden ones. The process check keeps
/// a second running copy of Pulse from being picked up.
int findRunnerWindow() {
  final user32 = DynamicLibrary.open('user32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final findWindowEx = user32.lookupFunction<_FindWindowExC, _FindWindowExDart>('FindWindowExW');
  final windowProcessId = user32.lookupFunction<_GetWindowThreadProcessIdC, _GetWindowThreadProcessIdDart>(
    'GetWindowThreadProcessId',
  );
  final currentProcessId = kernel32.lookupFunction<_GetCurrentProcessIdC, _GetCurrentProcessIdDart>(
    'GetCurrentProcessId',
  );

  final className = _runnerWindowClass.toNativeUtf16();
  final processId = calloc<Uint32>();
  try {
    final self = currentProcessId();
    var hwnd = 0;
    while (true) {
      hwnd = findWindowEx(0, hwnd, className, nullptr);
      if (hwnd == 0) return 0;
      windowProcessId(hwnd, processId);
      if (processId.value == self) return hwnd;
    }
  } finally {
    calloc.free(className);
    calloc.free(processId);
  }
}

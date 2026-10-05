#ifndef RUNNER_STARTUP_TASK_H_
#define RUNNER_STARTUP_TASK_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// `pulse/launch_at_login` channel for MSIX builds: launch at login goes
// through the package's StartupTask (declared in the MSIX manifest) because
// registry Run keys written from a package are virtualised and never seen by
// Windows.
void RegisterStartupTaskChannel(flutter::BinaryMessenger* messenger, HWND window);

// Delivers replies posted back from the worker thread. Returns true when the
// message was a startup-task reply.
bool HandleStartupTaskMessage(UINT message, WPARAM wparam, LPARAM lparam);

#endif  // RUNNER_STARTUP_TASK_H_

#include "startup_task.h"

#include <appmodel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.h>

#include <memory>
#include <string>
#include <thread>

namespace {

// Must match `startup_task.task_id` in pubspec.yaml's msix_config.
constexpr wchar_t kTaskId[] = L"PulseStartup";
constexpr UINT kStartupTaskReply = WM_APP + 0x51;

using Result = flutter::MethodResult<flutter::EncodableValue>;

struct Reply {
  std::unique_ptr<Result> result;
  int state = -1;
  std::string error;
};

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;
HWND g_window = nullptr;

bool IsPackaged() {
  UINT32 length = 0;
  return GetCurrentPackageFullName(&length, nullptr) != APPMODEL_ERROR_NO_PACKAGE;
}

enum class Action { kQuery, kEnable, kDisable };

// WinRT's blocking get() is not allowed on the STA UI thread, so the call
// runs on a worker and the reply is posted back to the window thread, where
// Flutter requires channel replies to be sent.
void RunOnWorker(std::unique_ptr<Result> result, Action action) {
  std::thread([r = std::move(result), action]() mutable {
    auto* reply = new Reply{std::move(r)};
    try {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
      using winrt::Windows::ApplicationModel::StartupTask;
      StartupTask task = StartupTask::GetAsync(kTaskId).get();
      auto state = task.State();
      if (action == Action::kEnable) {
        state = task.RequestEnableAsync().get();
      } else if (action == Action::kDisable) {
        task.Disable();
        state = task.State();
      }
      reply->state = static_cast<int>(state);
    } catch (winrt::hresult_error const& e) {
      reply->error = winrt::to_string(e.message());
    } catch (...) {
      reply->error = "StartupTask call failed";
    }
    if (!g_window || !PostMessage(g_window, kStartupTaskReply, 0, reinterpret_cast<LPARAM>(reply))) {
      delete reply;
    }
  }).detach();
}

}  // namespace

void RegisterStartupTaskChannel(flutter::BinaryMessenger* messenger, HWND window) {
  g_window = window;
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "pulse/launch_at_login", &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                     std::unique_ptr<Result> result) {
    const std::string& method = call.method_name();
    if (method == "isPackaged") {
      result->Success(flutter::EncodableValue(IsPackaged()));
      return;
    }
    if (!IsPackaged()) {
      result->Error("NOT_PACKAGED", "Startup tasks need the MSIX package");
      return;
    }
    if (method == "getState") {
      RunOnWorker(std::move(result), Action::kQuery);
    } else if (method == "setEnabled") {
      bool enabled = false;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end()) {
          if (const auto* b = std::get_if<bool>(&it->second)) enabled = *b;
        }
      }
      RunOnWorker(std::move(result), enabled ? Action::kEnable : Action::kDisable);
    } else {
      result->NotImplemented();
    }
  });
}

bool HandleStartupTaskMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message != kStartupTaskReply) return false;
  std::unique_ptr<Reply> reply(reinterpret_cast<Reply*>(lparam));
  if (!reply->error.empty()) {
    reply->result->Error("STARTUP_TASK", reply->error);
  } else {
    reply->result->Success(flutter::EncodableValue(reply->state));
  }
  return true;
}

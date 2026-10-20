#include "customize_window.h"

#include <flutter/standard_method_codec.h>
#include <shobjidl.h>

#include <optional>
#include <string>

#include "app_messages.h"
#include "login_item.h"

namespace {

std::string ToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                       static_cast<int>(wide.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string utf8(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      utf8.data(), size, nullptr, nullptr);
  return utf8;
}

}  // namespace

CustomizeWindow::CustomizeWindow(const flutter::DartProject& project)
    : project_(project) {}

std::wstring CustomizeWindow::PickImage() {
  IFileOpenDialog* dialog = nullptr;
  if (FAILED(CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog)))) {
    return {};
  }
  const COMDLG_FILTERSPEC filters[] = {
      {L"Pictures", L"*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif"},
  };
  dialog->SetFileTypes(ARRAYSIZE(filters), filters);
  dialog->SetTitle(L"Choose a photo for your charm");
  DWORD options = 0;
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_FILEMUSTEXIST | FOS_FORCEFILESYSTEM);

  std::wstring path;
  if (SUCCEEDED(dialog->Show(GetHandle()))) {
    IShellItem* item = nullptr;
    if (SUCCEEDED(dialog->GetResult(&item))) {
      PWSTR chosen = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &chosen))) {
        path = chosen;
        CoTaskMemFree(chosen);
      }
      item->Release();
    }
  }
  dialog->Release();
  return path;
}

CustomizeWindow::~CustomizeWindow() {}

bool CustomizeWindow::OnCreate() {
  RECT frame = GetClientArea();
  controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!controller_->engine() || !controller_->view()) {
    return false;
  }
  SetChildContent(controller_->view()->GetNativeWindow());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      controller_->engine()->messenger(), "charm/customize",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleCall(call, std::move(result));
  });

  // Appear once there is something to show, not as an empty frame.
  controller_->engine()->SetNextFrameCallback([this]() { Show(); });
  controller_->ForceRedraw();
  return true;
}

void CustomizeWindow::OnDestroy() {
  channel_ = nullptr;
  controller_ = nullptr;
  Win32Window::OnDestroy();
}

void CustomizeWindow::HandleCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "toCharm") {
    // A JSON message for the charm. False if the charm isn't running.
    const auto* json = std::get_if<std::string>(call.arguments());
    if (!json) {
      result->Error("bad_args", "toCharm expects a JSON string");
      return;
    }
    const bool sent =
        app_messages::Send(app_messages::Find(app_messages::kCharmTitle),
                           GetHandle(), app_messages::kToCharm, *json);
    result->Success(flutter::EncodableValue(sent));
  } else if (method == "getLaunchAtLogin") {
    result->Success(flutter::EncodableValue(login_item::IsEnabled()));
  } else if (method == "setLaunchAtLogin") {
    const auto* enabled = std::get_if<bool>(call.arguments());
    if (!enabled) {
      result->Error("bad_args", "setLaunchAtLogin expects a bool");
      return;
    }
    result->Success(flutter::EncodableValue(login_item::SetEnabled(*enabled)));
  } else if (method == "pickImage") {
    // The standard Windows "Open" dialog, images only. Returns the chosen
    // file's path, or null if the person cancels.
    const std::wstring path = PickImage();
    if (path.empty()) {
      result->Success();
    } else {
      result->Success(flutter::EncodableValue(ToUtf8(path)));
    }
  } else if (method == "close") {
    PostMessage(GetHandle(), WM_CLOSE, 0, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

LRESULT CustomizeWindow::MessageHandler(HWND hwnd, UINT const message,
                                        WPARAM const wparam,
                                        LPARAM const lparam) noexcept {
  if (controller_) {
    std::optional<LRESULT> result =
        controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  switch (message) {
    case WM_COPYDATA: {
      std::string json;
      if (!app_messages::Receive(wparam, lparam, app_messages::kToCustomize,
                                 &json)) {
        return FALSE;
      }
      if (channel_) {
        channel_->InvokeMethod("fromCharm",
                               std::make_unique<flutter::EncodableValue>(json));
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      if (controller_) controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      const double scale = GetDpiForWindow(hwnd) / 96.0;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = static_cast<LONG>(kMinWidth * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(kMinHeight * scale);
      return 0;
    }
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

import 'dart:ffi' show Pointer;
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:nativeapi/nativeapi.dart' show Application;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'windows_runner_window.dart';

/// Desktop window + system tray. The app window opens as the 720×440 launch
/// window, grows to the full app once booted, and hides to the tray on close
/// while monitoring is on.
class DesktopHost {
  DesktopHost._();
  static final instance = DesktopHost._();

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  late final Window _window;
  tray.TrayIcon? _icon;
  tray.MenuItem? _pauseItem;
  bool _alert = false;
  bool _closeToTray = true;
  bool _hidden = false;
  bool _quitting = false;
  bool _toldAboutTray = false;

  VoidCallback? onShow;
  VoidCallback? onTogglePause;
  VoidCallback? onQuit;

  /// Called for the one-time "still running in the tray" hint.
  void Function(String message)? onHint;

  static const launchSize = Size(720, 440);
  static const appSize = Size(1280, 800);
  static const minSize = Size(420, 640);

  /// [hidden]: launched at login — boot straight into the tray.
  void initWindow({bool hidden = false}) {
    final window = _findWindow();
    if (window == null) throw StateError('The Pulse window was not found');
    _window = window;
    window
      ..addListener(_onWindowEvent)
      ..title = 'Pulse'
      ..titleBarStyle = TitleBarStyle.hidden
      ..setSize(launchSize.toNative(), false)
      ..center()
      ..backgroundColor = Colors.transparent.toNative()
      ..isResizable = false;
    if (Platform.isLinux) {
      // Windows and macOS take the icon from the runner resources.
      final dir = File(Platform.resolvedExecutable).parent.path;
      Application.instance.setIcon('$dir/data/flutter_assets/assets/brand/icon/windows/app_icon_48.png');
    }
    if (hidden) {
      _hidden = true;
      return;
    }
    window
      ..show()
      ..focus();
  }

  Window? _findWindow() {
    if (!Platform.isWindows) return WindowManager.instance.getCurrent();
    final hwnd = findRunnerWindow();
    return hwnd == 0 ? null : Window.createWithNativeWindow(Pointer.fromAddress(hwnd));
  }

  /// Grows the launch window into the normal app window.
  void openAppWindow() {
    final display = _workArea();
    final size = display == null
        ? appSize
        : Size(
            appSize.width.clamp(minSize.width, display.width * 0.92),
            appSize.height.clamp(minSize.height, display.height * 0.92),
          );
    _window
      ..titleBarStyle = TitleBarStyle.normal
      ..isWindowControlButtonsVisible = true
      ..isResizable = true
      ..minimumSize = minSize.toNative()
      ..setSize(size.toNative(), false)
      ..center();
  }

  Size? _workArea() => DisplayManager.instance.getPrimary()?.workArea.toRect().size;

  void initTray() {
    final icon = tray.TrayIcon.create();
    if (icon == null) return;
    _icon = icon;
    _applyIcon();
    icon.setTooltip('Pulse');
    icon.addListener((event) {
      if (event is tray.TrayIconClickedEvent || event is tray.TrayIconDoubleClickedEvent) show();
    });
    final menu = tray.Menu.create()!;
    final showItem = tray.MenuItem.createWithLabelAndType('Show Pulse', tray.MenuItemType.normal)!;
    showItem.addListener((e) {
      if (e is tray.MenuItemClickedEvent) show();
    });
    final pause = tray.MenuItem.createWithLabelAndType('Pause monitoring', tray.MenuItemType.normal)!;
    pause.addListener((e) {
      if (e is tray.MenuItemClickedEvent) onTogglePause?.call();
    });
    _pauseItem = pause;
    final quit = tray.MenuItem.createWithLabelAndType('Quit Pulse', tray.MenuItemType.normal)!;
    quit.addListener((e) {
      if (e is tray.MenuItemClickedEvent) this.quit();
    });
    menu
      ..addItem(showItem)
      ..addItem(pause)
      ..addSeparator()
      ..addItem(quit);
    icon.setContextMenu(menu);
    // The default trigger is none: without this a right-click opens nothing.
    icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
    icon.setVisible(true);
  }

  void _applyIcon() {
    final icon = _icon;
    if (icon == null) return;
    if (Platform.isMacOS && !_alert) {
      icon.icon = tray.ImageAsset.fromAsset('assets/brand/tray/tray_template.png');
      icon.isIconTemplate = true;
      return;
    }
    icon.isIconTemplate = false;
    final name = _alert ? 'tray_alert' : 'tray_normal';
    icon.icon = tray.ImageAsset.fromAsset('assets/brand/tray/$name.${Platform.isWindows ? 'ico' : 'png'}');
  }

  /// Monitoring status in the tooltip; [alert] swaps to the signal icon.
  void setStatus(String text, {required bool alert, required bool paused}) {
    final icon = _icon;
    if (icon == null) return;
    if (alert != _alert) {
      _alert = alert;
      _applyIcon();
    }
    icon.setTooltip('Pulse · $text');
    _pauseItem?.label = paused ? 'Resume monitoring' : 'Pause monitoring';
  }

  void setCloseToTray(bool v) => _closeToTray = v;

  void show() {
    _hidden = false;
    if (_window.isMinimized) _window.restore();
    _window
      ..show()
      ..focus();
    onShow?.call();
  }

  void quit() {
    if (_quitting) return;
    _shutdown();
    if (!Window.isCloseSupported() || !_window.close()) Application.instance.quit(0);
  }

  void _shutdown() {
    _quitting = true;
    onQuit?.call();
    _icon?.dispose();
    _icon = null;
  }

  bool get hidden => _hidden;

  void _onWindowEvent(WindowEvent event) {
    if (event is! WindowCloseRequestedEvent || _quitting) return;
    // Without a tray icon there would be no way back to a hidden window.
    if (!_closeToTray || _icon == null) {
      _shutdown();
      return;
    }
    event.request.cancel();
    _hidden = true;
    _window.hide();
    if (!_toldAboutTray) {
      _toldAboutTray = true;
      onHint?.call('Pulse keeps monitoring in the tray. Right-click the tray icon to quit.');
    }
  }
}

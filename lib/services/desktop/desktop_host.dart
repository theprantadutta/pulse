import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

/// Desktop window + system tray. The app window opens as the 720×440 launch
/// window, grows to the full app once booted, and hides to the tray on close
/// while monitoring is on.
class DesktopHost with WindowListener {
  DesktopHost._();
  static final instance = DesktopHost._();

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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
  Future<void> initWindow({bool hidden = false}) async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: launchSize,
        center: true,
        title: 'Pulse',
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
      ),
      () async {
        await windowManager.setResizable(false);
        if (hidden) {
          _hidden = true;
          return;
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  /// Grows the launch window into the normal app window.
  Future<void> openAppWindow() async {
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(minSize);
    final display = await _workArea();
    final size = display == null
        ? appSize
        : Size(
            appSize.width.clamp(minSize.width, display.width * 0.92),
            appSize.height.clamp(minSize.height, display.height * 0.92),
          );
    await windowManager.setSize(size);
    await windowManager.center();
  }

  Future<Size?> _workArea() async {
    try {
      final d = await screenRetriever.getPrimaryDisplay();
      return d.visibleSize ?? d.size;
    } on Object {
      return null;
    }
  }

  Future<void> initTray() async {
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

  Future<void> setCloseToTray(bool v) async {
    _closeToTray = v;
    await windowManager.setPreventClose(v);
  }

  Future<void> show() async {
    _hidden = false;
    await windowManager.show();
    await windowManager.focus();
    onShow?.call();
  }

  Future<void> quit() async {
    _quitting = true;
    onQuit?.call();
    _icon?.dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  bool get hidden => _hidden;

  @override
  Future<void> onWindowClose() async {
    if (_quitting) return;
    if (_closeToTray && await windowManager.isPreventClose()) {
      _hidden = true;
      await windowManager.hide();
      if (!_toldAboutTray) {
        _toldAboutTray = true;
        onHint?.call('Pulse keeps monitoring in the tray. Right-click the tray icon to quit.');
      }
      return;
    }
    await quit();
  }
}

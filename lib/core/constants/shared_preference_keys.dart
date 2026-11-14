const kThemeModeKey = 'wire.theme_mode';
const kAccentKey = 'pulse.accent';
const kDynamicColorKey = 'pulse.dynamic_color';
const kExpressiveMotionKey = 'pulse.expressive_motion';
const kPingCountKey = 'wire.ping.count';
const kPingIntervalKey = 'wire.ping.interval_ms';
const kPingTimeoutKey = 'wire.ping.timeout_s';
const kPacketSizeKey = 'wire.ping.packet_size';
const kIpVersionKey = 'wire.ping.ip_version';
const kSlowThresholdKey = 'wire.ping.slow_ms';
const kSaveAsDefaultKey = 'wire.ping.save_default';
const kMonitorIntervalKey = 'wire.monitor.interval_s';
const kMonitorBackgroundKey = 'wire.monitor.background';
const kCloseToTrayKey = 'wire.monitor.close_to_tray';
const kLaunchAtStartupKey = 'wire.monitor.launch_at_startup';
const kNotificationsKey = 'wire.notify.enabled';
const kNotificationSoundKey = 'wire.notify.sound';
const kRetentionDaysKey = 'wire.data.retention_days';
const kExportFormatKey = 'wire.data.export_format';
const kExportFolderKey = 'wire.data.export_folder';
const kPublicIpLookupsKey = 'wire.privacy.public_ip';
const kLanDeviceWatchKey = 'wire.monitor.lan_watch';
const kMonitorPausedKey = 'wire.monitor.paused';
const kAlertsMutedUntilKey = 'wire.alerts.muted_until';
const kRecentTargetsKey = 'wire.ping.recent_targets';
const kQuickTargetsKey = 'wire.ping.quick_targets';

/// Written by the pre-Wire app; migrated once then removed.
const kLegacyIsDarkModeKey = 'is_dark_mode_key';
const kLegacyFlexSchemeKey = 'is_flex_scheme_key';

/// In-app updates and reviews (lib/services/store/).
const kUpdateLastCheckKey = 'pulse.update.last_check';
const kUpdatePromptedKey = 'pulse.update.prompted'; // "version|epochMs"
const kReviewMomentsKey = 'pulse.review.moments';
const kReviewFirstMomentKey = 'pulse.review.first_moment';
const kReviewLastAskedKey = 'pulse.review.last_asked';
const kReviewTimesAskedKey = 'pulse.review.times_asked';

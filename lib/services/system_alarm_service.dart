import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alarm_clock/flutter_alarm_clock.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 系统闹钟服务：在 Android 系统闹钟应用中创建闹钟
/// - Android 11 及以下：可直接使用 skipUi: true 静默创建
/// - Android 12 及以上：需 SCHEDULE_EXACT_ALARM 权限
class SystemAlarmService {
  SystemAlarmService._();
  static final SystemAlarmService instance = SystemAlarmService._();

  /// 是否支持系统闹钟（仅 Android）
  bool get isSupported => Platform.isAndroid;

  /// 检查 Android 12+ 的精确闹钟权限
  /// 返回 true 表示可使用 skipUi: true，false 表示需降级为 skipUi: false
  Future<bool> _hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await ph.Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 打开「闹钟与提醒」权限设置页（设置 -> 隐私/安全 -> 特殊应用权限 -> 闹钟和提醒）
  /// 使用 ACTION_REQUEST_SCHEDULE_EXACT_ALARM 跳转到正确位置，而非通用应用设置页
  Future<bool> openAlarmPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:${packageInfo.packageName}',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('SystemAlarmService.openAlarmPermissionSettings error: $e');
      // 降级：打开通用应用设置页
      return ph.openAppSettings();
    }
  }

  /// 创建系统闹钟
  /// [hour] 小时 0-23
  /// [minute] 分钟 0-59
  /// [title] 闹钟标题（可选）
  /// [context] 用于弹窗，若需降级且用户拒绝去设置时使用 skipUi: false
  ///
  /// 返回：true 表示成功创建，false 表示未创建（如非 Android 或用户去设置页）
  Future<bool> createAlarm({
    required int hour,
    required int minute,
    String title = '',
    BuildContext? context,
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final hasPermission = await _hasExactAlarmPermission();
      bool useSkipUi = hasPermission;

      if (!hasPermission && context != null && context.mounted) {
        final shouldRequest = await _showPermissionDialog(
          context: context,
          getPermissionTitle: getPermissionTitle,
          getPermissionMessage: getPermissionMessage,
          getGoToSettingsLabel: getGoToSettingsLabel,
          getCancelLabel: getCancelLabel,
        );
        if (!context.mounted) return false;
        if (shouldRequest == true) {
          await openAlarmPermissionSettings();
          return false; // 用户去设置，不在此处创建，返回后用户可再次保存
        }
        if (shouldRequest == false) {
          useSkipUi = false; // 用户选择取消，降级为跳转系统闹钟界面
        }
      } else if (!hasPermission) {
        useSkipUi = false;
      }

      FlutterAlarmClock.createAlarm(
        hour: hour,
        minutes: minute,
        title: title,
        skipUi: useSkipUi,
      );
      return true;
    } catch (e) {
      debugPrint('SystemAlarmService.createAlarm error: $e');
      return false;
    }
  }

  /// 显示权限引导弹窗
  /// 返回：true=用户点击去设置，false=用户选择取消（降级），null=用户关闭弹窗
  Future<bool?> _showPermissionDialog({
    required BuildContext context,
    required String Function() getPermissionTitle,
    required String Function() getPermissionMessage,
    required String Function() getGoToSettingsLabel,
    required String Function() getCancelLabel,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(getPermissionTitle()),
        content: Text(getPermissionMessage()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(getCancelLabel()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(getGoToSettingsLabel()),
          ),
        ],
      ),
    );
  }
}

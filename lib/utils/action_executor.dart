import 'package:flutter/services.dart';

import '../models/task_entity.dart';
import '../services/config_service.dart';
import 'app_launcher.dart';
import 'meeting_utils.dart';

/// 根据任务的动作类型执行导航、拨号、打开网页、加入会议或准备消息。
class ActionExecutor {
  /// 可选：用于显示提示信息（如“消息已复制”），未设置时使用 print。
  static void Function(String message)? onShowMessage;

  static void _show(String message) {
    if (onShowMessage != null) {
      onShowMessage!(message);
    } else {
      print(message);
    }
  }

  /// 根据 [item] 执行对应动作，返回是否执行成功。
  static Future<bool> executeActionItem(
    String type,
    String? data,
    String? target,
  ) async {
    _lastTencentNotInstalled = false;
    final d = data?.trim();
    if (type.isEmpty) {
      print('ActionExecutor: actionType is null or empty');
      return false;
    }
    if (d == null || d.isEmpty) {
      print('ActionExecutor: actionData is null or empty for type=$type');
      return false;
    }

    switch (type) {
      case 'navigation':
        return _launchNavigation(d, target?.trim().isNotEmpty == true ? target!.trim() : null);
      case 'phone':
        return _makePhoneCall(d);
      case 'web':
        return _openWeb(d);
      case 'meeting':
        return _joinMeeting(d, target?.trim().isNotEmpty == true ? target!.trim() : null);
      case 'message':
        return _prepareMessage(d, target?.trim().isNotEmpty == true ? target!.trim() : null);
      default:
        print('ActionExecutor: unknown actionType=$type');
        return false;
    }
  }

  /// 根据 [task] 的第一个动作执行（兼容旧 API）。
  static Future<bool> executeAction(TaskEntity task) async {
    final acts = task.actions;
    if (acts == null || acts.isEmpty) return false;
    final a = acts.first;
    return executeActionItem(a.type, a.data, a.target);
  }

  /// 打开导航：高德 / 百度 / Google；未指定 target 时按优先级尝试，失败则降级网页。
  /// 跳转逻辑由 AppLauncher 统一处理（Android 用 Intent，iOS 用 URL Scheme）。
  static Future<bool> _launchNavigation(String address, String? target) async {
    final encoded = Uri.encodeComponent(address);

    if (target != null) {
      switch (target.toLowerCase()) {
        case 'gaode':
          if (await AppLauncher.launch('amapuri://route/plan/?dname=$encoded')) return true;
          if (await AppLauncher.launch('iosamap://path?dname=$encoded')) return true;
          break;
        case 'baidu':
          if (await AppLauncher.launch('baidumap://map/direction?destination=$encoded')) return true;
          break;
        case 'google':
          if (await AppLauncher.launch('https://www.google.com/maps/search/?api=1&query=$encoded')) return true;
          if (await AppLauncher.launch('geo:0,0?q=$encoded')) return true;
          break;
      }
    }

    // 未指定 target 或指定方案失败：按优先级尝试
    final order = target != null ? [target.toLowerCase()] : ['gaode', 'baidu', 'google'];
    for (final t in order) {
      switch (t) {
        case 'gaode':
          if (await AppLauncher.launch('amapuri://route/plan/?dname=$encoded')) return true;
          if (await AppLauncher.launch('iosamap://path?dname=$encoded')) return true;
          break;
        case 'baidu':
          if (await AppLauncher.launch('baidumap://map/direction?destination=$encoded')) return true;
          break;
        case 'google':
          if (await AppLauncher.launch('https://www.google.com/maps/search/?api=1&query=$encoded')) return true;
          if (await AppLauncher.launch('geo:0,0?q=$encoded')) return true;
          break;
      }
    }

    // 降级到网页版（Google Maps 搜索）
    return AppLauncher.launch('https://www.google.com/maps/search/?api=1&query=$encoded');
  }

  /// 拨打电话，使用 tel: scheme，并做简单号码格式校验。
  static Future<bool> _makePhoneCall(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (digits.isEmpty || digits.length < 3) {
      print('ActionExecutor: invalid phone length: $phone');
      return false;
    }
    final hasDigits = RegExp(r'[\d+]').hasMatch(digits);
    if (!hasDigits) {
      print('ActionExecutor: no digits in phone: $phone');
      return false;
    }
    return AppLauncher.launch('tel:$phone');
  }

  /// 打开网页（AppLauncher 内部区分平台）。
  static Future<bool> _openWeb(String url) async {
    String toOpen = url.trim();
    if (!toOpen.contains('://')) toOpen = 'https://$toOpen';
    return AppLauncher.launch(toOpen);
  }

  /// 加入会议：支持腾讯会议、Zoom、钉钉；采用深度链接降级（Scheme → 网页）。
  /// 腾讯会议：支持从文本或 URL 提取会议号，统一用 wemeet scheme 打开。
  static Future<bool> _joinMeeting(String data, String? platform) async {
    final trimmed = data.trim();
    final p = (platform ?? 'tencent').toLowerCase();

    // 腾讯会议 URL：不直接打开，提取会议号后走 scheme（与输入 680-161-638 逻辑一致）
    if (p == 'tencent' &&
        (trimmed.toLowerCase().startsWith('https://meeting.tencent.com') ||
            trimmed.toLowerCase().startsWith('http://meeting.tencent.com'))) {
      return await _joinTencentMeeting(trimmed);
    }

    // 其他完整 URL（wemeet/zoom/dingtalk 等）直接打开
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://') ||
        trimmed.toLowerCase().startsWith('wemeet://') ||
        trimmed.toLowerCase().startsWith('zoommtg://') ||
        trimmed.toLowerCase().startsWith('dingtalk://')) {
      return AppLauncher.launch(trimmed);
    }

    switch (p) {
      case 'tencent':
        return await _joinTencentMeeting(trimmed);
      case 'zoom':
        return await _joinZoomMeeting(trimmed);
      case 'dingtalk':
        return await _joinDingtalkMeeting(trimmed);
      default:
        return await _joinTencentMeeting(trimmed);
    }
  }

  /// 腾讯会议：优先提取会议号拼装 scheme（与输入 680-161-638 逻辑一致）。
  /// 支持：纯会议号、腾讯会议：xxx、腾讯会议 URL（从 URL 提取会议号）。
  static Future<bool> _joinTencentMeeting(String data) async {
    // 1. 从文本提取会议号（纯会议号、腾讯会议：680-161-638 等）
    var meetingNumber = MeetingUtils.extractMeetingNumber(data);

    // 2. 若为腾讯会议 URL，从 URL 中提取会议号
    if (meetingNumber == null) {
      final url = MeetingUtils.extractUrl(data);
      if (url != null) {
        meetingNumber = MeetingUtils.extractMeetingCodeFromTencentUrl(url);
      }
    }

    if (meetingNumber != null) {
      final scheme = ConfigService.instance.tencentMeetingScheme;
      final url = scheme + meetingNumber;
      final ok = await AppLauncher.launch(url);
      if (!ok) {
        _lastTencentNotInstalled = true;
      }
      return ok;
    }

    return false;
  }

  /// 腾讯会议未安装时设为 true，供 UI 显示专用提示。
  static bool _lastTencentNotInstalled = false;
  static bool get lastTencentNotInstalled => _lastTencentNotInstalled;

  /// Zoom：提取会议号或 URL。
  static Future<bool> _joinZoomMeeting(String data) async {
    final meetingNumber = MeetingUtils.extractMeetingNumber(data);
    if (meetingNumber != null) {
      return await AppLauncher.launchWithFallback(
        'zoommtg://zoom.us/join?confno=$meetingNumber',
        'https://zoom.us/j/$meetingNumber',
      );
    }
    final url = MeetingUtils.extractUrl(data);
    if (url != null) return AppLauncher.launch(url);
    return false;
  }

  /// 钉钉会议。
  static Future<bool> _joinDingtalkMeeting(String data) async {
    final meetingNumber = MeetingUtils.extractMeetingNumber(data);
    if (meetingNumber != null) {
      return AppLauncher.launch(
        'dingtalk://dingtalk.com/page/meeting?meetingCode=$meetingNumber',
      );
    }
    final url = MeetingUtils.extractUrl(data);
    if (url != null) return AppLauncher.launch(url);
    return false;
  }

  /// 复制消息到剪贴板，尝试打开微信，并提示用户粘贴发送。
  static Future<bool> _prepareMessage(String message, String? contact) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      _show('消息已复制，请在微信中粘贴发送');
      await AppLauncher.launch('weixin://'); // 未安装时忽略，复制已成功
      return true;
    } catch (e) {
      print('ActionExecutor: prepareMessage failed: $e');
      return false;
    }
  }
}

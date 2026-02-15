import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task_entity.dart';

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

  /// 根据 [task] 的 actionType 执行对应动作，返回是否执行成功。
  static Future<bool> executeAction(TaskEntity task) async {
    final type = task.actionType;
    final data = task.actionData?.trim();
    final target = task.actionTarget?.trim();

    if (type == null || type.isEmpty) {
      print('ActionExecutor: actionType is null or empty');
      return false;
    }
    if (data == null || data.isEmpty) {
      print('ActionExecutor: actionData is null or empty for type=$type');
      return false;
    }

    switch (type) {
      case 'navigation':
        return _launchNavigation(data, target?.isNotEmpty == true ? target : null);
      case 'phone':
        return _makePhoneCall(data);
      case 'web':
        return _openWeb(data);
      case 'meeting':
        return _joinMeeting(data, target?.isNotEmpty == true ? target : null);
      case 'message':
        return _prepareMessage(data, target?.isNotEmpty == true ? target : null);
      default:
        print('ActionExecutor: unknown actionType=$type');
        return false;
    }
  }

  /// 打开导航：高德 / 百度 / Google；未指定 target 时按优先级尝试，失败则降级网页。
  static Future<bool> _launchNavigation(String address, String? target) async {
    final encoded = Uri.encodeComponent(address);

    Future<bool> tryLaunch(String url) async {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('ActionExecutor: launch failed $url: $e');
      }
      return false;
    }

    if (target != null) {
      switch (target.toLowerCase()) {
        case 'gaode':
          if (await tryLaunch('amapuri://route/plan/?dname=$encoded')) return true;
          if (await tryLaunch('iosamap://path?dname=$encoded')) return true;
          break;
        case 'baidu':
          if (await tryLaunch('baidumap://map/direction?destination=$encoded')) return true;
          break;
        case 'google':
          if (await tryLaunch('https://www.google.com/maps/search/?api=1&query=$encoded')) return true;
          if (await tryLaunch('geo:0,0?q=$encoded')) return true;
          break;
      }
    }

    // 未指定 target 或指定方案失败：按优先级尝试
    final order = target != null ? [target.toLowerCase()] : ['gaode', 'baidu', 'google'];
    for (final t in order) {
      switch (t) {
        case 'gaode':
          if (await tryLaunch('amapuri://route/plan/?dname=$encoded')) return true;
          if (await tryLaunch('iosamap://path?dname=$encoded')) return true;
          break;
        case 'baidu':
          if (await tryLaunch('baidumap://map/direction?destination=$encoded')) return true;
          break;
        case 'google':
          if (await tryLaunch('https://www.google.com/maps/search/?api=1&query=$encoded')) return true;
          if (await tryLaunch('geo:0,0?q=$encoded')) return true;
          break;
      }
    }

    // 降级到网页版（Google Maps 搜索）
    return tryLaunch('https://www.google.com/maps/search/?api=1&query=$encoded');
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
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('ActionExecutor: makePhoneCall failed: $e');
    }
    return false;
  }

  /// 使用 url_launcher 打开网页，externalApplication。
  static Future<bool> _openWeb(String url) async {
    String toOpen = url.trim();
    if (!toOpen.contains('://')) {
      toOpen = 'https://$toOpen';
    }
    try {
      final uri = Uri.parse(toOpen);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('ActionExecutor: openWeb failed: $e');
    }
    return false;
  }

  /// 加入会议：支持腾讯会议、Zoom、钉钉；data 为完整 URL 时直接打开，否则按 platform 构建。
  static Future<bool> _joinMeeting(String data, String? platform) async {
    final trimmed = data.trim();

    Future<bool> tryLaunch(String url) async {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('ActionExecutor: launch meeting failed $url: $e');
      }
      return false;
    }

    // 已是完整 URL
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://') ||
        trimmed.toLowerCase().startsWith('wemeet://') ||
        trimmed.toLowerCase().startsWith('zoommtg://') ||
        trimmed.toLowerCase().startsWith('dingtalk://')) {
      return tryLaunch(trimmed);
    }

    // 会议号，按 platform 构建
    final p = (platform ?? 'tencent').toLowerCase();
    switch (p) {
      case 'tencent':
        return tryLaunch('wemeet://meeting/join?meeting_no=$trimmed') ||
            tryLaunch('https://meeting.tencent.com/p/$trimmed');
      case 'zoom':
        return tryLaunch('zoommtg://zoom.us/join?confno=$trimmed') ||
            tryLaunch('https://zoom.us/j/$trimmed');
      case 'dingtalk':
        return tryLaunch('dingtalk://dingtalk.com/page/meeting?meetingCode=$trimmed');
      default:
        return tryLaunch('wemeet://meeting/join?meeting_no=$trimmed') ||
            tryLaunch('https://meeting.tencent.com/p/$trimmed');
    }
  }

  /// 复制消息到剪贴板，尝试打开微信，并提示用户粘贴发送。
  static Future<bool> _prepareMessage(String message, String? contact) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      _show('消息已复制，请在微信中粘贴发送');
      try {
        final uri = Uri.parse('weixin://');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        // 未安装微信时忽略，复制已成功
      }
      return true;
    } catch (e) {
      print('ActionExecutor: prepareMessage failed: $e');
      return false;
    }
  }
}

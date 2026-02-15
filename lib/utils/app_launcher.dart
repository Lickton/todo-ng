import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

// 仅在 Android 上调用，避免在 iOS 上 invoke 导致崩溃
import 'package:android_intent_plus/android_intent.dart' as android_plugin;
import 'package:android_intent_plus/flag.dart' as android_flag;

/// 跨平台「打开外部链接/应用」抽象。
/// - iOS：使用 url_launcher（URL Scheme）。
/// - Android：对应用 scheme（会议、地图、通讯等）优先使用 Intent；其余用 url_launcher，失败时 Intent 兜底。
class AppLauncher {
  AppLauncher._();

  /// 在 Android 上应优先使用 Intent 的应用 scheme（避免 url_launcher 对自定义 scheme 检测受限）。
  static const _androidIntentSchemes = ['wemeet://', 'zoommtg://', 'dingtalk://', 'amapuri://', 'iosamap://', 'baidumap://', 'weixin://', 'mqq://'];

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// 是否为自定义 scheme（非 http/https/tel/mailto 等系统通用协议）
  static bool _isCustomScheme(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return false;
    if (lower.startsWith('tel:') || lower.startsWith('mailto:') || lower.startsWith('geo:')) return false;
    return lower.contains('://');
  }

  /// 在 Android 上是否应优先使用 Intent（应用 scheme）
  static bool _shouldUseIntentOnAndroid(String url) {
    final lower = url.trim().toLowerCase();
    return _androidIntentSchemes.any((s) => lower.startsWith(s));
  }

  /// 尝试打开 [url]（网页、电话、或应用 scheme）。返回是否成功。
  static Future<bool> launch(String url) async {
    final uri = Uri.parse(url.trim());
    final isCustom = _isCustomScheme(url);
    final trimmed = url.trim();

    // Android + 应用 scheme：优先使用 Intent，避免 url_launcher 对自定义 scheme 检测受限
    if (_isAndroid && _shouldUseIntentOnAndroid(trimmed)) {
      try {
        final intent = android_plugin.AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: trimmed,
          flags: <int>[android_flag.Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        return true;
      } catch (e) {
        print('AppLauncher: Android Intent failed $url: $e');
      }
      return false;
    }

    // 先尝试 url_launcher（iOS 或通用协议，或 Android 非应用 scheme）
    if (!_isAndroid || !isCustom) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
        // 对 http/https 再试一次直接 launch（部分浏览器/机型下 canLaunchUrl 不可靠）
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('http://') || lower.startsWith('https://')) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (e) {
        print('AppLauncher: url_launcher failed $url: $e');
      }
    } else {
      // Android + 其他自定义 scheme：先尝试 url_launcher
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (_) {}
    }

    // Android：url_launcher 失败时用 Intent 兜底（部分机型如 MIUI 上 url_launcher 对 tel: 等返回 component null）
    if (_isAndroid) {
      try {
        final intent = android_plugin.AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: trimmed,
          flags: <int>[android_flag.Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        return true;
      } catch (e) {
        print('AppLauncher: Android Intent failed $url: $e');
      }
    }

    return false;
  }

  /// 深度链接降级：先尝试 [primaryUrl]（如 App scheme），失败则打开 [fallbackUrl]（如网页）。
  /// - Android：对应用 scheme 使用 canResolveActivity 预检查，无处理者则直接回退网页。
  /// - iOS：使用 canLaunchUrl 预检查（需在 Info.plist 配置 LSApplicationQueriesSchemes）。
  static Future<bool> launchWithFallback(String primaryUrl, String fallbackUrl) async {
    final primary = primaryUrl.trim();
    final fallback = fallbackUrl.trim();

    if (_isAndroid && _shouldUseIntentOnAndroid(primary)) {
      try {
        final intent = android_plugin.AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: primary,
          flags: <int>[android_flag.Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        final canResolve = await intent.canResolveActivity() == true;
        if (canResolve) {
          await intent.launch();
          return true;
        }
      } catch (e) {
        print('AppLauncher: Intent launch failed $primary: $e');
      }
      return launch(fallback);
    }

    if (!_isAndroid) {
      try {
        final uri = Uri.parse(primary);
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (e) {
        print('AppLauncher: scheme launch failed $primary: $e');
      }
      return launch(fallback);
    }

    if (await launch(primary)) return true;
    return launch(fallback);
  }

  /// 深度链接降级（多 Scheme）：依次尝试 [primaryUrls]，全部失败则打开 [fallbackUrl]。
  /// 每个 scheme 会做 canResolveActivity / canLaunchUrl 预检查，避免无效尝试。
  static Future<bool> launchWithFallbackMulti(
    List<String> primaryUrls,
    String fallbackUrl,
  ) async {
    for (final primary in primaryUrls) {
      final ok = await _tryLaunchScheme(primary.trim());
      if (ok) return true;
    }
    return launch(fallbackUrl.trim());
  }

  /// 尝试启动 scheme，成功返回 true；失败（无处理者或异常）返回 false，不打开其他链接。
  static Future<bool> _tryLaunchScheme(String url) async {
    if (_isAndroid && _shouldUseIntentOnAndroid(url)) {
      try {
        final intent = android_plugin.AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: url,
          flags: <int>[android_flag.Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        if (await intent.canResolveActivity() != true) return false;
        await intent.launch();
        return true;
      } catch (e) {
        print('AppLauncher: _tryLaunchScheme failed $url: $e');
        return false;
      }
    }
    if (!_isAndroid) {
      try {
        final uri = Uri.parse(url);
        if (!await canLaunchUrl(uri)) return false;
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('AppLauncher: _tryLaunchScheme failed $url: $e');
        return false;
      }
    }
    return launch(url);
  }

  /// 仅当可打开时才打开（先检测再 launch）。用于不希望「尝试失败」的场景。
  static Future<bool> launchIfSupported(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('AppLauncher: launchIfSupported failed $url: $e');
    }
    return false;
  }
}

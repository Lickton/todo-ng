import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 配置服务：持久化应用偏好（语言等），供全局使用。
class ConfigService {
  ConfigService._();

  static const String _keyLocale = 'app_locale';
  static const String _keyTencentMeetingScheme = 'tencent_meeting_scheme';
  static const String _keyDefaultPhonePrefix = 'default_phone_prefix';

  /// 腾讯会议 URL Scheme 前缀，可配置。默认 wemeet://page/inmeeting?meeting_code=
  static const String defaultTencentMeetingScheme =
      'wemeet://page/inmeeting?meeting_code=';

  /// 默认电话国家码前缀，如 +86
  static const String defaultPhonePrefixValue = '+86';

  /// 支持的语言代码。null 表示跟随系统。
  static const String localeSystem = 'system';
  static const String localeEn = 'en';
  static const String localeZh = 'zh';

  static final ConfigService _instance = ConfigService._();
  static ConfigService get instance => _instance;

  SharedPreferences? _prefs;
  String? _cachedLocaleCode;

  /// 初始化，应在 main() 中尽早调用。
  static Future<void> init() async {
    instance._prefs ??= await SharedPreferences.getInstance();
    instance._cachedLocaleCode = instance._prefs!.getString(_keyLocale);
    instance.localeNotifier.value = instance.localeCode;
  }

  /// 当前保存的语言代码：'en' | 'zh' | 'system'
  String get localeCode => _cachedLocaleCode ?? localeSystem;

  /// 腾讯会议 Scheme 前缀，用于拼装会议链接。
  String get tencentMeetingScheme =>
      _prefs?.getString(_keyTencentMeetingScheme) ?? defaultTencentMeetingScheme;

  /// 设置腾讯会议 Scheme 前缀。
  Future<void> setTencentMeetingScheme(String scheme) async {
    await _prefs?.setString(_keyTencentMeetingScheme, scheme);
  }

  /// 默认电话前缀（如 +86），用于电话动作输入。
  String get defaultPhonePrefix =>
      _prefs?.getString(_keyDefaultPhonePrefix) ?? defaultPhonePrefixValue;

  /// 设置默认电话前缀。
  Future<void> setDefaultPhonePrefix(String prefix) async {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return;
    await _prefs?.setString(_keyDefaultPhonePrefix, trimmed);
  }

  /// 当前实际使用的 Locale（用于 MaterialApp.locale）。
  Locale? get effectiveLocale {
    final code = localeCode;
    if (code == localeSystem) return null;
    if (code == localeZh) return const Locale('zh');
    if (code == localeEn) return const Locale('en');
    return null;
  }

  /// 设置显示语言并持久化，并通知监听者重建 UI。
  Future<void> setLocale(String code) async {
    if (code != localeEn && code != localeZh && code != localeSystem) return;
    await _prefs?.setString(_keyLocale, code);
    _cachedLocaleCode = code;
    localeNotifier.value = code;
  }

  /// 监听语言变化，用于触发应用重建。
  final ValueNotifier<String> localeNotifier = ValueNotifier<String>(localeSystem);
}

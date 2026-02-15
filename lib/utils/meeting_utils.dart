/// 会议相关工具：从文本中提取会议号、URL 等。
class MeetingUtils {
  MeetingUtils._();

  /// 从文本中提取会议号（纯数字，已去除分隔符）。
  /// 支持：
  /// 1. 纯会议号：如 680-161-638、680161638
  /// 2. 中文冒号后：如 腾讯会议：680-161-638、会议号：680-161-638
  static String? extractMeetingNumber(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    // 1. 纯会议号：整串只有数字和分隔符（-、空格）
    final pureDigits = t.replaceAll(RegExp(r'[\s\-]'), '');
    if (pureDigits.isNotEmpty &&
        RegExp(r'^\d+$').hasMatch(pureDigits) &&
        pureDigits.length >= 6) {
      return pureDigits;
    }

    // 2. 中文冒号后提取：腾讯会议：680-161-638 或 会议号：680-161-638
    final match = RegExp(r'[：:]\s*([\d\s\-]+)').firstMatch(t);
    if (match != null) {
      final digits = match.group(1)!.replaceAll(RegExp(r'[\s\-]'), '');
      if (digits.length >= 6) return digits;
    }

    return null;
  }

  /// 从腾讯会议 URL 中提取会议号。
  /// 支持：?code=680161638、/dm/680161638 等格式。
  static String? extractMeetingCodeFromTencentUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (!uri.host.toLowerCase().contains('meeting.tencent.com')) return null;

      // 1. 查询参数 code
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        final digits = code.replaceAll(RegExp(r'[\s\-]'), '');
        if (RegExp(r'^\d+$').hasMatch(digits) && digits.length >= 6) {
          return digits;
        }
      }

      // 2. 路径 /dm/会议号 或 /dm/join-by-code 等
      final pathSegments = uri.pathSegments;
      for (final seg in pathSegments) {
        final digits = seg.replaceAll(RegExp(r'[\s\-]'), '');
        if (RegExp(r'^\d+$').hasMatch(digits) && digits.length >= 6) {
          return digits;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 从文本中提取可打开的 URL（http/https/wemeet/zoommtg/dingtalk 等）。
  static String? extractUrl(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    final urlMatch = RegExp(
      r'(https?://\S+|wemeet://\S+|zoommtg://\S+|dingtalk://\S+)',
    ).firstMatch(t);
    if (urlMatch != null) {
      return urlMatch.group(0)!.trim();
    }
    return null;
  }

  /// 文本是否包含有效的会议数据（会议号或 URL）。
  static bool hasValidMeetingData(String text) {
    return extractMeetingNumber(text) != null || extractUrl(text) != null;
  }
}

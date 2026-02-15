/// URL Scheme 常量及构建方法，用于调起系统/第三方应用（地图、会议、通讯等）。
class UrlSchemes {
  UrlSchemes._();

  // ========== 导航应用 ==========

  /// 高德地图：打开骑行导航并传入目的地地址（需在地址后拼接具体地址文本）。
  static const String GAODE_MAP =
      'amapuri://openFeature?featureName=OnRideNavigation&sourceApplication=todo&address=';

  /// 百度地图：路径规划，destination 需拼接 name:目的地名称 或 latlng:纬度,经度。
  static const String BAIDU_MAP =
      'baidumap://map/direction?destination=name:目的地|latlng:';

  /// Google 地图（geo 协议）：系统级地理搜索，后接地址或经纬度。
  static const String GOOGLE_MAP_GEO = 'geo:0,0?q=';

  /// Google 地图（网页）：浏览器打开地图搜索，后接编码后的查询字符串。
  static const String GOOGLE_MAP_WEB = 'https://maps.google.com/?q=';

  // ========== 会议平台 ==========

  /// 腾讯会议：通过会议号加入会议。
  static const String TENCENT_MEETING = 'wemeet://page/inmeeting?meeting_code=';

  /// Zoom：通过会议号加入会议。
  static const String ZOOM_MEETING = 'zoommtg://zoom.us/join?confno=';

  /// 钉钉：通过会议 ID 打开视频会议页面。
  static const String DINGTALK_MEETING =
      'dingtalk://dingtalkclient/page/videoConfFromCalendar?confId=';

  // ========== 通讯工具 ==========

  /// 微信：仅打开微信主界面，无法直接指定会话。
  static const String WECHAT = 'weixin://';

  /// QQ：打开 QQ 客户端。
  static const String QQ = 'mqq://';

  /// 钉钉：打开钉钉内链接，url 需为编码后的目标地址。
  static const String DINGTALK_CHAT = 'dingtalk://dingtalkclient/page/link?url=';

  // ========== 工具方法 ==========

  /// 构建高德地图导航 URL。将 [address] 进行编码后拼接到 GAODE_MAP 后。
  static String buildGaodeNavUrl(String address) {
    return GAODE_MAP + Uri.encodeComponent(address);
  }

  /// 构建腾讯会议加入 URL。[meetingId] 为会议号。
  static String buildTencentMeetingUrl(String meetingId) {
    return TENCENT_MEETING + Uri.encodeComponent(meetingId.trim());
  }

  /// 构建 Zoom 加入会议 URL。[meetingId] 为会议号。
  static String buildZoomMeetingUrl(String meetingId) {
    return ZOOM_MEETING + Uri.encodeComponent(meetingId.trim());
  }
}

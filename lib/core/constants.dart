class AppConstants {
  AppConstants._();

  static const String appName = '明耀文件快传';
  static const int discoveryPort = 22473;
  static const String discoveryPrefix = 'MYSHARE';
  static const Duration broadcastInterval = Duration(seconds: 3);
  static const Duration deviceTimeout = Duration(seconds: 10);
  static const Duration cleanupInterval = Duration(seconds: 5);

  static const String platformAndroid = 'android';
  static const String platformWindows = 'windows';
  static const String platformUnknown = 'unknown';
}
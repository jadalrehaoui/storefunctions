import 'dart:io' show Platform;

const String appVersionAndroid = '5.3.0';
const String appVersionWindows = '5.7.0';

String get appVersion =>
    Platform.isAndroid ? appVersionAndroid : appVersionWindows;

import 'dart:io' show Platform;

const String appVersionAndroid = '5.2.1';
const String appVersionWindows = '5.3.0';

String get appVersion =>
    Platform.isAndroid ? appVersionAndroid : appVersionWindows;

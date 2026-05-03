import 'dart:io' show Platform;

const String appVersionAndroid = '5.1.0';
const String appVersionWindows = '5.1.0';

String get appVersion =>
    Platform.isAndroid ? appVersionAndroid : appVersionWindows;

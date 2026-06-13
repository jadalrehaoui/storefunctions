import 'dart:io' show Platform;

const String appVersionAndroid = '5.2.2';
const String appVersionWindows = '5.5.1';

String get appVersion =>
    Platform.isAndroid ? appVersionAndroid : appVersionWindows;

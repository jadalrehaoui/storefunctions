import 'dart:io' show Platform;

const String appVersionAndroid = '5.2.3';
const String appVersionWindows = '5.5.2';

String get appVersion =>
    Platform.isAndroid ? appVersionAndroid : appVersionWindows;

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Storefunctions';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navSearch => 'Search';

  @override
  String get navCollapse => 'Collapse menu';

  @override
  String get navExpand => 'Expand menu';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventorySearchTitle => 'Search inventory';

  @override
  String get navPrintLabels => 'Print labels';

  @override
  String get inventoryPrintLabelsTitle => 'Print labels';

  @override
  String get navExportInventory => 'Export inventory';
}

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
  String get navDashboard => 'Dashboard';

  @override
  String get dashboardToday => 'Today';

  @override
  String get dashboardTotalSales => 'Total Sales';

  @override
  String get dashboardTotalDiscounts => 'Total Discounts';

  @override
  String get dashboardTotalBonos => 'Total Bonos';

  @override
  String get dashboardNetSales => 'Net Sales';

  @override
  String get dashboardInvoices => 'Invoices';

  @override
  String get dashboardNulledInvoices => 'Nulled Invoices';

  @override
  String get dashboardClientCount => 'Clients';

  @override
  String get dashboardAvgPerClient => 'Avg. per Client';

  @override
  String get dashboardCurrentYear => 'This Year';

  @override
  String get dashboardLastYear => 'Last Year';

  @override
  String get dashboardTwoYearsAgo => '2 Years Ago';

  @override
  String get dashboardMikailSales => 'Mikail Sales';

  @override
  String get dashboardMikailItems => 'Items';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navSearch => 'Search';

  @override
  String get navCollapse => 'Collapse menu';

  @override
  String get navExpand => 'Expand menu';

  @override
  String get navPrintLabels => 'Print labels';

  @override
  String get navExportInventory => 'Export inventory';

  @override
  String get navReports => 'Reports';

  @override
  String get navSalesReports => 'Sales Reports';

  @override
  String get navCierreSitsa => 'Cierre Sitsa';

  @override
  String get navCierreMikail => 'Cierre Mikail';

  @override
  String get navCierreParallel => 'Cierre Parallel';

  @override
  String get navRestockList => 'Restock List';

  @override
  String get navCierres => 'Closures';

  @override
  String get navBilling => 'Billing';

  @override
  String get navInvoice => 'New Invoice';

  @override
  String get navInvoiceList => 'Invoices';

  @override
  String get navCierreCaja => 'Cash Closure';

  @override
  String get navCierreCajaSitsa => 'Sitsa Cash Closure';

  @override
  String get navUsers => 'Users';

  @override
  String get invoiceCreateTitle => 'Create Invoice';

  @override
  String get invoiceListTitle => 'Invoices';

  @override
  String get invoiceDetailTitle => 'Invoice';

  @override
  String get invoiceItemLookupLabel => 'Item Code / Barcode';

  @override
  String get invoiceAdd => 'Add';

  @override
  String get invoiceItemNotFound => 'Item not found';

  @override
  String get invoiceDescription => 'Description';

  @override
  String get invoiceCode => 'Code';

  @override
  String get invoiceBarcode => 'Barcode';

  @override
  String get invoiceQty => 'Qty';

  @override
  String get invoiceUnitPrice => 'Unit Price';

  @override
  String get invoiceDiscountPct => 'Discount %';

  @override
  String get invoiceLineTotal => 'Line Total';

  @override
  String get invoiceAddToInvoice => 'Add to Invoice';

  @override
  String get invoiceClientName => 'Client Name';

  @override
  String get invoiceClientId => 'Client ID';

  @override
  String get invoiceDate => 'Date';

  @override
  String get invoiceNotes => 'Notes';

  @override
  String get invoiceSubtotal => 'Subtotal';

  @override
  String get invoiceDiscount => 'Discount';

  @override
  String get invoiceTotal => 'Total';

  @override
  String get invoiceCreate => 'Process and Print';

  @override
  String get invoiceCreated => 'Invoice created';

  @override
  String get invoiceManagerAuthTitle => 'Manager Authorization Required';

  @override
  String get invoiceManagerAuthBody =>
      'A discount above 15% requires manager approval.';

  @override
  String get invoiceManagerUsername => 'Manager Username';

  @override
  String get invoiceManagerPassword => 'Manager Password';

  @override
  String get invoiceAuthorize => 'Authorize';

  @override
  String get invoiceAuthError =>
      'Invalid credentials or insufficient privileges';

  @override
  String get invoiceColInvoiceId => 'Invoice #';

  @override
  String get invoiceColClient => 'Client';

  @override
  String get invoiceColTotal => 'Total';

  @override
  String get invoiceColStatus => 'Status';

  @override
  String get invoiceColActions => 'Actions';

  @override
  String get invoiceStatusActive => 'Active';

  @override
  String get invoiceStatusVoided => 'Voided';

  @override
  String get invoiceView => 'View';

  @override
  String get invoiceEdit => 'Edit';

  @override
  String get invoiceVoid => 'Void';

  @override
  String get invoiceVoidConfirmTitle => 'Void invoice';

  @override
  String get invoiceVoidConfirmBody =>
      'Are you sure you want to void this invoice? This cannot be undone.';

  @override
  String get invoiceFilterDateRange => 'Date range';

  @override
  String get invoiceFilterClient => 'Search client';

  @override
  String get invoiceCreatedBy => 'Created by';

  @override
  String get invoiceCreatedAt => 'Created at';

  @override
  String get invoiceNoItems => 'No items';

  @override
  String get invoiceSave => 'Save';

  @override
  String get navSettings => 'Settings';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventorySearchTitle => 'Search inventory';

  @override
  String get inventoryPrintLabelsTitle => 'Print labels';

  @override
  String get searchFieldLabel => 'Code / Text';

  @override
  String get btnGenerate => 'Generate';

  @override
  String get btnSave => 'Save';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnAdd => 'Add';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnEdit => 'Edit';

  @override
  String get btnPrint => 'Print';

  @override
  String get btnRetry => 'Retry';

  @override
  String get btnUpdate => 'Update';

  @override
  String get btnSearch => 'Search';

  @override
  String get btnAddUser => 'Add User';

  @override
  String get btnCustomLabel => 'Custom label';

  @override
  String get btnExportCsv => 'Export CSV';

  @override
  String get labelDate => 'Date';

  @override
  String get labelSearchHint => 'Search…';

  @override
  String get labelMonto => 'Amount';

  @override
  String get labelBanco => 'Bank';

  @override
  String get labelTC => 'Exch. Rate';

  @override
  String get labelNumDeposito => 'Deposit No.';

  @override
  String get labelInventarioAnterior => 'Previous Inventory';

  @override
  String get labelCostoInventarioAyer => 'Yesterday\'s Inventory Cost (₡)';

  @override
  String get labelDepositosBancarios => 'Bank Deposits';

  @override
  String get labelCobrosConTarjeta => 'Card Charges';

  @override
  String get labelCostoInventarioField => 'Inventory Cost (₡)';

  @override
  String get labelInventarioAnteriorField => 'Previous Inventory (₡)';

  @override
  String get labelCostosInventario => 'Inventory Costs';

  @override
  String get labelCreadoPor => 'Created by';

  @override
  String get labelTotalDia => 'Daily Total';

  @override
  String get labelRequired => 'Required';

  @override
  String get labelNewUsername => 'New username';

  @override
  String get labelUsername => 'Username';

  @override
  String get labelPassword => 'Password';

  @override
  String get labelNewPassword => 'New password';

  @override
  String get labelPrivileges => 'Privileges';

  @override
  String get labelCodigo => 'Code';

  @override
  String get labelModelo => 'Model';

  @override
  String get labelFechaInicio => 'Start date';

  @override
  String get labelFechaFin => 'End date';

  @override
  String get labelClasificacion => 'Classification';

  @override
  String get labelTodas => 'All';

  @override
  String get labelCodigoBarras => 'Barcode';

  @override
  String get labelFilas => 'Rows';

  @override
  String get labelCantidad => 'Quantity';

  @override
  String get labelBarcode => 'Barcode';

  @override
  String get labelArticleId => 'Article ID';

  @override
  String get labelPrice => 'Price';

  @override
  String get labelDescription => 'Description';

  @override
  String get labelCosto => 'Cost';

  @override
  String get labelGanancia => 'Profit';

  @override
  String get labelPrecio => 'Price';

  @override
  String get labelFob => 'FOB';

  @override
  String get labelSalida => 'Exit';

  @override
  String get labelDisponible => 'Available';

  @override
  String get labelVendidoSitsa => 'V. Sitsa';

  @override
  String get labelVendidoMikail => 'V. Mikail';

  @override
  String get labelVendidoWorkdb => 'V. WorkDB';

  @override
  String get labelVenta => 'Sale';

  @override
  String get labelIngreso => 'Income';

  @override
  String get labelSinFiltro => 'No filter';

  @override
  String get tileTotalFacturas => 'Total Invoices';

  @override
  String get tileAnuladas => 'Voided';

  @override
  String get tileBruto => 'Gross';

  @override
  String get tileBonos => 'Bonuses';

  @override
  String get tileDescuentos => 'Discounts';

  @override
  String get tileCostoInventario => 'Current Inventory';

  @override
  String get tileVentaNeta => 'Net Sales';

  @override
  String get tilePctDescuento => '% Discount';

  @override
  String get tileDiferenciaDepositar => 'Difference to Deposit';

  @override
  String get tileTipoCambio => 'Exchange Rate (Sell USD)';

  @override
  String get tileInventarioUsd => 'Current Inventory (\$)';

  @override
  String get colColones => 'Colones';

  @override
  String get labelRangosFacturas => 'Invoice Ranges';

  @override
  String get colRangoInicio => 'Range Start';

  @override
  String get colRangoFin => 'Range End';

  @override
  String get colTotal => 'Total';

  @override
  String get colFecha => 'Date';

  @override
  String get colPor => 'By';

  @override
  String get colVentaNeta => 'Net Sales';

  @override
  String get colPctDesc => '% Disc.';

  @override
  String get colDifDepositar => 'Diff. to Deposit';

  @override
  String get colInvAnterior => 'Prev. Inventory';

  @override
  String get colNoDeposito => 'Deposit No.';

  @override
  String get colMoneda => 'Currency';

  @override
  String get colCodigo => 'Code';

  @override
  String get colModelo => 'Model';

  @override
  String get colClasificacion => 'Classification';

  @override
  String get colDescripcion => 'Description';

  @override
  String get colDisp => 'Avail.';

  @override
  String get colReserv => 'Reserved';

  @override
  String get colUsername => 'Username';

  @override
  String get colPrivileges => 'Privileges';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionCalculos => 'Calculations';

  @override
  String get sectionFacturas => 'Invoices';

  @override
  String get sectionDetalle => 'Detail';

  @override
  String get cierreSitsaTitle => 'Cierre Sitsa';

  @override
  String get cierreMikailTitle => 'Cierre Mikail';

  @override
  String get restockListTitle => 'Restock List';

  @override
  String get closuresTitle => 'Closures';

  @override
  String get closureDetailTitle => 'Closure Detail';

  @override
  String get editClosureTitle => 'Edit Closure';

  @override
  String get usersTitle => 'Users';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get labelLanguage => 'Language';

  @override
  String get labelDatabaseConnections => 'Database Connections';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusChecking => 'Checking…';

  @override
  String get tooltipPrintPdf => 'Print PDF';

  @override
  String get tooltipExportCsv => 'Export CSV';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get tooltipBack => 'Back';

  @override
  String get tooltipRemove => 'Remove';

  @override
  String get tooltipDownloadCsv => 'Download CSV';

  @override
  String get tooltipEdit => 'Edit';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String get tooltipCannotDeleteSelf => 'Cannot delete yourself';

  @override
  String get tooltipGuardar => 'Save';

  @override
  String get tooltipActualizar => 'Update';

  @override
  String get msgSaved => 'Saved';

  @override
  String get msgUpdated => 'Updated';

  @override
  String get msgSelectDateGenerate => 'Select a date and press Generate';

  @override
  String get msgNoItems => 'No items';

  @override
  String get msgNoDepositsAdded => 'No deposits added';

  @override
  String get msgNoCardChargesAdded => 'No card charges added';

  @override
  String get msgNoDeposits => 'No deposits';

  @override
  String get msgNoCardCharges => 'No card charges';

  @override
  String get msgNoClosures => 'No closures yet';

  @override
  String get msgNoUsersFound => 'No users found.';

  @override
  String get msgDeleteForbidden =>
      'You do not have permission to delete this user.';

  @override
  String get msgNoChangesToSave => 'No changes to save.';

  @override
  String get msgDescargandoDatos => 'Downloading data...';

  @override
  String get hintLeaveBlankCurrent => 'Leave blank to keep current';

  @override
  String get helperMax28Chars => 'Max 28 characters';

  @override
  String get labelDifDepositar => 'Diff. to Deposit';

  @override
  String get deleteUserTitle => 'Delete user';

  @override
  String msgVerMasModelo(String modelo) {
    return 'View more with model $modelo';
  }

  @override
  String msgModeloHeader(String modelo) {
    return 'Model $modelo';
  }

  @override
  String msgSinResultados(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String msgResultadosPara(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String msgArticulosExportados(int count) {
    return '$count items exported';
  }

  @override
  String helperMaxRows(int max) {
    return 'Max $max';
  }

  @override
  String deleteUserConfirm(String username) {
    return 'Delete \"$username\"? This cannot be undone.';
  }

  @override
  String get validatorMinOne => 'Enter a number ≥ 1';

  @override
  String msgSavedAt(String path) {
    return 'Saved: $path';
  }

  @override
  String msgErrorDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String editUserTitle(String username) {
    return 'Edit \"$username\"';
  }
}

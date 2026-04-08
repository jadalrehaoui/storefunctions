import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Storefunctions'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In es, this message translates to:
  /// **'Panel'**
  String get navDashboard;

  /// No description provided for @dashboardToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get dashboardToday;

  /// No description provided for @dashboardTotalSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas Totales'**
  String get dashboardTotalSales;

  /// No description provided for @dashboardTotalDiscounts.
  ///
  /// In es, this message translates to:
  /// **'Descuentos Totales'**
  String get dashboardTotalDiscounts;

  /// No description provided for @dashboardTotalBonos.
  ///
  /// In es, this message translates to:
  /// **'Bonos Totales'**
  String get dashboardTotalBonos;

  /// No description provided for @dashboardNetSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas Netas'**
  String get dashboardNetSales;

  /// No description provided for @dashboardInvoices.
  ///
  /// In es, this message translates to:
  /// **'Facturas'**
  String get dashboardInvoices;

  /// No description provided for @dashboardNulledInvoices.
  ///
  /// In es, this message translates to:
  /// **'Facturas Anuladas'**
  String get dashboardNulledInvoices;

  /// No description provided for @dashboardClientCount.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get dashboardClientCount;

  /// No description provided for @dashboardAvgPerClient.
  ///
  /// In es, this message translates to:
  /// **'Prom. por Cliente'**
  String get dashboardAvgPerClient;

  /// No description provided for @dashboardCurrentYear.
  ///
  /// In es, this message translates to:
  /// **'Este Año'**
  String get dashboardCurrentYear;

  /// No description provided for @dashboardLastYear.
  ///
  /// In es, this message translates to:
  /// **'Año Anterior'**
  String get dashboardLastYear;

  /// No description provided for @dashboardTwoYearsAgo.
  ///
  /// In es, this message translates to:
  /// **'Hace 2 Años'**
  String get dashboardTwoYearsAgo;

  /// No description provided for @dashboardMikailSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas Mikail'**
  String get dashboardMikailSales;

  /// No description provided for @dashboardMikailItems.
  ///
  /// In es, this message translates to:
  /// **'Artículos'**
  String get dashboardMikailItems;

  /// No description provided for @navInventory.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get navInventory;

  /// No description provided for @navSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get navSearch;

  /// No description provided for @navCollapse.
  ///
  /// In es, this message translates to:
  /// **'Colapsar menú'**
  String get navCollapse;

  /// No description provided for @navExpand.
  ///
  /// In es, this message translates to:
  /// **'Expandir menú'**
  String get navExpand;

  /// No description provided for @navPrintLabels.
  ///
  /// In es, this message translates to:
  /// **'Imprimir etiquetas'**
  String get navPrintLabels;

  /// No description provided for @navExportInventory.
  ///
  /// In es, this message translates to:
  /// **'Exportar inventario'**
  String get navExportInventory;

  /// No description provided for @navReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get navReports;

  /// No description provided for @navSalesReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes de Ventas'**
  String get navSalesReports;

  /// No description provided for @navCierreSitsa.
  ///
  /// In es, this message translates to:
  /// **'Cierre Sitsa'**
  String get navCierreSitsa;

  /// No description provided for @navCierreMikail.
  ///
  /// In es, this message translates to:
  /// **'Cierre Mikail'**
  String get navCierreMikail;

  /// No description provided for @navCierreParallel.
  ///
  /// In es, this message translates to:
  /// **'Cierre Parallel'**
  String get navCierreParallel;

  /// No description provided for @navRestockList.
  ///
  /// In es, this message translates to:
  /// **'Lista de Restock'**
  String get navRestockList;

  /// No description provided for @navCierres.
  ///
  /// In es, this message translates to:
  /// **'Cierres'**
  String get navCierres;

  /// No description provided for @navBilling.
  ///
  /// In es, this message translates to:
  /// **'Facturación'**
  String get navBilling;

  /// No description provided for @navInvoice.
  ///
  /// In es, this message translates to:
  /// **'Facturar'**
  String get navInvoice;

  /// No description provided for @navInvoiceList.
  ///
  /// In es, this message translates to:
  /// **'Facturas'**
  String get navInvoiceList;

  /// No description provided for @navCierreCaja.
  ///
  /// In es, this message translates to:
  /// **'Cierre Caja'**
  String get navCierreCaja;

  /// No description provided for @navCierreCajaSitsa.
  ///
  /// In es, this message translates to:
  /// **'Cierre Caja Sitsa'**
  String get navCierreCajaSitsa;

  /// No description provided for @navUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get navUsers;

  /// No description provided for @invoiceCreateTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear Factura'**
  String get invoiceCreateTitle;

  /// No description provided for @invoiceListTitle.
  ///
  /// In es, this message translates to:
  /// **'Facturas'**
  String get invoiceListTitle;

  /// No description provided for @invoiceDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Factura'**
  String get invoiceDetailTitle;

  /// No description provided for @invoiceItemLookupLabel.
  ///
  /// In es, this message translates to:
  /// **'Código / Código de Barras'**
  String get invoiceItemLookupLabel;

  /// No description provided for @invoiceAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get invoiceAdd;

  /// No description provided for @invoiceItemNotFound.
  ///
  /// In es, this message translates to:
  /// **'Artículo no encontrado'**
  String get invoiceItemNotFound;

  /// No description provided for @invoiceDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get invoiceDescription;

  /// No description provided for @invoiceCode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get invoiceCode;

  /// No description provided for @invoiceBarcode.
  ///
  /// In es, this message translates to:
  /// **'Código de Barras'**
  String get invoiceBarcode;

  /// No description provided for @invoiceQty.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get invoiceQty;

  /// No description provided for @invoiceUnitPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio Unitario'**
  String get invoiceUnitPrice;

  /// No description provided for @invoiceDiscountPct.
  ///
  /// In es, this message translates to:
  /// **'Descuento %'**
  String get invoiceDiscountPct;

  /// No description provided for @invoiceLineTotal.
  ///
  /// In es, this message translates to:
  /// **'Total Línea'**
  String get invoiceLineTotal;

  /// No description provided for @invoiceAddToInvoice.
  ///
  /// In es, this message translates to:
  /// **'Agregar a Factura'**
  String get invoiceAddToInvoice;

  /// No description provided for @invoiceClientName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del Cliente'**
  String get invoiceClientName;

  /// No description provided for @invoiceClientId.
  ///
  /// In es, this message translates to:
  /// **'Cédula'**
  String get invoiceClientId;

  /// No description provided for @invoiceDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get invoiceDate;

  /// No description provided for @invoiceNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get invoiceNotes;

  /// No description provided for @invoiceSubtotal.
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get invoiceSubtotal;

  /// No description provided for @invoiceDiscount.
  ///
  /// In es, this message translates to:
  /// **'Descuento'**
  String get invoiceDiscount;

  /// No description provided for @invoiceTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get invoiceTotal;

  /// No description provided for @invoiceCreate.
  ///
  /// In es, this message translates to:
  /// **'Procesar e Imprimir'**
  String get invoiceCreate;

  /// No description provided for @invoiceCreated.
  ///
  /// In es, this message translates to:
  /// **'Factura creada'**
  String get invoiceCreated;

  /// No description provided for @invoiceManagerAuthTitle.
  ///
  /// In es, this message translates to:
  /// **'Autorización de Gerente Requerida'**
  String get invoiceManagerAuthTitle;

  /// No description provided for @invoiceManagerAuthBody.
  ///
  /// In es, this message translates to:
  /// **'Un descuento mayor al 15% requiere aprobación de gerente.'**
  String get invoiceManagerAuthBody;

  /// No description provided for @invoiceManagerUsername.
  ///
  /// In es, this message translates to:
  /// **'Usuario del Gerente'**
  String get invoiceManagerUsername;

  /// No description provided for @invoiceManagerPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña del Gerente'**
  String get invoiceManagerPassword;

  /// No description provided for @invoiceAuthorize.
  ///
  /// In es, this message translates to:
  /// **'Autorizar'**
  String get invoiceAuthorize;

  /// No description provided for @invoiceAuthError.
  ///
  /// In es, this message translates to:
  /// **'Credenciales inválidas o privilegios insuficientes'**
  String get invoiceAuthError;

  /// No description provided for @invoiceColInvoiceId.
  ///
  /// In es, this message translates to:
  /// **'Factura #'**
  String get invoiceColInvoiceId;

  /// No description provided for @invoiceColClient.
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get invoiceColClient;

  /// No description provided for @invoiceColTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get invoiceColTotal;

  /// No description provided for @invoiceColStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get invoiceColStatus;

  /// No description provided for @invoiceColActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get invoiceColActions;

  /// No description provided for @invoiceStatusActive.
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get invoiceStatusActive;

  /// No description provided for @invoiceStatusVoided.
  ///
  /// In es, this message translates to:
  /// **'Anulada'**
  String get invoiceStatusVoided;

  /// No description provided for @invoiceView.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get invoiceView;

  /// No description provided for @invoiceEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get invoiceEdit;

  /// No description provided for @invoiceVoid.
  ///
  /// In es, this message translates to:
  /// **'Anular'**
  String get invoiceVoid;

  /// No description provided for @invoiceVoidConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Anular factura'**
  String get invoiceVoidConfirmTitle;

  /// No description provided for @invoiceVoidConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'¿Está seguro de anular esta factura? Esta acción no se puede deshacer.'**
  String get invoiceVoidConfirmBody;

  /// No description provided for @invoiceFilterDateRange.
  ///
  /// In es, this message translates to:
  /// **'Rango de fechas'**
  String get invoiceFilterDateRange;

  /// No description provided for @invoiceFilterClient.
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente'**
  String get invoiceFilterClient;

  /// No description provided for @invoiceCreatedBy.
  ///
  /// In es, this message translates to:
  /// **'Creada por'**
  String get invoiceCreatedBy;

  /// No description provided for @invoiceCreatedAt.
  ///
  /// In es, this message translates to:
  /// **'Creada el'**
  String get invoiceCreatedAt;

  /// No description provided for @invoiceNoItems.
  ///
  /// In es, this message translates to:
  /// **'Sin artículos'**
  String get invoiceNoItems;

  /// No description provided for @invoiceSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get invoiceSave;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get navSettings;

  /// No description provided for @inventoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get inventoryTitle;

  /// No description provided for @inventorySearchTitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar en inventario'**
  String get inventorySearchTitle;

  /// No description provided for @inventoryPrintLabelsTitle.
  ///
  /// In es, this message translates to:
  /// **'Imprimir etiquetas'**
  String get inventoryPrintLabelsTitle;

  /// No description provided for @searchFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Código / Texto'**
  String get searchFieldLabel;

  /// No description provided for @btnGenerate.
  ///
  /// In es, this message translates to:
  /// **'Generar'**
  String get btnGenerate;

  /// No description provided for @btnSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get btnCancel;

  /// No description provided for @btnAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get btnAdd;

  /// No description provided for @btnDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get btnDelete;

  /// No description provided for @btnEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get btnEdit;

  /// No description provided for @btnPrint.
  ///
  /// In es, this message translates to:
  /// **'Imprimir'**
  String get btnPrint;

  /// No description provided for @btnRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get btnRetry;

  /// No description provided for @btnUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get btnUpdate;

  /// No description provided for @btnSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get btnSearch;

  /// No description provided for @btnAddUser.
  ///
  /// In es, this message translates to:
  /// **'Agregar Usuario'**
  String get btnAddUser;

  /// No description provided for @btnCustomLabel.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta personalizada'**
  String get btnCustomLabel;

  /// No description provided for @btnExportCsv.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get btnExportCsv;

  /// No description provided for @labelDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get labelDate;

  /// No description provided for @labelSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar…'**
  String get labelSearchHint;

  /// No description provided for @labelMonto.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get labelMonto;

  /// No description provided for @labelBanco.
  ///
  /// In es, this message translates to:
  /// **'Banco'**
  String get labelBanco;

  /// No description provided for @labelTC.
  ///
  /// In es, this message translates to:
  /// **'T/C'**
  String get labelTC;

  /// No description provided for @labelNumDeposito.
  ///
  /// In es, this message translates to:
  /// **'No. Depósito'**
  String get labelNumDeposito;

  /// No description provided for @labelInventarioAnterior.
  ///
  /// In es, this message translates to:
  /// **'Inventario Anterior'**
  String get labelInventarioAnterior;

  /// No description provided for @labelCostoInventarioAyer.
  ///
  /// In es, this message translates to:
  /// **'Costo Inventario Ayer (₡)'**
  String get labelCostoInventarioAyer;

  /// No description provided for @labelDepositosBancarios.
  ///
  /// In es, this message translates to:
  /// **'Depósitos Bancarios'**
  String get labelDepositosBancarios;

  /// No description provided for @labelCobrosConTarjeta.
  ///
  /// In es, this message translates to:
  /// **'Cobros con Tarjeta'**
  String get labelCobrosConTarjeta;

  /// No description provided for @labelCostoInventarioField.
  ///
  /// In es, this message translates to:
  /// **'Costo Inventario (₡)'**
  String get labelCostoInventarioField;

  /// No description provided for @labelInventarioAnteriorField.
  ///
  /// In es, this message translates to:
  /// **'Inventario Anterior (₡)'**
  String get labelInventarioAnteriorField;

  /// No description provided for @labelCostosInventario.
  ///
  /// In es, this message translates to:
  /// **'Costos de Inventario'**
  String get labelCostosInventario;

  /// No description provided for @labelCreadoPor.
  ///
  /// In es, this message translates to:
  /// **'Creado por'**
  String get labelCreadoPor;

  /// No description provided for @labelTotalDia.
  ///
  /// In es, this message translates to:
  /// **'Total del Día'**
  String get labelTotalDia;

  /// No description provided for @labelRequired.
  ///
  /// In es, this message translates to:
  /// **'Requerido'**
  String get labelRequired;

  /// No description provided for @labelNewUsername.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario nuevo'**
  String get labelNewUsername;

  /// No description provided for @labelUsername.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get labelUsername;

  /// No description provided for @labelPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get labelPassword;

  /// No description provided for @labelNewPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña nueva'**
  String get labelNewPassword;

  /// No description provided for @labelPrivileges.
  ///
  /// In es, this message translates to:
  /// **'Privilegios'**
  String get labelPrivileges;

  /// No description provided for @labelCodigo.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get labelCodigo;

  /// No description provided for @labelModelo.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get labelModelo;

  /// No description provided for @labelFechaInicio.
  ///
  /// In es, this message translates to:
  /// **'Fecha inicio'**
  String get labelFechaInicio;

  /// No description provided for @labelFechaFin.
  ///
  /// In es, this message translates to:
  /// **'Fecha fin'**
  String get labelFechaFin;

  /// No description provided for @labelClasificacion.
  ///
  /// In es, this message translates to:
  /// **'Clasificación'**
  String get labelClasificacion;

  /// No description provided for @labelTodas.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get labelTodas;

  /// No description provided for @labelCodigoBarras.
  ///
  /// In es, this message translates to:
  /// **'Código de Barras'**
  String get labelCodigoBarras;

  /// No description provided for @labelFilas.
  ///
  /// In es, this message translates to:
  /// **'Filas'**
  String get labelFilas;

  /// No description provided for @labelCantidad.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get labelCantidad;

  /// No description provided for @labelBarcode.
  ///
  /// In es, this message translates to:
  /// **'Código de Barras'**
  String get labelBarcode;

  /// No description provided for @labelArticleId.
  ///
  /// In es, this message translates to:
  /// **'ID de Artículo'**
  String get labelArticleId;

  /// No description provided for @labelPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get labelPrice;

  /// No description provided for @labelDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get labelDescription;

  /// No description provided for @labelCosto.
  ///
  /// In es, this message translates to:
  /// **'Costo'**
  String get labelCosto;

  /// No description provided for @labelGanancia.
  ///
  /// In es, this message translates to:
  /// **'Ganancia'**
  String get labelGanancia;

  /// No description provided for @labelPrecio.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get labelPrecio;

  /// No description provided for @labelFob.
  ///
  /// In es, this message translates to:
  /// **'FOB'**
  String get labelFob;

  /// No description provided for @labelSalida.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get labelSalida;

  /// No description provided for @labelDisponible.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get labelDisponible;

  /// No description provided for @labelVendidoSitsa.
  ///
  /// In es, this message translates to:
  /// **'V. Sitsa'**
  String get labelVendidoSitsa;

  /// No description provided for @labelVendidoMikail.
  ///
  /// In es, this message translates to:
  /// **'V. Mikail'**
  String get labelVendidoMikail;

  /// No description provided for @labelVendidoWorkdb.
  ///
  /// In es, this message translates to:
  /// **'V. WorkDB'**
  String get labelVendidoWorkdb;

  /// No description provided for @labelVenta.
  ///
  /// In es, this message translates to:
  /// **'Venta'**
  String get labelVenta;

  /// No description provided for @labelIngreso.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get labelIngreso;

  /// No description provided for @labelSinFiltro.
  ///
  /// In es, this message translates to:
  /// **'Sin filtro'**
  String get labelSinFiltro;

  /// No description provided for @tileTotalFacturas.
  ///
  /// In es, this message translates to:
  /// **'Total Facturas'**
  String get tileTotalFacturas;

  /// No description provided for @tileAnuladas.
  ///
  /// In es, this message translates to:
  /// **'Anuladas'**
  String get tileAnuladas;

  /// No description provided for @tileBruto.
  ///
  /// In es, this message translates to:
  /// **'Bruto'**
  String get tileBruto;

  /// No description provided for @tileBonos.
  ///
  /// In es, this message translates to:
  /// **'Bonos'**
  String get tileBonos;

  /// No description provided for @tileDescuentos.
  ///
  /// In es, this message translates to:
  /// **'Descuentos'**
  String get tileDescuentos;

  /// No description provided for @tileCostoInventario.
  ///
  /// In es, this message translates to:
  /// **'Inventario Actual'**
  String get tileCostoInventario;

  /// No description provided for @tileVentaNeta.
  ///
  /// In es, this message translates to:
  /// **'Venta Neta'**
  String get tileVentaNeta;

  /// No description provided for @tilePctDescuento.
  ///
  /// In es, this message translates to:
  /// **'% Descuento'**
  String get tilePctDescuento;

  /// No description provided for @tileDiferenciaDepositar.
  ///
  /// In es, this message translates to:
  /// **'Diferencia a Depositar'**
  String get tileDiferenciaDepositar;

  /// No description provided for @tileTipoCambio.
  ///
  /// In es, this message translates to:
  /// **'T/C Venta USD'**
  String get tileTipoCambio;

  /// No description provided for @tileInventarioUsd.
  ///
  /// In es, this message translates to:
  /// **'Inventario Actual (\$)'**
  String get tileInventarioUsd;

  /// No description provided for @colColones.
  ///
  /// In es, this message translates to:
  /// **'Colones'**
  String get colColones;

  /// No description provided for @labelRangosFacturas.
  ///
  /// In es, this message translates to:
  /// **'Rangos de Facturas'**
  String get labelRangosFacturas;

  /// No description provided for @colRangoInicio.
  ///
  /// In es, this message translates to:
  /// **'Rango Inicio'**
  String get colRangoInicio;

  /// No description provided for @colRangoFin.
  ///
  /// In es, this message translates to:
  /// **'Rango Fin'**
  String get colRangoFin;

  /// No description provided for @colTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get colTotal;

  /// No description provided for @colFecha.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get colFecha;

  /// No description provided for @colPor.
  ///
  /// In es, this message translates to:
  /// **'Por'**
  String get colPor;

  /// No description provided for @colVentaNeta.
  ///
  /// In es, this message translates to:
  /// **'Venta Neta'**
  String get colVentaNeta;

  /// No description provided for @colPctDesc.
  ///
  /// In es, this message translates to:
  /// **'% Desc.'**
  String get colPctDesc;

  /// No description provided for @colDifDepositar.
  ///
  /// In es, this message translates to:
  /// **'Dif. a Depositar'**
  String get colDifDepositar;

  /// No description provided for @colInvAnterior.
  ///
  /// In es, this message translates to:
  /// **'Inv. Anterior'**
  String get colInvAnterior;

  /// No description provided for @colNoDeposito.
  ///
  /// In es, this message translates to:
  /// **'No. Depósito'**
  String get colNoDeposito;

  /// No description provided for @colMoneda.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get colMoneda;

  /// No description provided for @colCodigo.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get colCodigo;

  /// No description provided for @colModelo.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get colModelo;

  /// No description provided for @colClasificacion.
  ///
  /// In es, this message translates to:
  /// **'Clasificación'**
  String get colClasificacion;

  /// No description provided for @colDescripcion.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get colDescripcion;

  /// No description provided for @colDisp.
  ///
  /// In es, this message translates to:
  /// **'Disp.'**
  String get colDisp;

  /// No description provided for @colReserv.
  ///
  /// In es, this message translates to:
  /// **'Reserv.'**
  String get colReserv;

  /// No description provided for @colUsername.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get colUsername;

  /// No description provided for @colPrivileges.
  ///
  /// In es, this message translates to:
  /// **'Privilegios'**
  String get colPrivileges;

  /// No description provided for @sectionGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @sectionCalculos.
  ///
  /// In es, this message translates to:
  /// **'Cálculos'**
  String get sectionCalculos;

  /// No description provided for @sectionFacturas.
  ///
  /// In es, this message translates to:
  /// **'Facturas'**
  String get sectionFacturas;

  /// No description provided for @sectionDetalle.
  ///
  /// In es, this message translates to:
  /// **'Detalle'**
  String get sectionDetalle;

  /// No description provided for @cierreSitsaTitle.
  ///
  /// In es, this message translates to:
  /// **'Cierre Sitsa'**
  String get cierreSitsaTitle;

  /// No description provided for @cierreMikailTitle.
  ///
  /// In es, this message translates to:
  /// **'Cierre Mikail'**
  String get cierreMikailTitle;

  /// No description provided for @restockListTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista de Restock'**
  String get restockListTitle;

  /// No description provided for @closuresTitle.
  ///
  /// In es, this message translates to:
  /// **'Cierres'**
  String get closuresTitle;

  /// No description provided for @closureDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de Cierre'**
  String get closureDetailTitle;

  /// No description provided for @editClosureTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar Cierre'**
  String get editClosureTitle;

  /// No description provided for @usersTitle.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get usersTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// No description provided for @labelLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get labelLanguage;

  /// No description provided for @labelDatabaseConnections.
  ///
  /// In es, this message translates to:
  /// **'Conexiones de Base de Datos'**
  String get labelDatabaseConnections;

  /// No description provided for @statusConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectado'**
  String get statusConnected;

  /// No description provided for @statusDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Desconectado'**
  String get statusDisconnected;

  /// No description provided for @statusChecking.
  ///
  /// In es, this message translates to:
  /// **'Verificando…'**
  String get statusChecking;

  /// No description provided for @tooltipPrintPdf.
  ///
  /// In es, this message translates to:
  /// **'Imprimir PDF'**
  String get tooltipPrintPdf;

  /// No description provided for @tooltipExportCsv.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get tooltipExportCsv;

  /// No description provided for @tooltipRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get tooltipRefresh;

  /// No description provided for @tooltipBack.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get tooltipBack;

  /// No description provided for @tooltipRemove.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get tooltipRemove;

  /// No description provided for @tooltipDownloadCsv.
  ///
  /// In es, this message translates to:
  /// **'Descargar CSV'**
  String get tooltipDownloadCsv;

  /// No description provided for @tooltipEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get tooltipEdit;

  /// No description provided for @tooltipDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get tooltipDelete;

  /// No description provided for @tooltipCannotDeleteSelf.
  ///
  /// In es, this message translates to:
  /// **'No puede eliminarse a sí mismo'**
  String get tooltipCannotDeleteSelf;

  /// No description provided for @tooltipGuardar.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get tooltipGuardar;

  /// No description provided for @tooltipActualizar.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get tooltipActualizar;

  /// No description provided for @msgSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado'**
  String get msgSaved;

  /// No description provided for @msgUpdated.
  ///
  /// In es, this message translates to:
  /// **'Actualizado'**
  String get msgUpdated;

  /// No description provided for @msgSelectDateGenerate.
  ///
  /// In es, this message translates to:
  /// **'Seleccione una fecha y presione Generar'**
  String get msgSelectDateGenerate;

  /// No description provided for @msgNoItems.
  ///
  /// In es, this message translates to:
  /// **'Sin artículos'**
  String get msgNoItems;

  /// No description provided for @msgNoDepositsAdded.
  ///
  /// In es, this message translates to:
  /// **'Sin depósitos agregados'**
  String get msgNoDepositsAdded;

  /// No description provided for @msgNoCardChargesAdded.
  ///
  /// In es, this message translates to:
  /// **'Sin cobros con tarjeta'**
  String get msgNoCardChargesAdded;

  /// No description provided for @msgNoDeposits.
  ///
  /// In es, this message translates to:
  /// **'Sin depósitos'**
  String get msgNoDeposits;

  /// No description provided for @msgNoCardCharges.
  ///
  /// In es, this message translates to:
  /// **'Sin cobros con tarjeta'**
  String get msgNoCardCharges;

  /// No description provided for @msgNoClosures.
  ///
  /// In es, this message translates to:
  /// **'Sin cierres aún'**
  String get msgNoClosures;

  /// No description provided for @msgNoUsersFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron usuarios.'**
  String get msgNoUsersFound;

  /// No description provided for @msgDeleteForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para eliminar este usuario.'**
  String get msgDeleteForbidden;

  /// No description provided for @msgNoChangesToSave.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios para guardar.'**
  String get msgNoChangesToSave;

  /// No description provided for @msgDescargandoDatos.
  ///
  /// In es, this message translates to:
  /// **'Descargando datos...'**
  String get msgDescargandoDatos;

  /// No description provided for @hintLeaveBlankCurrent.
  ///
  /// In es, this message translates to:
  /// **'Dejar en blanco para mantener el actual'**
  String get hintLeaveBlankCurrent;

  /// No description provided for @helperMax28Chars.
  ///
  /// In es, this message translates to:
  /// **'Máx 28 caracteres'**
  String get helperMax28Chars;

  /// No description provided for @labelDifDepositar.
  ///
  /// In es, this message translates to:
  /// **'Dif. a Depositar'**
  String get labelDifDepositar;

  /// No description provided for @deleteUserTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar usuario'**
  String get deleteUserTitle;

  /// No description provided for @msgVerMasModelo.
  ///
  /// In es, this message translates to:
  /// **'Ver más con modelo {modelo}'**
  String msgVerMasModelo(String modelo);

  /// No description provided for @msgModeloHeader.
  ///
  /// In es, this message translates to:
  /// **'Modelo {modelo}'**
  String msgModeloHeader(String modelo);

  /// No description provided for @msgSinResultados.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para \"{query}\"'**
  String msgSinResultados(String query);

  /// No description provided for @msgResultadosPara.
  ///
  /// In es, this message translates to:
  /// **'Resultados para \"{query}\"'**
  String msgResultadosPara(String query);

  /// No description provided for @msgArticulosExportados.
  ///
  /// In es, this message translates to:
  /// **'{count} artículos exportados'**
  String msgArticulosExportados(int count);

  /// No description provided for @helperMaxRows.
  ///
  /// In es, this message translates to:
  /// **'Máx {max}'**
  String helperMaxRows(int max);

  /// No description provided for @deleteUserConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{username}\"? Esta acción no se puede deshacer.'**
  String deleteUserConfirm(String username);

  /// No description provided for @validatorMinOne.
  ///
  /// In es, this message translates to:
  /// **'Ingrese un número ≥ 1'**
  String get validatorMinOne;

  /// No description provided for @msgSavedAt.
  ///
  /// In es, this message translates to:
  /// **'Guardado: {path}'**
  String msgSavedAt(String path);

  /// No description provided for @msgErrorDetail.
  ///
  /// In es, this message translates to:
  /// **'Error: {detail}'**
  String msgErrorDetail(String detail);

  /// No description provided for @editUserTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar \"{username}\"'**
  String editUserTitle(String username);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

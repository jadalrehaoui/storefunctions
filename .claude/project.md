# Storefunctions — Project Context

## Purpose
Desktop app (Windows & macOS only) that connects to a remote server over the network to retrieve and manage store-related data/functions.

## Platforms
- Windows
- macOS (entitlements: `com.apple.security.network.client` added to both Debug and Release)

---

## Architecture

### State Management — `flutter_bloc` (Cubit)
- Use **Cubit** for all state management
- One Cubit per feature/screen; shared cubits go in `lib/shared/cubit/`
- States are sealed classes with plain Dart data

### Navigation — `go_router`
- Router defined in `lib/router/app_router.dart`
- `ShellRoute` wraps all screens with `AppShell` (side nav + content)
- Named routes: use `context.goNamed('route-name')`

### Dependency Injection — `get_it`
- Service locator in `lib/di/service_locator.dart`
- Alias: `sl` = `GetIt.instance`
- `ApiClient` and `InventoryService` registered as lazy singletons
- Cubits provided via `BlocProvider` at screen level (not global)

### Localization — `flutter_localizations` + `intl`
- Default locale: **Spanish (`es`)**
- Supported: `es`, `en`
- ARB source: `lib/l10n/app_es.arb` (template), `lib/l10n/app_en.arb`
- Generated files maintained manually (sandbox blocks `flutter gen-l10n`):
  - `lib/l10n/app_localizations.dart` — abstract base + delegate
  - `lib/l10n/app_localizations_es.dart`
  - `lib/l10n/app_localizations_en.dart`
- Helper: `lib/l10n/l10n.dart` — `context.l10n` extension
- **When adding a string:** update both ARBs + both impl classes + abstract base

---

## Code Rules

- **Max 600 lines per file** — split if approaching limit
- **Shared UI components** → `lib/shared/widgets/`
- **Shared utilities** → `lib/shared/utils/`
- **Shared cubits** → `lib/shared/cubit/`
- One class/widget per file where practical
- No business logic in widgets — delegate to Cubits
- Prefer `context.select(...)` over `context.watch(...)` to minimize rebuilds

---

## Folder Structure

```
lib/
├── main.dart
├── app.dart                              # MaterialApp.router + l10n
├── router/
│   └── app_router.dart                  # GoRouter + ShellRoute
├── di/
│   └── service_locator.dart             # GetIt: ApiClient, InventoryService
├── l10n/                                # Localization files (ES default)
├── models/
│   ├── article_result.dart              # Search-by-barcode result
│   └── combined_item.dart               # CombinedItem (SitsaItem + MikailItem)
├── services/
│   ├── api_client.dart                  # Dio → http://10.10.0.130:3000
│   └── inventory_service.dart           # searchByBarcode, getItemCombined
├── shared/
│   ├── cubit/
│   │   ├── nav_cubit.dart               # Sidebar state
│   │   └── nav_state.dart
│   ├── utils/
│   │   └── label_printer.dart           # ZPL → TCP → Zebra ZD620 (10.10.0.144:9100)
│   └── widgets/
│       ├── app_shell.dart               # Row(SideNav, child)
│       ├── barcode_display.dart         # CustomPainter EAN-13/Code128 widget
│       └── side_nav/
│           ├── side_nav.dart
│           ├── nav_item_widget.dart
│           ├── nav_sub_item_widget.dart
│           └── nav_config.dart          # navItems list — add items here
└── features/
    └── inventory/
        ├── cubit/
        │   ├── nav_cubit.dart / nav_state.dart         (shared)
        │   ├── print_labels_cubit.dart / _state.dart
        │   ├── inventory_search_cubit.dart / _state.dart
        └── view/
            ├── inventory_screen.dart
            ├── inventory_search_screen.dart
            ├── inventory_print_labels_screen.dart
            └── inventory_print_labels_screen.dart
```

---

## Navigation Structure

```
ShellRoute (AppShell)
└── /inventory               → InventoryScreen
    ├── /search              → InventorySearchScreen
    └── /print-labels        → InventoryPrintLabelsScreen  ← initial route
```

---

## Side Nav

- Expanded: **220px** | Collapsed: **64px** | Animation: 200ms ease-in-out
- `NavCubit` provided in `AppShell`
- Adding a nav item: add `NavItemConfig` to `navItems` in `nav_config.dart` + add route to router

**Current nav tree:**
```
Inventario
  └── Buscar
  └── Imprimir Etiquetas
```

---

## API

**Base URL:** `http://10.10.0.130:3000`

### POST `/api/sql/search-by-barcode`
Searches SITSA by barcode/articleId.
```json
{ "articleId": "...", "bodega": "B-01", "database": "Punto_Venta_Sucursal",
  "password": "Sql2020", "server": "10.10.0.191\\MSSQLSERVER2017", "username": "sa" }
```
Response shape: `{ "success": true, "data": [ ...ArticleResult ], "count": 1 }`

### POST `/api/sql/get-item-combined`
Returns combined SITSA + Mikail data for a product code.
```json
{ "code": "...",
  "sitsaServer": "10.10.0.191\\MSSQLSERVER2017", "sitsaDatabase": "Punto_Venta_Sucursal",
  "sitsaUsername": "sa", "sitsaPassword": "Sql2020",
  "mikailServer": "10.10.0.191", "mikailDatabase": "Mikail",
  "mikailUsername": "JAD_LCTR", "mikailPassword": "ContraseñaSegura123!" }
```
Response shape: `{ "success": true, "code": "...", "sitsa": { ... }, "mikail": { ... } }`

---

## Models

### `ArticleResult` (`models/article_result.dart`)
Fields: `id`, `barcode`, `description`, `model`, `classification`, `cost`, `profit`, `quantityAvailable`
Computed: `price = cost + cost * profit / 100`

### `CombinedItem` (`models/combined_item.dart`)
- `SitsaItem`: `description`, `model`, `classification`, `fob`, `costo`, `ganancia`, `fechaCreacion`
- `MikailItem`: `existencia`, `precio`, `costo`, `utilidad`

---

## Zebra Printer

- **IP:** `10.10.0.144` **Port:** `9100` (raw TCP)
- **Printer:** Zebra ZD620
- ZPL template in `lib/shared/utils/label_printer.dart`
- Label: 80mm × 50mm, two copies per sheet side-by-side
- Description truncated to **28 chars**
- Price: no decimals, comma thousands separator (`#,##0`)
- Rows to print = `⌈quantity / 2⌉` (max)

---

## Screens

### Inventory Search (`/inventory/search`)
- Search field → calls `getItemCombined`
- **Section 1:** SITSA card — Descripcion, Modelo, Clasificacion, Costo, Ganancia%, FOB, Fecha Creación
- **Section 2:** Raw JSON display

### Print Labels (`/inventory/print-labels`)
- Search by barcode → calls `searchByBarcode`
- Displays article card: description, model, classification, price, barcode widget + number
- Print controls (only when quantity > 0): rows = `⌈qty/2⌉` max
- Keyboard flow: Enter on código → focus rows → Enter → print → clear → back to código

---

## Packages
| Package | Purpose |
|---------|---------|
| `flutter_bloc` | Cubit state management |
| `go_router` | Navigation + ShellRoute |
| `get_it` | Service locator |
| `dio` | HTTP client |
| `barcode` | EAN-13/Code128 rendering (CustomPainter) |
| `flutter_localizations` | L10n delegates |
| `intl` | Formatting + locale |
| `cupertino_icons` | Icons |

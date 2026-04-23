import '../model/bodega_lista_item.dart';

sealed class BodegaListasState {}

class BodegaListasInitial extends BodegaListasState {}

class BodegaListasLoading extends BodegaListasState {}

class BodegaListasFailure extends BodegaListasState {
  final String error;
  BodegaListasFailure(this.error);
}

class BodegaListasReady extends BodegaListasState {
  final List<BodegaListaItem> items;

  /// Creator username to filter by. `null` means "all creators" — when this is
  /// null the print button is disabled (per spec: printing is only allowed
  /// scoped to a single creator).
  final String? creatorFilter;

  final bool liveConnected;
  final bool addInFlight;
  final bool printInFlight;

  /// One-off error message surfaced via BlocListener; cleared on next emit.
  final String? transientError;

  BodegaListasReady({
    required this.items,
    this.creatorFilter,
    this.liveConnected = false,
    this.addInFlight = false,
    this.printInFlight = false,
    this.transientError,
  });

  BodegaListasReady copyWith({
    List<BodegaListaItem>? items,
    Object? creatorFilter = _sentinel,
    bool? liveConnected,
    bool? addInFlight,
    bool? printInFlight,
    Object? transientError = _sentinel,
  }) {
    return BodegaListasReady(
      items: items ?? this.items,
      creatorFilter: creatorFilter == _sentinel
          ? this.creatorFilter
          : creatorFilter as String?,
      liveConnected: liveConnected ?? this.liveConnected,
      addInFlight: addInFlight ?? this.addInFlight,
      printInFlight: printInFlight ?? this.printInFlight,
      transientError: transientError == _sentinel
          ? this.transientError
          : transientError as String?,
    );
  }

  List<BodegaListaItem> get visibleItems {
    if (creatorFilter == null) return items;
    return items.where((i) => i.addedByUsername == creatorFilter).toList();
  }

  /// Distinct creators present in the current list (for filter dropdown).
  List<String> get creatorsInList {
    final seen = <String>{};
    for (final i in items) {
      seen.add(i.addedByUsername);
    }
    final list = seen.toList()..sort();
    return list;
  }
}

const _sentinel = Object();

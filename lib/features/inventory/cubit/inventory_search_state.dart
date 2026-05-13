import '../../../models/combined_item.dart';
import '../../../models/item_list_membership.dart';

sealed class InventorySearchState {}

class InventorySearchInitial extends InventorySearchState {}

class InventorySearchLoading extends InventorySearchState {}

class InventorySearchSuccess extends InventorySearchState {
  final CombinedItem item;
  final bool modeloLoading;
  final List<dynamic>? modeloItems;
  final List<ItemListMembership> itemLists;

  InventorySearchSuccess(
    this.item, {
    this.modeloLoading = false,
    this.modeloItems,
    this.itemLists = const [],
  });

  InventorySearchSuccess copyWith({
    CombinedItem? item,
    bool? modeloLoading,
    List<dynamic>? modeloItems,
    bool clearModeloItems = false,
    List<ItemListMembership>? itemLists,
  }) {
    return InventorySearchSuccess(
      item ?? this.item,
      modeloLoading: modeloLoading ?? this.modeloLoading,
      modeloItems: clearModeloItems ? null : (modeloItems ?? this.modeloItems),
      itemLists: itemLists ?? this.itemLists,
    );
  }
}

class InventorySearchDescriptionResults extends InventorySearchState {
  final String query;
  final List<dynamic> items;
  final dynamic raw;
  InventorySearchDescriptionResults({required this.query, required this.items, required this.raw});
}

class InventorySearchFailure extends InventorySearchState {
  final String error;
  InventorySearchFailure(this.error);
}

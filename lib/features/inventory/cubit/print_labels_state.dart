import '../../../models/combined_item.dart';

sealed class PrintLabelsState {}

class PrintLabelsInitial extends PrintLabelsState {}

class PrintLabelsLoading extends PrintLabelsState {}

class PrintLabelsSuccess extends PrintLabelsState {
  final CombinedItem item;
  PrintLabelsSuccess(this.item);
}

class PrintLabelsFailure extends PrintLabelsState {
  final String error;
  PrintLabelsFailure(this.error);
}

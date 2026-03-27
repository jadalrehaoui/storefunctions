import '../../../models/article_result.dart';

sealed class PrintLabelsState {}

class PrintLabelsInitial extends PrintLabelsState {}

class PrintLabelsLoading extends PrintLabelsState {}

class PrintLabelsSuccess extends PrintLabelsState {
  final List<ArticleResult> results;
  PrintLabelsSuccess(this.results);
}

class PrintLabelsFailure extends PrintLabelsState {
  final String error;
  PrintLabelsFailure(this.error);
}

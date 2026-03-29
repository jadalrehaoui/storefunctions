import 'dart:io';

import 'package:intl/intl.dart';

import '../../models/article_result.dart';
import '../../models/combined_item.dart';

const _printerHost = '10.10.0.144';
const _printerPort = 9100;

const _zplTemplate = r'''^XA
^MMT
^PW898
^LL295
^LS-20
^BY3,2,101^FT90,118^BEN,,Y,N
^FH\^FD{{BARCODE}}^FS
^FT45,278^A0B,38,38^FB278,1,10,C^FH\^CI28^FD{{ARTICLE_ID}}^FS^CI27
^FT72,204^A0N,67,66^FH\^CI28^FDCRC {{PRICE}}^FS^CI27
^FT16,295^A0N,25,23^FH\^CI28^FDLEY 9356 - Unicamente para uso personal^FS^CI27
^FT18,252^A0N,28,28^FH\^CI28^FD{{DESCRIPTION}}^FS^CI27
^BY3,2,101^FT544,114^BEN,,Y,N
^FH\^FD{{BARCODE}}^FS
^FT499,272^A0B,38,38^FB272,1,10,C^FH\^CI28^FD{{ARTICLE_ID}}^FS^CI27
^FT526,200^A0N,67,66^FH\^CI28^FDCRC {{PRICE}}^FS^CI27
^FT471,292^A0N,25,23^FH\^CI28^FDLEY 9356 - Unicamente para uso personal^FS^CI27
^FT473,252^A0N,28,28^FH\^CI28^FD{{DESCRIPTION}}^FS^CI27
^PQ{{COUNT}},0,1,Y
^XZ
''';

String _buildZpl({
  required String barcode,
  required String articleId,
  required String price,
  required String description,
  required int count,
}) {
  return _zplTemplate
      .replaceAll('{{BARCODE}}', barcode)
      .replaceAll('{{ARTICLE_ID}}', articleId)
      .replaceAll('{{PRICE}}', price)
      .replaceAll('{{DESCRIPTION}}', description)
      .replaceAll('{{COUNT}}', '$count');
}

Future<void> printCustomLabel({
  required String barcode,
  required String articleId,
  required String price,
  required String description,
  required int count,
}) async {
  final zpl = _buildZpl(
    barcode: barcode,
    articleId: articleId,
    price: price,
    description: description.length > 28 ? description.substring(0, 28) : description,
    count: count,
  );

  final socket = await Socket.connect(
    _printerHost,
    _printerPort,
    timeout: const Duration(seconds: 5),
  );

  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

Future<void> printCombinedLabel(CombinedItem item, int count) async {
  final sitsa = item.sitsa;
  final barcode = sitsa?.codigoBarras ?? '';
  final rawPrice =
      sitsa != null ? sitsa.costo + sitsa.costo * sitsa.ganancia / 100 : 0;
  final price = NumberFormat('#,##0', 'en_US').format(rawPrice.round());
  final description = sitsa?.description ?? '';

  final zpl = _buildZpl(
    barcode: barcode,
    articleId: item.code,
    price: price,
    description:
        description.length > 28 ? description.substring(0, 28) : description,
    count: count,
  );

  final socket = await Socket.connect(
    _printerHost,
    _printerPort,
    timeout: const Duration(seconds: 5),
  );

  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

Future<void> printArticleLabels(ArticleResult article, int count) async {
  final price = NumberFormat('#,##0', 'en_US').format(article.price.round());

  final zpl = _buildZpl(
    barcode: article.barcode,
    articleId: article.id,
    price: price,
    description: article.description.length > 28
        ? article.description.substring(0, 28)
        : article.description,
    count: count,
  );

  final socket = await Socket.connect(
    _printerHost,
    _printerPort,
    timeout: const Duration(seconds: 5),
  );

  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

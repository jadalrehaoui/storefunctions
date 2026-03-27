class ArticleResult {
  final String id;
  final String barcode;
  final String description;
  final String model;
  final String classification;
  final double cost;
  final double profit;
  final int quantityAvailable;

  const ArticleResult({
    required this.id,
    required this.barcode,
    required this.description,
    required this.model,
    required this.classification,
    required this.cost,
    required this.profit,
    required this.quantityAvailable,
  });

  double get price => cost + cost * profit / 100;

  factory ArticleResult.fromJson(Map<String, dynamic> json) {
    return ArticleResult(
      id: json['PK_FK_Articulo'] as String,
      barcode: json['Codigo_Barras'] as String,
      description: json['Articulo_Descripcion'] as String,
      model: json['MODELO'] as String,
      classification: json['Clasificacion_Descripcion'] as String,
      cost: (json['cost'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      quantityAvailable: (json['Cantidad_Disponible'] as num).toInt(),
    );
  }
}

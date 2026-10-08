/// Modelo que representa un Producto de la tienda
class Producto {
  final int? id;
  final String nombre;
  final double precio;
  final int cantidad; // Stock disponible
  final String imagen;
  final String? desc;

  Producto({
    this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.imagen,
    this.desc,
  });

  /// Crear un objeto Producto desde un Map de SQLite o JSON
  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] != null ? map['id'] as int : null,
      nombre: map['nombre_product'] as String? ?? map['nombre'] as String? ?? 'Producto sin nombre',
      precio: map['precio'] is int
          ? (map['precio'] as int).toDouble()
          : map['precio'] is double
              ? map['precio'] as double
              : double.tryParse(map['precio'].toString()) ?? 0.0,
      cantidad: map['cantidad'] as int? ?? map['stock'] as int? ?? 100,
      imagen: map['imagen'] as String? ?? map['image'] as String? ?? '',
      desc: map['desc'] as String? ?? map['description'] as String?,
    );
  }

  /// Convertir el objeto Producto a un Map para SQLite
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'imagen': imagen,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Copiar objeto con modificaciones
  Producto copyWith({
    int? id,
    String? nombre,
    double? precio,
    int? cantidad,
    String? imagen,
    String? desc,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      cantidad: cantidad ?? this.cantidad,
      imagen: imagen ?? this.imagen,
      desc: desc ?? this.desc,
    );
  }

  @override
  String toString() =>
      'Producto(id: $id, nombre: $nombre, precio: $precio, cantidad: $cantidad)';
}

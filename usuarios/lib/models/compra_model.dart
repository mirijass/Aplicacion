import 'dart:convert';

/// Modelo de Compra / Orden de Pedido
class Compra {
  final int? id;
  final int usuarioId;
  final String usuarioNombre;
  final String usuarioCorreo;
  final double total;
  final String fecha;
  final String metodoPago;
  final String estado; // 'En preparación', 'En camino', 'Entregado'
  final List<Map<String, dynamic>> items;
  final double latitud;
  final double longitud;
  final String direccionEntrega;

  Compra({
    this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioCorreo,
    required this.total,
    required this.fecha,
    required this.metodoPago,
    this.estado = 'En camino',
    required this.items,
    this.latitud = 19.432608,
    this.longitud = -99.133209,
    this.direccionEntrega = 'Av. Reforma #123, Ciudad de México',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'usuario_correo': usuarioCorreo,
      'total': total,
      'fecha': fecha,
      'metodo_pago': metodoPago,
      'estado': estado,
      'items_json': jsonEncode(items),
      'latitud': latitud,
      'longitud': longitud,
      'direccion_entrega': direccionEntrega,
    };
  }

  factory Compra.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> itemsList = [];
    if (map['items_json'] != null) {
      try {
        final decoded = jsonDecode(map['items_json'] as String);
        itemsList = List<Map<String, dynamic>>.from(decoded);
      } catch (_) {}
    }

    return Compra(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int? ?? 0,
      usuarioNombre: map['usuario_nombre'] as String? ?? 'Cliente',
      usuarioCorreo: map['usuario_correo'] as String? ?? '',
      total: (map['total'] is int)
          ? (map['total'] as int).toDouble()
          : (map['total'] as double? ?? 0.0),
      fecha: map['fecha'] as String? ?? '',
      metodoPago: map['metodo_pago'] as String? ?? 'Tarjeta de Crédito',
      estado: map['estado'] as String? ?? 'En camino',
      items: itemsList,
      latitud: (map['latitud'] is int)
          ? (map['latitud'] as int).toDouble()
          : (map['latitud'] as double? ?? 19.432608),
      longitud: (map['longitud'] is int)
          ? (map['longitud'] as int).toDouble()
          : (map['longitud'] as double? ?? -99.133209),
      direccionEntrega: map['direccion_entrega'] as String? ?? 'Dirección de Entrega',
    );
  }
}

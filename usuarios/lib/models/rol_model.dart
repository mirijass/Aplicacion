/// Modelo que representa la tabla rol_permiso en SQLite
class Rol {
  final int id;
  final String rol;

  static const String rolAdmin = 'admin';
  static const String rolEditor = 'editor';
  static const String rolLector = 'lector';

  Rol({
    required this.id,
    required this.rol,
  });

  /// Crear un objeto Rol desde un Map de SQLite
  factory Rol.fromMap(Map<String, dynamic> map) {
    return Rol(
      id: map['id'] as int,
      rol: map['rol'] as String,
    );
  }

  /// Convertir el objeto Rol a un Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rol': rol,
    };
  }

  /// Nombre formateado con mayúscula inicial
  String get rolFormateado {
    if (rol.isEmpty) return '';
    return rol[0].toUpperCase() + rol.substring(1);
  }

  @override
  String toString() => 'Rol(id: $id, rol: $rol)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rol && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Modelo que representa la tabla user_app en SQLite
class Usuario {
  final int? id;
  final String nombre;
  final String? desc;
  final String pass;
  final String correo;
  final int roleId;
  final String? rolNombre; // Nombre del rol obtenido vía JOIN
  final String? tokenRecuperacion;
  final String? tokenExpiracion;
  final String? codigoVerificacion;
  final String? codigoExpiracion;
  final String? createdAt;

  Usuario({
    this.id,
    required this.nombre,
    this.desc,
    required this.pass,
    required this.correo,
    required this.roleId,
    this.rolNombre,
    this.tokenRecuperacion,
    this.tokenExpiracion,
    this.codigoVerificacion,
    this.codigoExpiracion,
    this.createdAt,
  });

  /// Crear un objeto Usuario desde un Map de SQLite
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] != null ? map['id'] as int : null,
      nombre: map['nombre'] as String? ?? '',
      desc: map['desc'] as String?,
      pass: map['pass'] as String? ?? '',
      correo: map['correo'] as String? ?? '',
      roleId: map['role_id'] as int? ?? 3,
      rolNombre: map['rol_nombre'] as String? ?? map['rol'] as String?,
      tokenRecuperacion: map['token_recuperacion'] as String?,
      tokenExpiracion: map['token_expiracion'] as String?,
      codigoVerificacion: map['codigo_verificacion'] as String?,
      codigoExpiracion: map['codigo_expiracion'] as String?,
      createdAt: map['createdAT'] as String?,
    );
  }

  /// Convertir a Map para inserción o actualización en SQLite
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'desc': desc,
      'pass': pass,
      'correo': correo,
      'role_id': roleId,
      'token_recuperacion': tokenRecuperacion,
      'token_expiracion': tokenExpiracion,
      'codigo_verificacion': codigoVerificacion,
      'codigo_expiracion': codigoExpiracion,
    };
    if (id != null) {
      map['id'] = id;
    }
    if (createdAt != null) {
      map['createdAT'] = createdAt;
    }
    return map;
  }

  /// Copiar el objeto con campos modificados
  Usuario copyWith({
    int? id,
    String? nombre,
    String? desc,
    String? pass,
    String? correo,
    int? roleId,
    String? rolNombre,
    String? tokenRecuperacion,
    String? tokenExpiracion,
    String? codigoVerificacion,
    String? codigoExpiracion,
    String? createdAt,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      desc: desc ?? this.desc,
      pass: pass ?? this.pass,
      correo: correo ?? this.correo,
      roleId: roleId ?? this.roleId,
      rolNombre: rolNombre ?? this.rolNombre,
      tokenRecuperacion: tokenRecuperacion ?? this.tokenRecuperacion,
      tokenExpiracion: tokenExpiracion ?? this.tokenExpiracion,
      codigoVerificacion: codigoVerificacion ?? this.codigoVerificacion,
      codigoExpiracion: codigoExpiracion ?? this.codigoExpiracion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Obtener las iniciales del usuario para el avatar
  String get iniciales {
    if (nombre.trim().isEmpty) return '?';
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.length == 1) {
      return partes[0].substring(0, partes[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  /// Nombre del rol legible
  String get rolTexto {
    if (rolNombre != null && rolNombre!.isNotEmpty) {
      return rolNombre![0].toUpperCase() + rolNombre!.substring(1);
    }
    switch (roleId) {
      case 1:
        return 'Admin';
      case 2:
        return 'Editor';
      case 3:
      default:
        return 'Lector';
    }
  }

  /// Helpers de verificación de roles y permisos
  bool get esAdmin => roleId == 1;
  bool get esEditor => roleId == 2;
  bool get esLector => roleId == 3;
  bool get puedeCrearEditar => roleId == 1 || roleId == 2;
  bool get puedeEliminar => roleId == 1;

  @override
  String toString() =>
      'Usuario(id: $id, nombre: $nombre, correo: $correo, roleId: $roleId, rol: $rolNombre)';
}

enum UserRole {
  docente,
  estudiante;

  static UserRole fromString(String rol) {
    switch (rol.trim().toLowerCase()) {
      case 'docente':
        return UserRole.docente;
      case 'estudiante':
        return UserRole.estudiante;
      default:
        throw ArgumentError('Rol de usuario no reconocido: $rol');
    }
  }

  String get valor {
    switch (this) {
      case UserRole.docente:
        return 'docente';
      case UserRole.estudiante:
        return 'estudiante';
    }
  }
}

class UserProfile {
  final String id;
  final String nombre;
  final UserRole rol;
  final String? codigoAcceso;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.nombre,
    required this.rol,
    this.codigoAcceso,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawRol = map['rol']?.toString() ?? '';
    return UserProfile(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      rol: UserRole.fromString(rawRol),
      codigoAcceso: map['codigo_acceso']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'rol': rol.valor,
      'codigo_acceso': codigoAcceso,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? nombre,
    UserRole? rol,
    String? codigoAcceso,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      codigoAcceso: codigoAcceso ?? this.codigoAcceso,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

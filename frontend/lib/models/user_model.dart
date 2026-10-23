class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String nombreCompleto;
  final String? telefono;
  final String? avatarUrl;
  final String? sedePrincipalId;
  final String? programaId;
  final String rol;
  final String estado;
  final double reputacionPromedio;
  final int totalCalificaciones;
  final String? biografia;

  final String? sedeNombre;
  final String? programaNombre;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.nombreCompleto,
    this.telefono,
    this.avatarUrl,
    this.sedePrincipalId,
    this.programaId,
    this.sedeNombre,
    this.programaNombre,
    required this.rol,
    required this.estado,
    required this.reputacionPromedio,
    required this.totalCalificaciones,
    this.biografia,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      firebaseUid: json['firebase_uid'] ?? '',
      email: json['email'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      telefono: json['telefono'],
      avatarUrl: json['avatar_url'] ?? json['foto_perfil_url'],
      sedePrincipalId: json['sede_principal_id'] ?? json['sede_id'],
      programaId: json['programa_id'],
      sedeNombre: json['sede_nombre'] ?? json['sede'],
      programaNombre: json['programa_nombre'] ?? json['carrera'],
      rol: json['rol'] ?? 'ESTUDIANTE',
      estado: json['estado'] ?? (json['activo'] == false ? 'INACTIVO' : 'ACTIVO'),
      reputacionPromedio: double.tryParse(json['reputacion_promedio']?.toString() ?? '5.0') ?? 5.0,
      totalCalificaciones: json['total_calificaciones'] ?? 0,
      biografia: json['biografia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'email': email,
      'nombre_completo': nombreCompleto,
      if (telefono != null) 'telefono': telefono,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (sedePrincipalId != null) 'sede_principal_id': sedePrincipalId,
      if (programaId != null) 'programa_id': programaId,
      if (sedeNombre != null) 'sede_nombre': sedeNombre,
      if (programaNombre != null) 'programa_nombre': programaNombre,
      'rol': rol,
      'estado': estado,
      'reputacion_promedio': reputacionPromedio,
      'total_calificaciones': totalCalificaciones,
      if (biografia != null) 'biografia': biografia,
    };
  }

  bool get isAdmin => rol == 'ADMINISTRADOR' || rol == 'ADMIN';
  bool get isEstudiante => rol == 'ESTUDIANTE';
  bool get isActivo => estado == 'ACTIVO';
}

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
    final totalCalificaciones =
        int.tryParse(json['total_calificaciones']?.toString() ?? '0') ?? 0;
    final storedAverage =
        double.tryParse(json['reputacion_promedio']?.toString() ?? '0') ?? 0;
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
      estado:
          (json['is_suspended'] == true ||
              json['status'] == 'suspended' ||
              json['estado'] == 'SUSPENDIDO')
          ? 'SUSPENDIDO'
          : (json['activo'] == false
                ? 'INACTIVO'
                : (json['estado'] ?? 'ACTIVO')),
      reputacionPromedio: totalCalificaciones == 0 ? 0 : storedAverage,
      totalCalificaciones: totalCalificaciones,
      biografia: json['biografia'],
    );
  }

  Map<String, dynamic> toJson() {
    final bool suspended = (estado == 'SUSPENDIDO');
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
      'status': suspended ? 'suspended' : 'active',
      'is_suspended': suspended,
      'activo': !suspended && estado != 'INACTIVO',
      'reputacion_promedio': reputacionPromedio,
      'total_calificaciones': totalCalificaciones,
      if (biografia != null) 'biografia': biografia,
    };
  }

  bool get isAdmin =>
      rol.trim().toUpperCase() == 'ADMINISTRADOR' ||
      rol.trim().toUpperCase() == 'ADMIN' ||
      email.trim().toLowerCase() == 'vargasdeiby54@gmail.com';
  bool get isEstudiante => rol == 'ESTUDIANTE';
  bool get isSuspended => estado == 'SUSPENDIDO' || estado == 'INACTIVO';
  bool get isActivo => estado == 'ACTIVO' && !isSuspended;
}

class MensajeModel {
  final String id;
  final String conversacionId;
  final String remitenteId;
  final String contenido;
  final String tipo; // 'TEXT' | 'IMAGE'
  final String? fotoUrl;
  final bool leido;
  final DateTime createdAt;

  MensajeModel({
    required this.id,
    required this.conversacionId,
    required this.remitenteId,
    required this.contenido,
    this.tipo = 'TEXT',
    this.fotoUrl,
    required this.leido,
    required this.createdAt,
  });

  factory MensajeModel.fromJson(Map<String, dynamic> json) {
    return MensajeModel(
      id: json['id'] ?? '',
      conversacionId: json['conversacion_id'] ?? '',
      remitenteId: json['remitente_id'] ?? '',
      contenido: json['contenido'] ?? '',
      tipo: json['tipo'] ?? 'TEXT',
      fotoUrl: json['foto_url'],
      leido: json['leido'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get esImagen => tipo == 'IMAGE' && fotoUrl != null && fotoUrl!.isNotEmpty;
  bool esMio(String? myUserId) => myUserId != null && remitenteId == myUserId;
}

class ConversacionModel {
  final String id;
  final String? publicacionId;
  final String? publicacionTitulo;
  final String? publicacionPortadaUrl;
  final double? publicacionPrecio;
  final String? publicacionModalidad;
  final String usuarioUnoId;
  final String usuarioDosId;
  final String? otroUsuarioId;
  final String otroUsuarioNombre;
  final String? otroUsuarioAvatarUrl;
  final String? otroUsuarioEmail;
  final String? otroUsuarioSede;
  final int mensajesNoLeidos;
  final String? ultimoMensajeTexto;
  final String? ultimoMensajeTipo;
  final DateTime ultimoMensajeAt;
  final DateTime createdAt;

  ConversacionModel({
    required this.id,
    this.publicacionId,
    this.publicacionTitulo,
    this.publicacionPortadaUrl,
    this.publicacionPrecio,
    this.publicacionModalidad,
    required this.usuarioUnoId,
    required this.usuarioDosId,
    this.otroUsuarioId,
    required this.otroUsuarioNombre,
    this.otroUsuarioAvatarUrl,
    this.otroUsuarioEmail,
    this.otroUsuarioSede,
    required this.mensajesNoLeidos,
    this.ultimoMensajeTexto,
    this.ultimoMensajeTipo,
    required this.ultimoMensajeAt,
    required this.createdAt,
  });

  factory ConversacionModel.fromJson(Map<String, dynamic> json) {
    return ConversacionModel(
      id: json['id'] ?? '',
      publicacionId: json['publicacion_id'],
      publicacionTitulo: json['publicacion_titulo'],
      publicacionPortadaUrl: json['publicacion_portada_url'],
      publicacionPrecio: json['publicacion_precio'] != null
          ? double.tryParse(json['publicacion_precio'].toString())
          : null,
      publicacionModalidad: json['publicacion_modalidad'],
      usuarioUnoId: json['usuario_uno_id'] ?? '',
      usuarioDosId: json['usuario_dos_id'] ?? '',
      otroUsuarioId: json['otro_usuario_id'],
      otroUsuarioNombre: json['otro_usuario_nombre'] ?? 'Compañero UDEC',
      otroUsuarioAvatarUrl: json['otro_usuario_avatar_url'],
      otroUsuarioEmail: json['otro_usuario_email'],
      otroUsuarioSede: json['otro_usuario_sede'],
      mensajesNoLeidos: json['mensajes_no_leidos'] ?? 0,
      ultimoMensajeTexto: json['ultimo_mensaje_texto'],
      ultimoMensajeTipo: json['ultimo_mensaje_tipo'] ?? 'TEXT',
      ultimoMensajeAt: json['ultimo_mensaje_at'] != null
          ? DateTime.tryParse(json['ultimo_mensaje_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

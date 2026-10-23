import 'publication_model.dart';
import 'user_model.dart';

class SolicitudIntercambioModel {
  final String id;
  final String publicacionSolicitadaId;
  final String? publicacionOfrecidaId;
  final String usuarioSolicitanteId;
  final String usuarioReceptorId;
  final String mensajePropuesta;
  final String estado; // PENDIENTE, ACEPTADA, RECHAZADA, COMPLETADA
  final String? motivoRechazo;
  final DateTime createdAt;
  final PublicacionModel? publicacionSolicitada;
  final PublicacionModel? publicacionOfrecida;
  final UserModel? usuarioSolicitante;

  SolicitudIntercambioModel({
    required this.id,
    required this.publicacionSolicitadaId,
    this.publicacionOfrecidaId,
    required this.usuarioSolicitanteId,
    required this.usuarioReceptorId,
    required this.mensajePropuesta,
    required this.estado,
    this.motivoRechazo,
    required this.createdAt,
    this.publicacionSolicitada,
    this.publicacionOfrecida,
    this.usuarioSolicitante,
  });

  factory SolicitudIntercambioModel.fromJson(Map<String, dynamic> json) {
    return SolicitudIntercambioModel(
      id: json['id'] ?? '',
      publicacionSolicitadaId: json['publicacion_solicitada_id'] ?? '',
      publicacionOfrecidaId: json['publicacion_ofrecida_id'],
      usuarioSolicitanteId: json['usuario_solicitante_id'] ?? '',
      usuarioReceptorId: json['usuario_receptor_id'] ?? '',
      mensajePropuesta: json['mensaje_propuesta'] ?? '',
      estado: json['estado'] ?? 'PENDIENTE',
      motivoRechazo: json['motivo_rechazo'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      publicacionSolicitada: json['publicacion_solicitada'] != null
          ? PublicacionModel.fromJson(json['publicacion_solicitada'])
          : null,
      publicacionOfrecida: json['publicacion_ofrecida'] != null
          ? PublicacionModel.fromJson(json['publicacion_ofrecida'])
          : null,
      usuarioSolicitante: json['usuario_solicitante'] != null
          ? UserModel.fromJson(json['usuario_solicitante'])
          : null,
    );
  }

  bool get esPendiente => estado == 'PENDIENTE';
  bool get esAceptada => estado == 'ACEPTADA';
  bool get esRechazada => estado == 'RECHAZADA';
}

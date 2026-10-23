import 'institutional_model.dart';
import 'publication_model.dart';
import 'user_model.dart';

class TransaccionModel {
  final String id;
  final String publicacionId;
  final String? solicitudIntercambioId;
  final String vendedorId;
  final String compradorId;
  final String tipoTransaccion;
  final double montoPago;
  final String puntoEncuentroId;
  final DateTime fechaHoraEncuentro;
  final String codigoVerificacionEntrega;
  final String estado; // PENDIENTE_ENCUENTRO, COMPLETADA, CANCELADA
  final String? observacionesEntrega;
  final PuntoEncuentroModel? puntoEncuentro;
  final PublicacionModel? publicacion;
  final UserModel? vendedor;
  final UserModel? comprador;

  TransaccionModel({
    required this.id,
    required this.publicacionId,
    this.solicitudIntercambioId,
    required this.vendedorId,
    required this.compradorId,
    required this.tipoTransaccion,
    required this.montoPago,
    required this.puntoEncuentroId,
    required this.fechaHoraEncuentro,
    required this.codigoVerificacionEntrega,
    required this.estado,
    this.observacionesEntrega,
    this.puntoEncuentro,
    this.publicacion,
    this.vendedor,
    this.comprador,
  });

  factory TransaccionModel.fromJson(Map<String, dynamic> json) {
    return TransaccionModel(
      id: json['id'] ?? '',
      publicacionId: json['publicacion_id'] ?? '',
      solicitudIntercambioId: json['solicitud_intercambio_id'],
      vendedorId: json['vendedor_id'] ?? '',
      compradorId: json['comprador_id'] ?? '',
      tipoTransaccion: json['tipo_transaccion'] ?? 'VENTA',
      montoPago: double.tryParse(json['monto_pago']?.toString() ?? '0') ?? 0.0,
      puntoEncuentroId: json['punto_encuentro_id'] ?? '',
      fechaHoraEncuentro: json['fecha_hora_encuentro'] != null
          ? DateTime.parse(json['fecha_hora_encuentro'])
          : DateTime.now(),
      codigoVerificacionEntrega: json['codigo_verificacion_entrega'] ?? '',
      estado: json['estado'] ?? 'PENDIENTE_ENCUENTRO',
      observacionesEntrega: json['observaciones_entrega'],
      puntoEncuentro: json['punto_encuentro'] != null
          ? PuntoEncuentroModel.fromJson(json['punto_encuentro'])
          : null,
      publicacion: json['publicacion'] != null
          ? PublicacionModel.fromJson(json['publicacion'])
          : null,
      vendedor: json['vendedor'] != null ? UserModel.fromJson(json['vendedor']) : null,
      comprador: json['comprador'] != null ? UserModel.fromJson(json['comprador']) : null,
    );
  }

  bool get esCompletada => estado == 'COMPLETADA';
}

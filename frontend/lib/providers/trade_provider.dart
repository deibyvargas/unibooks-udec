import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/trade_model.dart';
import '../models/transaction_model.dart';

class TradeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<SolicitudIntercambioModel> _recibidas = [];
  List<SolicitudIntercambioModel> _enviadas = [];
  List<TransaccionModel> _transacciones = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<SolicitudIntercambioModel> get recibidas => _recibidas;
  List<SolicitudIntercambioModel> get enviadas => _enviadas;
  List<TransaccionModel> get transacciones => _transacciones;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> loadTradesAndTransactions() async {
    final uid = currentUserId;
    if (uid == null) {
      _recibidas = [];
      _enviadas = [];
      _transacciones = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Solicitudes recibidas
      final recSnap = await _firestore
          .collection('solicitudes_intercambio')
          .where('usuario_receptor_id', isEqualTo: uid)
          .get();

      _recibidas = recSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return SolicitudIntercambioModel.fromJson(data);
      }).toList();

      // 2. Solicitudes enviadas
      final envSnap = await _firestore
          .collection('solicitudes_intercambio')
          .where('usuario_solicitante_id', isEqualTo: uid)
          .get();

      _enviadas = envSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return SolicitudIntercambioModel.fromJson(data);
      }).toList();

      // 3. Transacciones (como comprador o vendedor)
      final txSnap1 = await _firestore
          .collection('transacciones')
          .where('comprador_id', isEqualTo: uid)
          .get();

      final txSnap2 = await _firestore
          .collection('transacciones')
          .where('vendedor_id', isEqualTo: uid)
          .get();

      final allTxDocs = [...txSnap1.docs, ...txSnap2.docs];
      final uniqueTxMap = <String, DocumentSnapshot>{};
      for (final doc in allTxDocs) {
        uniqueTxMap[doc.id] = doc;
      }

      _transacciones = uniqueTxMap.values.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        data['id'] = d.id;
        return TransaccionModel.fromJson(data);
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[TradeProvider] Error en loadTradesAndTransactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> proposeTrade({
    required String publicacionSolicitadaId,
    required String mensaje,
    String? publicacionOfrecidaId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Obtener publicación solicitada para saber el receptor
      final pubDoc = await _firestore.collection('publicaciones').doc(publicacionSolicitadaId).get();
      final pubData = pubDoc.data() ?? {};
      final receptorId = pubData['usuario_id'] ?? '';

      final docRef = _firestore.collection('solicitudes_intercambio').doc();
      final data = {
        'id': docRef.id,
        'publicacion_solicitada_id': publicacionSolicitadaId,
        'mensaje_propuesta': mensaje,
        if (publicacionOfrecidaId != null) 'publicacion_ofrecida_id': publicacionOfrecidaId,
        'usuario_solicitante_id': uid,
        'usuario_receptor_id': receptorId,
        'estado': 'PENDIENTE',
        'publicacion_solicitada': pubData,
        'created_at': DateTime.now().toIso8601String(),
      };

      await docRef.set(data);
      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> respondTrade(String tradeId, bool accept, {String? motivo}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nuevoEstado = accept ? 'ACEPTADA' : 'RECHAZADA';
      await _firestore.collection('solicitudes_intercambio').doc(tradeId).update({
        'estado': nuevoEstado,
        if (motivo != null) 'motivo_rechazo': motivo,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Si fue aceptada, generar la transacción automáticamente
      if (accept) {
        final tradeDoc = await _firestore.collection('solicitudes_intercambio').doc(tradeId).get();
        final tradeData = tradeDoc.data() ?? {};

        final pin = (1000 + Random().nextInt(9000)).toString();
        final txRef = _firestore.collection('transacciones').doc();
        await txRef.set({
          'id': txRef.id,
          'solicitud_intercambio_id': tradeId,
          'publicacion_id': tradeData['publicacion_solicitada_id'],
          'vendedor_id': tradeData['usuario_receptor_id'],
          'comprador_id': tradeData['usuario_solicitante_id'],
          'tipo_transaccion': 'INTERCAMBIO',
          'monto_pago': 0.0,
          'punto_encuentro_id': '44444444-4444-4444-4444-444444444401',
          'fecha_hora_encuentro': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'codigo_verificacion_entrega': pin,
          'estado': 'PENDIENTE_ENCUENTRO',
          'publicacion': tradeData['publicacion_solicitada'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmDelivery(String transactionId, String pin, {String? obs}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final doc = await _firestore.collection('transacciones').doc(transactionId).get();
      final data = doc.data() ?? {};
      final realPin = data['codigo_verificacion_entrega'] ?? '';

      if (pin.trim() != realPin.toString().trim()) {
        _errorMessage = 'El código PIN de verificación es incorrecto.';
        return false;
      }

      await _firestore.collection('transacciones').doc(transactionId).update({
        'estado': 'COMPLETADA',
        if (obs != null) 'observaciones_entrega': obs,
        'fecha_completada': DateTime.now().toIso8601String(),
      });

      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rateTransaction({
    required String transactionId,
    required int puntuacion,
    String? comentario,
    int? puntualidad,
    int? estadoLibroFiel,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final calRef = _firestore.collection('calificaciones').doc();
      await calRef.set({
        'id': calRef.id,
        'transaccion_id': transactionId,
        'evaluador_id': uid,
        'puntuacion': puntuacion,
        if (comentario != null) 'comentario': comentario,
        'puntualidad': puntualidad ?? 5,
        'estado_libro_fiel': estadoLibroFiel ?? 5,
        'created_at': DateTime.now().toIso8601String(),
      });

      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

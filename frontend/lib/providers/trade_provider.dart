import 'dart:async';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _buyerTransactionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _sellerTransactionsSub;
  final Map<String, DocumentSnapshot<Map<String, dynamic>>>
  _liveTransactionDocs = {};

  List<SolicitudIntercambioModel> get recibidas => _recibidas;
  List<SolicitudIntercambioModel> get enviadas => _enviadas;
  List<TransaccionModel> get transacciones => _transacciones;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get currentUserId => _auth.currentUser?.uid;

  void _startTransactionSync(String uid) {
    _buyerTransactionsSub?.cancel();
    _sellerTransactionsSub?.cancel();
    _liveTransactionDocs.clear();

    void updateTransactions(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        _liveTransactionDocs[doc.id] = doc;
      }
      _transacciones = _liveTransactionDocs.values.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() ?? {});
        data['id'] = doc.id;
        return TransaccionModel.fromJson(data);
      }).toList();
      notifyListeners();
    }

    _buyerTransactionsSub = _firestore
        .collection('transacciones')
        .where('comprador_id', isEqualTo: uid)
        .snapshots()
        .listen(updateTransactions);
    _sellerTransactionsSub = _firestore
        .collection('transacciones')
        .where('vendedor_id', isEqualTo: uid)
        .snapshots()
        .listen(updateTransactions);
  }

  Future<Map<String, dynamic>> _publicationSnapshot(
    String publicationId, {
    Map<String, dynamic>? fallback,
  }) async {
    if (fallback != null && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    final snapshot = await _firestore
        .collection('publicaciones')
        .doc(publicationId)
        .get();
    final data = snapshot.data() ?? <String, dynamic>{};
    data['id'] = snapshot.id;
    return data;
  }

  Future<Map<String, dynamic>> _withOwner(
    Map<String, dynamic> publication,
  ) async {
    final ownerId = publication['usuario_id'];
    if (ownerId == null || publication['usuario'] != null) {
      return publication;
    }
    final ownerSnapshot = await _firestore
        .collection('usuarios')
        .doc(ownerId)
        .get();
    if (ownerSnapshot.exists) {
      final owner = Map<String, dynamic>.from(ownerSnapshot.data() ?? {});
      owner['id'] = ownerSnapshot.id;
      publication['usuario'] = owner;
    }
    return publication;
  }

  Future<Map<String, dynamic>> _hydrateTrade(Map<String, dynamic> raw) async {
    final data = Map<String, dynamic>.from(raw);
    final requestedId = data['publicacion_solicitada_id']?.toString();
    if (requestedId != null && requestedId.isNotEmpty) {
      var requested = await _publicationSnapshot(
        requestedId,
        fallback: data['publicacion_solicitada'] is Map
            ? Map<String, dynamic>.from(data['publicacion_solicitada'])
            : null,
      );
      requested = await _withOwner(requested);
      data['publicacion_solicitada'] = requested;
    }
    final offeredId = data['publicacion_ofrecida_id']?.toString();
    if (offeredId != null && offeredId.isNotEmpty) {
      var offered = await _publicationSnapshot(
        offeredId,
        fallback: data['publicacion_ofrecida'] is Map
            ? Map<String, dynamic>.from(data['publicacion_ofrecida'])
            : null,
      );
      offered = await _withOwner(offered);
      data['publicacion_ofrecida'] = offered;
    }
    if (data['usuario_solicitante'] == null &&
        data['usuario_solicitante_id'] != null) {
      final userSnapshot = await _firestore
          .collection('usuarios')
          .doc(data['usuario_solicitante_id'])
          .get();
      if (userSnapshot.exists) {
        final user = Map<String, dynamic>.from(userSnapshot.data() ?? {});
        user['id'] = userSnapshot.id;
        data['usuario_solicitante'] = user;
      }
    }
    return data;
  }

  Future<void> loadTradesAndTransactions() async {
    final uid = currentUserId;
    if (uid == null) {
      _buyerTransactionsSub?.cancel();
      _sellerTransactionsSub?.cancel();
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

      _recibidas = (await Future.wait(
        recSnap.docs.map((d) async {
          var data = await _hydrateTrade(d.data());
          data['id'] = d.id;
          return SolicitudIntercambioModel.fromJson(data);
        }),
      )).toList();

      // 2. Solicitudes enviadas
      final envSnap = await _firestore
          .collection('solicitudes_intercambio')
          .where('usuario_solicitante_id', isEqualTo: uid)
          .get();

      _enviadas = (await Future.wait(
        envSnap.docs.map((d) async {
          var data = await _hydrateTrade(d.data());
          data['id'] = d.id;
          return SolicitudIntercambioModel.fromJson(data);
        }),
      )).toList();

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
      _startTransactionSync(uid);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[TradeProvider] Error en loadTradesAndTransactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _buyerTransactionsSub?.cancel();
    _sellerTransactionsSub?.cancel();
    super.dispose();
  }

  Future<bool> _isUserSuspended(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};
      return data['estado'] == 'SUSPENDIDO' ||
          data['status'] == 'suspended' ||
          data['is_suspended'] == true ||
          data['activo'] == false;
    } catch (_) {
      return false;
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
      if (await _isUserSuspended(uid)) {
        _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
        return false;
      }

      // Obtener publicación solicitada para saber el receptor
      final pubDoc = await _firestore
          .collection('publicaciones')
          .doc(publicacionSolicitadaId)
          .get();
      final pubData = pubDoc.data() ?? {};
      final receptorId = pubData['usuario_id'] ?? '';
      if (pubData['estado'] != null && pubData['estado'] != 'DISPONIBLE') {
        _errorMessage = 'Este libro ya no está disponible';
        return false;
      }

      final docRef = _firestore.collection('solicitudes_intercambio').doc();
      var requestedData = await _withOwner({...pubData, 'id': pubDoc.id});
      Map<String, dynamic>? offeredData;
      if (publicacionOfrecidaId != null) {
        final offeredDoc = await _firestore
            .collection('publicaciones')
            .doc(publicacionOfrecidaId)
            .get();
        if (!offeredDoc.exists) {
          _errorMessage = 'El libro ofrecido no existe';
          return false;
        }
        if (offeredDoc.data()?['usuario_id'] != uid ||
            offeredDoc.data()?['estado'] != 'DISPONIBLE') {
          _errorMessage = 'El libro ofrecido debe ser tuyo y estar disponible';
          return false;
        }
        offeredData = await _withOwner({
          ...(offeredDoc.data() ?? {}),
          'id': offeredDoc.id,
        });
      }
      final data = {
        'id': docRef.id,
        'publicacion_solicitada_id': publicacionSolicitadaId,
        'mensaje_propuesta': mensaje,
        if (publicacionOfrecidaId != null)
          'publicacion_ofrecida_id': publicacionOfrecidaId,
        'usuario_solicitante_id': uid,
        'usuario_receptor_id': receptorId,
        'estado': 'PENDIENTE',
        'publicacion_solicitada': requestedData,
        if (offeredData != null) 'publicacion_ofrecida': offeredData,
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

  Future<bool> requestAcquisition({
    required String publicacionId,
    required String puntoEncuentroId,
    required DateTime fechaEncuentro,
    required double monto,
  }) async {
    final uid = currentUserId;
    if (uid == null || await _isUserSuspended(uid)) {
      _errorMessage = 'Tu cuenta no puede realizar esta acción';
      return false;
    }
    try {
      final pub = await _firestore
          .collection('publicaciones')
          .doc(publicacionId)
          .get();
      final data = pub.data();
      if (data == null || data['estado'] != 'DISPONIBLE') {
        _errorMessage = 'Este libro ya no está disponible';
        return false;
      }
      final ref = _firestore.collection('transacciones').doc();
      await ref.set({
        'id': ref.id,
        'publicacion_id': publicacionId,
        'vendedor_id': data['usuario_id'],
        'comprador_id': uid,
        'tipo_transaccion': 'VENTA',
        'monto_pago': monto,
        'punto_encuentro_id': puntoEncuentroId,
        'fecha_hora_encuentro': fechaEncuentro.toIso8601String(),
        'codigo_verificacion_entrega': '',
        'estado': 'SOLICITUD_PENDIENTE',
        'publicacion': data,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> respondAcquisition(String transactionId, bool accept) async {
    final uid = currentUserId;
    if (uid == null || await _isUserSuspended(uid)) return false;
    try {
      final ref = _firestore.collection('transacciones').doc(transactionId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      if (data['vendedor_id'] != uid || data['estado'] != 'SOLICITUD_PENDIENTE')
        return false;
      await ref.update({
        'estado': accept ? 'PENDIENTE_ENCUENTRO' : 'CANCELADA',
        if (accept)
          'codigo_verificacion_entrega': (1000 + Random().nextInt(9000))
              .toString(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> respondTrade(
    String tradeId,
    bool accept, {
    String? motivo,
  }) async {
    final uid = currentUserId;
    if (uid != null && await _isUserSuspended(uid)) {
      _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final tradeRef = _firestore
          .collection('solicitudes_intercambio')
          .doc(tradeId);
      final tradeDoc = await tradeRef.get();
      final tradeData = tradeDoc.data() ?? {};
      if (tradeData['estado'] != 'PENDIENTE' ||
          tradeData['usuario_receptor_id'] != uid) {
        _errorMessage = 'La solicitud ya fue respondida o no te pertenece';
        return false;
      }

      if (accept) {
        final pin = (1000 + Random().nextInt(9000)).toString();
        final txRef = _firestore.collection('transacciones').doc();
        await txRef.set({
          'id': txRef.id,
          'solicitud_intercambio_id': tradeId,
          'publicacion_id': tradeData['publicacion_solicitada_id'],
          'publicacion_ofrecida_id': tradeData['publicacion_ofrecida_id'],
          'vendedor_id': tradeData['usuario_receptor_id'],
          'comprador_id': tradeData['usuario_solicitante_id'],
          'tipo_transaccion': 'INTERCAMBIO',
          'monto_pago': 0.0,
          'punto_encuentro_id': '44444444-4444-4444-4444-444444444401',
          'fecha_hora_encuentro': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
          'codigo_verificacion_entrega': pin,
          'estado': 'PENDIENTE_ENCUENTRO',
          'publicacion': tradeData['publicacion_solicitada'],
          if (tradeData['publicacion_ofrecida'] != null)
            'publicacion_ofrecida': tradeData['publicacion_ofrecida'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await tradeRef.update({
        'estado': accept ? 'ACEPTADA' : 'RECHAZADA',
        if (motivo != null) 'motivo_rechazo': motivo,
        'updated_at': DateTime.now().toIso8601String(),
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

  Future<bool> confirmDelivery(
    String transactionId,
    String pin, {
    String? obs,
  }) async {
    final uid = currentUserId;
    if (uid != null && await _isUserSuspended(uid)) {
      _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('transacciones')
          .doc(transactionId)
          .get();
      final data = doc.data() ?? {};
      if (data['vendedor_id'] != uid ||
          data['estado'] != 'PENDIENTE_ENCUENTRO') {
        _errorMessage =
            'Esta entrega todavía no está aprobada o no puedes confirmarla';
        return false;
      }
      final realPin = data['codigo_verificacion_entrega'] ?? '';

      if (pin.trim() != realPin.toString().trim()) {
        _errorMessage = 'PIN incorrecto, verifica con el solicitante';
        return false;
      }

      final now = DateTime.now().toIso8601String();

      // a) Marca la entrega como Confirmada / Entregada registrando fecha y hora
      await _firestore.collection('transacciones').doc(transactionId).update({
        'estado': 'COMPLETADA',
        if (obs != null) 'observaciones_entrega': obs,
        'fecha_completada': now,
      });

      // b) Cambia automáticamente el estado del libro a "NO_DISPONIBLE" para retirarlo del catálogo
      final publicationIds = <String>{
        if (data['publicacion_id'] != null) data['publicacion_id'].toString(),
        if (data['publicacion_ofrecida_id'] != null)
          data['publicacion_ofrecida_id'].toString(),
      };
      for (final publicacionId in publicationIds) {
        await _firestore.collection('publicaciones').doc(publicacionId).update({
          'estado': 'NO_DISPONIBLE',
          'ultima_transaccion_id': transactionId,
          'updated_at': now,
        });
        final pendingByRequested = await _firestore
            .collection('transacciones')
            .where('publicacion_id', isEqualTo: publicacionId)
            .get();
        final pendingByOffered = await _firestore
            .collection('transacciones')
            .where('publicacion_ofrecida_id', isEqualTo: publicacionId)
            .get();
        final pending = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
          for (final other in [
            ...pendingByRequested.docs,
            ...pendingByOffered.docs,
          ])
            other.id: other,
        }.values;
        for (final other in pending) {
          if (other.id != transactionId &&
              [
                'SOLICITUD_PENDIENTE',
                'PENDIENTE_ENCUENTRO',
              ].contains(other.data()['estado'])) {
            await other.reference.update({
              'estado': 'CANCELADA',
              'motivo_cancelacion': 'El libro ya fue entregado',
              'updated_at': now,
            });
          }
        }
        final tradeRequests = await _firestore
            .collection('solicitudes_intercambio')
            .where('publicacion_solicitada_id', isEqualTo: publicacionId)
            .get();
        for (final request in tradeRequests.docs) {
          if (['PENDIENTE', 'ACEPTADA'].contains(request.data()['estado'])) {
            await request.reference.update({
              'estado': 'CANCELADA',
              'updated_at': now,
            });
          }
        }
      }

      // c) Muestra una notificación de éxito a ambos usuarios confirmando que el libro ha sido entregado
      final vendedorId = data['vendedor_id'];
      final compradorId = data['comprador_id'];
      final bookTitle = data['publicacion']?['titulo'] ?? 'el libro';

      if (vendedorId != null) {
        await _firestore.collection('notificaciones').add({
          'usuario_id': vendedorId,
          'tipo': 'ENTREGA_CONFIRMADA',
          'titulo': '¡Entrega confirmada con éxito!',
          'mensaje':
              'Has completado la entrega de "$bookTitle" exitosamente en el punto de encuentro.',
          'leida': false,
          'created_at': now,
        });
      }

      if (compradorId != null) {
        await _firestore.collection('notificaciones').add({
          'usuario_id': compradorId,
          'tipo': 'ENTREGA_CONFIRMADA',
          'titulo': '¡Libro recibido con éxito!',
          'mensaje':
              'Has recibido "$bookTitle" en el campus de la universidad.',
          'leida': false,
          'created_at': now,
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
      final tx = await _firestore
          .collection('transacciones')
          .doc(transactionId)
          .get();
      final txData = tx.data() ?? {};
      final evaluationKey = 'evaluacion_$uid';
      if (txData[evaluationKey] != null) {
        _errorMessage = 'Esta entrega ya fue evaluada u omitida';
        return false;
      }
      final calRef = _firestore.collection('calificaciones').doc();
      final evaluatedId = txData['vendedor_id'] == uid
          ? txData['comprador_id']?.toString()
          : txData['vendedor_id']?.toString();
      if (evaluatedId == null || evaluatedId.isEmpty) {
        _errorMessage = 'No se pudo identificar al usuario evaluado';
        return false;
      }
      await calRef.set({
        'id': calRef.id,
        'transaccion_id': transactionId,
        'evaluador_id': uid,
        'evaluado_id': evaluatedId,
        'puntuacion': puntuacion,
        if (comentario != null) 'comentario': comentario,
        'puntualidad': puntualidad ?? 5,
        'estado_libro_fiel': estadoLibroFiel ?? 5,
        'created_at': DateTime.now().toIso8601String(),
      });
      await tx.reference.update({
        evaluationKey: {
          'estado': 'COMPLETADA',
          'puntuacion': puntuacion,
          'calificacion_id': calRef.id,
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      final ratings = await _firestore
          .collection('calificaciones')
          .where('evaluado_id', isEqualTo: evaluatedId)
          .get();
      final total = ratings.docs.length;
      final sum = ratings.docs.fold<double>(
        0,
        (current, doc) =>
            current +
            (double.tryParse(doc.data()['puntuacion'].toString()) ?? 0),
      );
      await _firestore.collection('usuarios').doc(evaluatedId).set({
        'reputacion_promedio': total == 0
            ? 0.0
            : double.parse((sum / total).toStringAsFixed(1)),
        'total_calificaciones': total,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

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

  Future<bool> skipRating(String transactionId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final ref = _firestore.collection('transacciones').doc(transactionId);
      final snap = await ref.get();
      final key = 'evaluacion_$uid';
      if ((snap.data() ?? {})[key] != null) return false;
      await ref.update({
        key: {
          'estado': 'OMITIDA',
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await loadTradesAndTransactions();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ConversacionModel> _conversaciones = [];
  final Map<String, List<MensajeModel>> _mensajesPorConversacion = {};

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  String? _activeConversacionId;

  List<ConversacionModel> get conversaciones => _conversaciones;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalNoLeidos =>
      _conversaciones.fold(0, (sum, c) => sum + c.mensajesNoLeidos);

  List<MensajeModel> getMensajes(String conversacionId) =>
      _mensajesPorConversacion[conversacionId] ?? [];

  String? get currentUserId => _auth.currentUser?.uid;

  /// Inicia la escucha en tiempo real de Firestore para la conversación activa
  void startRealtimePolling(String conversacionId) {
    _activeConversacionId = conversacionId;
    _messagesSubscription?.cancel();

    _messagesSubscription = _firestore
        .collection('chats')
        .doc(conversacionId)
        .collection('mensajes')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            final mensajes = snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              data['conversacion_id'] = conversacionId;
              return MensajeModel.fromJson(data);
            }).toList();

            _mensajesPorConversacion[conversacionId] = mensajes;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[ChatProvider] Error en stream de mensajes: $e');
          },
        );
  }

  /// Detiene la suscripción de tiempo real al salir del chat
  void stopRealtimePolling() {
    _activeConversacionId = null;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }

  /// Carga la bandeja de conversaciones activas desde Cloud Firestore
  Future<void> cargarConversaciones({bool silent = false}) async {
    final uid = currentUserId;
    if (uid == null) return;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final snap1 = await _firestore
          .collection('chats')
          .where('usuario_uno_id', isEqualTo: uid)
          .get();

      final snap2 = await _firestore
          .collection('chats')
          .where('usuario_dos_id', isEqualTo: uid)
          .get();

      final allDocs = [...snap1.docs, ...snap2.docs];
      final uniqueChats = <String, DocumentSnapshot>{};
      for (final doc in allDocs) {
        uniqueChats[doc.id] = doc;
      }

      _conversaciones = uniqueChats.values.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        data['id'] = d.id;

        // Determinar quién es el otro usuario
        final u1 = data['usuario_uno_id'] ?? '';
        final isUserOne = (u1 == uid);
        data['otro_usuario_id'] = isUserOne
            ? data['usuario_dos_id']
            : data['usuario_uno_id'];
        data['otro_usuario_nombre'] = isUserOne
            ? (data['usuario_dos_nombre'] ?? 'Compañero UDEC')
            : (data['usuario_uno_nombre'] ?? 'Compañero UDEC');
        data['otro_usuario_avatar_url'] = isUserOne
            ? data['usuario_dos_avatar_url']
            : data['usuario_uno_avatar_url'];

        return ConversacionModel.fromJson(data);
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ChatProvider] Error cargando conversaciones: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
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

  /// Inicia o abre una conversación vinculada a un libro
  Future<ConversacionModel?> iniciarOObtenerConversacion({
    required String destinatarioId,
    String? publicacionId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    if (await _isUserSuspended(uid)) {
      _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Buscar si ya existe una conversación entre estos 2 usuarios
      final snap = await _firestore
          .collection('chats')
          .where('participantes', arrayContains: uid)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final List parts = data['participantes'] ?? [];
        if (parts.contains(destinatarioId)) {
          final convMap = Map<String, dynamic>.from(data);
          convMap['id'] = doc.id;
          convMap['otro_usuario_id'] = destinatarioId;
          final conv = ConversacionModel.fromJson(convMap);
          return conv;
        }
      }

      // Obtener datos del destinatario
      final destDoc = await _firestore
          .collection('usuarios')
          .doc(destinatarioId)
          .get();
      final destData = destDoc.data() ?? {};
      final destNombre = destData['nombre_completo'] ?? 'Compañero UDEC';
      final destAvatar = destData['avatar_url'];

      // Obtener datos del usuario actual
      final myDoc = await _firestore.collection('usuarios').doc(uid).get();
      final myData = myDoc.data() ?? {};
      final myNombre =
          myData['nombre_completo'] ??
          (_auth.currentUser?.displayName ?? 'Usuario');
      final myAvatar = myData['avatar_url'];

      // Crear nueva conversación
      final docRef = _firestore.collection('chats').doc();
      final newChatData = <String, dynamic>{
        'id': docRef.id,
        'participantes': [uid, destinatarioId],
        'usuario_uno_id': uid,
        'usuario_uno_nombre': myNombre,
        if (myAvatar != null) 'usuario_uno_avatar_url': myAvatar,
        'usuario_dos_id': destinatarioId,
        'usuario_dos_nombre': destNombre,
        if (destAvatar != null) 'usuario_dos_avatar_url': destAvatar,
        if (publicacionId != null) 'publicacion_id': publicacionId,
        'mensajes_no_leidos': 0,
        'ultimo_mensaje_texto': 'Conversación iniciada',
        'ultimo_mensaje_tipo': 'TEXT',
        'ultimo_mensaje_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await docRef.set(newChatData);
      newChatData['otro_usuario_id'] = destinatarioId;
      newChatData['otro_usuario_nombre'] = destNombre;
      newChatData['otro_usuario_avatar_url'] = destAvatar;

      final conv = ConversacionModel.fromJson(newChatData);
      _conversaciones.insert(0, conv);
      return conv;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ChatProvider] Error iniciando chat: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga los mensajes de un chat específico
  Future<void> cargarMensajes(
    String conversacionId, {
    bool silent = false,
  }) async {
    try {
      final snap = await _firestore
          .collection('chats')
          .doc(conversacionId)
          .collection('mensajes')
          .orderBy('created_at', descending: false)
          .get();

      final mensajes = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['conversacion_id'] = conversacionId;
        return MensajeModel.fromJson(data);
      }).toList();

      _mensajesPorConversacion[conversacionId] = mensajes;
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  /// Envía un mensaje (texto o fotografía) directo a Firestore
  Future<bool> enviarMensaje({
    required String conversacionId,
    String? contenido,
    String tipo = 'TEXT',
    String? fotoUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;

    if (await _isUserSuspended(uid)) {
      _errorMessage = 'Tu cuenta ha sido suspendida por un administrador';
      notifyListeners();
      return false;
    }

    try {
      final msgRef = _firestore
          .collection('chats')
          .doc(conversacionId)
          .collection('mensajes')
          .doc();

      final nowIso = DateTime.now().toIso8601String();
      final msgData = <String, dynamic>{
        'id': msgRef.id,
        'conversacion_id': conversacionId,
        'remitente_id': uid,
        'contenido': contenido ?? '',
        'tipo': tipo,
        if (fotoUrl != null) 'foto_url': fotoUrl,
        'leido': false,
        'created_at': nowIso,
      };

      await msgRef.set(msgData);

      // Actualizar último mensaje del chat
      await _firestore.collection('chats').doc(conversacionId).update({
        'ultimo_mensaje_texto': tipo == 'IMAGE'
            ? '📷 Foto adjunta'
            : (contenido ?? ''),
        'ultimo_mensaje_tipo': tipo,
        'ultimo_mensaje_at': nowIso,
      });

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarMensaje({
    required String conversacionId,
    required String mensajeId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(conversacionId)
          .collection('mensajes')
          .doc(mensajeId);
      final message = await messageRef.get();
      if (!message.exists || message.data()?['remitente_id'] != uid) {
        _errorMessage = 'Solo puedes eliminar tus propios mensajes';
        notifyListeners();
        return false;
      }

      await messageRef.delete();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}

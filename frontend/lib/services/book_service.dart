import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/publication_model.dart';

/// Servicio centralizado para gestión de libros 100% nativo en Cloud Firestore
class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convierte los bytes de una foto a Data URI Base64 (100% Gratis en Cloud Firestore)
  Future<String> subirFotoLibro({
    required Uint8List bytes,
    required String libroId,
    required int indiceFoto,
    String? extension,
  }) async {
    final ext = extension ?? 'jpg';
    return 'data:image/$ext;base64,${base64Encode(bytes)}';
  }

  /// Sube un lote de imágenes a Firebase Storage y retorna la lista de URLs
  Future<List<String>> subirMultiplesFotos({
    required String libroId,
    required List<Uint8List> listaBytes,
  }) async {
    final List<String> urls = [];
    for (int i = 0; i < listaBytes.length; i++) {
      final url = await subirFotoLibro(
        bytes: listaBytes[i],
        libroId: libroId,
        indiceFoto: i,
      );
      urls.add(url);
    }
    return urls;
  }

  /// Registra una nueva publicación de libro en Cloud Firestore (colección: libros)
  Future<String> publicarLibro({
    required String titulo,
    required String autor,
    required String sedeId,
    required String condicionLibro,
    required String modalidad,
    required double precio,
    required String descripcion,
    List<String> fotosUrls = const [],
    String? editorial,
    String? edicion,
    int? anoPublicacion,
    String? isbn,
    String? materia,
    int? semestreSugerido,
    String? facultadId,
    String? interesIntercambio,
    Map<String, dynamic>? usuarioData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para publicar un libro.');
    }

    final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
    final uData = userDoc.data() ?? {};
    final bool isSuspended = uData['estado'] == 'SUSPENDIDO' ||
        uData['status'] == 'suspended' ||
        uData['is_suspended'] == true ||
        uData['activo'] == false;
    if (isSuspended) {
      throw Exception('Tu cuenta ha sido suspendida por un administrador');
    }

    final docRef = _firestore.collection('libros').doc();
    final nowIso = DateTime.now().toIso8601String();

    final libroData = <String, dynamic>{
      'id': docRef.id,
      'usuario_id': user.uid,
      'usuario_nombre': user.displayName ?? user.email?.split('@')[0],
      'usuario_email': user.email,
      'usuario': ?usuarioData,
      'titulo': titulo.trim(),
      'autor': autor.trim(),
      if (editorial != null && editorial.isNotEmpty) 'editorial': editorial.trim(),
      if (edicion != null && edicion.isNotEmpty) 'edicion': edicion.trim(),
      'ano_publicacion': ?anoPublicacion,
      if (isbn != null && isbn.isNotEmpty) 'isbn': isbn.trim(),
      if (materia != null && materia.isNotEmpty) 'materia': materia.trim(),
      'semestre_sugerido': ?semestreSugerido,
      'sede_id': sedeId,
      if (facultadId != null && facultadId.isNotEmpty) 'facultad_id': facultadId,
      'condicion_libro': condicionLibro,
      'modalidad': modalidad,
      'precio': (modalidad == 'DONACION' || modalidad == 'INTERCAMBIO') ? 0.0 : precio,
      'descripcion': descripcion.trim(),
      if (interesIntercambio != null && interesIntercambio.isNotEmpty)
        'interes_intercambio': interesIntercambio.trim(),
      'fotos_urls': fotosUrls,
      'estado': 'DISPONIBLE',
      'vistas': 0,
      'created_at': nowIso,
    };

    // Guardar en la colección 'libros' (y en 'publicaciones' para compatibilidad total)
    final batch = _firestore.batch();
    batch.set(docRef, libroData);
    final pubRef = _firestore.collection('publicaciones').doc(docRef.id);
    batch.set(pubRef, libroData);
    await batch.commit();

    return docRef.id;
  }

  /// Catálogo en tiempo real: Retorna un Stream que emite actualizaciones en vivo
  Stream<QuerySnapshot<Map<String, dynamic>>> obtenerCatalogoEnTiempoReal({
    String? sedeId,
    String? modalidad,
    String? estado = 'DISPONIBLE',
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('libros');

    if (estado != null && estado.isNotEmpty) {
      query = query.where('estado', isEqualTo: estado);
    }
    if (sedeId != null && sedeId.isNotEmpty) {
      query = query.where('sede_id', isEqualTo: sedeId);
    }
    if (modalidad != null && modalidad.isNotEmpty) {
      query = query.where('modalidad', isEqualTo: modalidad);
    }

    return query.snapshots();
  }

  /// Catálogo en tiempo real mapeado a modelos `PublicacionModel`
  Stream<List<PublicacionModel>> obtenerLibrosStream({
    String? sedeId,
    String? modalidad,
  }) {
    return obtenerCatalogoEnTiempoReal(
      sedeId: sedeId,
      modalidad: modalidad,
    ).map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return PublicacionModel.fromJson(data);
      }).toList();
    });
  }

  /// Obtiene los detalles de un libro específico en Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> obtenerDetalleLibro(String libroId) async {
    return await _firestore.collection('libros').doc(libroId).get();
  }

  /// Elimina una publicación de libro en Firestore y cancela solicitudes asociadas
  Future<void> eliminarLibro(String libroId) async {
    final doc = await _firestore.collection('publicaciones').doc(libroId).get();
    final estado = (doc.data()?['estado'] ?? 'DISPONIBLE').toString().toUpperCase().trim();
    if (estado != 'DISPONIBLE') {
      throw Exception('No se puede eliminar un libro que ya fue donado, vendido o intercambiado.');
    }

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('libros').doc(libroId));
    batch.delete(_firestore.collection('publicaciones').doc(libroId));

    final tradesSnap = await _firestore
        .collection('solicitudes_intercambio')
        .where('publicacion_solicitada_id', isEqualTo: libroId)
        .get();
    for (final doc in tradesSnap.docs) {
      batch.delete(doc.reference);
    }

    final offeredSnap = await _firestore
        .collection('solicitudes_intercambio')
        .where('publicacion_ofrecida_id', isEqualTo: libroId)
        .get();
    for (final doc in offeredSnap.docs) {
      batch.delete(doc.reference);
    }

    final txSnap = await _firestore
        .collection('transacciones')
        .where('publicacion_id', isEqualTo: libroId)
        .get();
    for (final doc in txSnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

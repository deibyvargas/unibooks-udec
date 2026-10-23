import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/institutional_model.dart';
import '../models/publication_model.dart';

class CatalogProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<PublicacionModel> _publications = [];
  List<SedeModel> _sedes = [];
  List<FacultadModel> _facultades = [];

  bool _isLoading = false;
  String? _errorMessage;

  String? _selectedSedeId;
  String? _selectedModalidad;
  String _searchQuery = '';

  List<PublicacionModel> get publications => _publications;
  List<SedeModel> get sedes => _sedes;
  List<FacultadModel> get facultades => _facultades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedSedeId => _selectedSedeId;
  String? get selectedModalidad => _selectedModalidad;
  String get searchQuery => _searchQuery;

  CatalogProvider() {
    loadInstitutionalData();
    loadCatalog();
  }

  Future<void> loadInstitutionalData() async {
    try {
      final sedesSnap = await _firestore.collection('sedes').get();
      if (sedesSnap.docs.isNotEmpty) {
        _sedes = sedesSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return SedeModel.fromJson(data);
        }).toList();
      } else {
        // Catálogo predeterminado de Sedes UDEC en la nube
        _sedes = [
          SedeModel(id: '11111111-1111-1111-1111-111111111101', nombre: 'Sede Fusagasugá (Principal)', ciudad: 'Fusagasugá', direccion: 'Diagonal 18 No. 20-29', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111102', nombre: 'Seccional Girardot', ciudad: 'Girardot', direccion: 'Carrera 19 No. 24-209', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111103', nombre: 'Seccional Ubaté', ciudad: 'Ubaté', direccion: 'Calle 6 No. 9-80', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111104', nombre: 'Extensión Facatativá', ciudad: 'Facatativá', direccion: 'Calle 8 No. 5-80', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111105', nombre: 'Extensión Chía', ciudad: 'Chía', direccion: 'Autopista Norte Km 20', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111106', nombre: 'Extensión Soacha', ciudad: 'Soacha', direccion: 'Carrera 7 No. 13-35', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111107', nombre: 'Extensión Chocontá', ciudad: 'Chocontá', direccion: 'Carrera 4 No. 5-30', activo: true),
          SedeModel(id: '11111111-1111-1111-1111-111111111108', nombre: 'Extensión Zipaquirá', ciudad: 'Zipaquirá', direccion: 'Carrera 7 No. 1-35', activo: true),
        ];
      }

      final facSnap = await _firestore.collection('facultades').get();
      if (facSnap.docs.isNotEmpty) {
        _facultades = facSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return FacultadModel.fromJson(data);
        }).toList();
      } else {
        // Catálogo predeterminado de Facultades UDEC
        _facultades = [
          FacultadModel(id: '22222222-2222-2222-2222-222222222201', nombre: 'Facultad de Ingeniería', sigla: 'FING'),
          FacultadModel(id: '22222222-2222-2222-2222-222222222202', nombre: 'Facultad de Ciencias Agropecuarias', sigla: 'FCA'),
          FacultadModel(id: '22222222-2222-2222-2222-222222222203', nombre: 'Facultad de Ciencias Administrativas, Económicas y Contables', sigla: 'FCAEC'),
          FacultadModel(id: '22222222-2222-2222-2222-222222222204', nombre: 'Facultad de Ciencias de la Salud', sigla: 'FCS'),
        ];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CatalogProvider] Error cargando sedes/facultades de Firestore: $e');
    }
  }

  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query query = _firestore.collection('publicaciones');

      if (_selectedSedeId != null && _selectedSedeId!.isNotEmpty) {
        query = query.where('sede_id', isEqualTo: _selectedSedeId);
      }
      if (_selectedModalidad != null && _selectedModalidad!.isNotEmpty) {
        query = query.where('modalidad', isEqualTo: _selectedModalidad);
      }

      final snapshot = await query.get();
      final allItems = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return PublicacionModel.fromJson(data);
      }).toList();

      // Filtrado por búsqueda en cliente
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        _publications = allItems.where((p) {
          final t = p.titulo.toLowerCase();
          final a = p.autor.toLowerCase();
          final m = (p.materia ?? '').toLowerCase();
          final d = p.descripcion.toLowerCase();
          return t.contains(q) || a.contains(q) || m.contains(q) || d.contains(q);
        }).toList();
      } else {
        _publications = allItems;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[CatalogProvider] Error en loadCatalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadCatalog();
  }

  void setSedeFilter(String? sedeId) {
    _selectedSedeId = sedeId;
    loadCatalog();
  }

  void setModalidadFilter(String? modalidad) {
    _selectedModalidad = modalidad;
    loadCatalog();
  }

  Future<bool> createPublication(Map<String, dynamic> body) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore.collection('publicaciones').doc();
      final data = Map<String, dynamic>.from(body);
      data['id'] = docRef.id;
      data['estado'] = data['estado'] ?? 'DISPONIBLE';
      data['vistas'] = data['vistas'] ?? 0;
      data['created_at'] = DateTime.now().toIso8601String();

      final batch = _firestore.batch();
      batch.set(docRef, data);
      batch.set(_firestore.collection('libros').doc(docRef.id), data);
      await batch.commit();

      await loadCatalog();
      debugPrint('[DEBUG] [CatalogProvider] Publicación creada exitosamente en Cloud Firestore.');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[DEBUG] [CatalogProvider] Error en createPublication: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

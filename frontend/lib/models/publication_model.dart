import 'institutional_model.dart';
import 'user_model.dart';

class FotoModel {
  final String id;
  final String fotoUrl;
  final bool esPortada;
  final int orden;

  FotoModel({
    required this.id,
    required this.fotoUrl,
    required this.esPortada,
    required this.orden,
  });

  factory FotoModel.fromJson(Map<String, dynamic> json) {
    return FotoModel(
      id: json['id'] ?? '',
      fotoUrl: json['foto_url'] ?? '',
      esPortada: json['es_portada'] ?? false,
      orden: json['orden'] ?? 0,
    );
  }
}

class PublicacionModel {
  final String id;
  final String usuarioId;
  final String titulo;
  final String autor;
  final String? editorial;
  final String? edicion;
  final int? anoPublicacion;
  final String? isbn;
  final String? materia;
  final int? semestreSugerido;
  final String? facultadId;
  final String sedeId;
  final String condicionLibro;
  final String modalidad; // VENTA, INTERCAMBIO, VENTA_O_INTERCAMBIO, DONACION
  final double precio;
  final String descripcion;
  final String? interesIntercambio;
  final String estado;
  final int vistas;
  final List<FotoModel> fotos;
  final UserModel? usuario;
  final SedeModel? sede;
  final FacultadModel? facultad;
  final DateTime createdAt;

  PublicacionModel({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.autor,
    this.editorial,
    this.edicion,
    this.anoPublicacion,
    this.isbn,
    this.materia,
    this.semestreSugerido,
    this.facultadId,
    required this.sedeId,
    required this.condicionLibro,
    required this.modalidad,
    required this.precio,
    required this.descripcion,
    this.interesIntercambio,
    required this.estado,
    required this.vistas,
    required this.fotos,
    this.usuario,
    this.sede,
    this.facultad,
    required this.createdAt,
  });

  factory PublicacionModel.fromJson(Map<String, dynamic> json) {
    var fotosList = <FotoModel>[];
    if (json['fotos'] != null && json['fotos'] is List) {
      fotosList = (json['fotos'] as List).map((f) {
        if (f is Map<String, dynamic>) {
          return FotoModel.fromJson(f);
        }
        return FotoModel(id: f.toString(), fotoUrl: f.toString(), esPortada: false, orden: 0);
      }).toList();
    } else if (json['fotos_urls'] != null && json['fotos_urls'] is List) {
      fotosList = (json['fotos_urls'] as List).asMap().entries.map((entry) {
        return FotoModel(
          id: 'foto_${entry.key}',
          fotoUrl: entry.value.toString(),
          esPortada: entry.key == 0,
          orden: entry.key,
        );
      }).toList();
    }

    DateTime parsedDate = DateTime.now();
    final rawDate = json['created_at'];
    if (rawDate != null) {
      if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else {
        try {
          parsedDate = (rawDate as dynamic).toDate();
        } catch (_) {}
      }
    }

    return PublicacionModel(
      id: json['id'] ?? '',
      usuarioId: json['usuario_id'] ?? '',
      titulo: json['titulo'] ?? '',
      autor: json['autor'] ?? '',
      editorial: json['editorial'],
      edicion: json['edicion'],
      anoPublicacion: json['ano_publicacion'],
      isbn: json['isbn'],
      materia: json['materia'],
      semestreSugerido: json['semestre_sugerido'],
      facultadId: json['facultad_id'],
      sedeId: json['sede_id'] ?? '',
      condicionLibro: json['condicion_libro'] ?? 'BUEN_ESTADO',
      modalidad: json['modalidad'] ?? 'VENTA_O_INTERCAMBIO',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      descripcion: json['descripcion'] ?? '',
      interesIntercambio: json['interes_intercambio'],
      estado: json['estado'] ?? 'DISPONIBLE',
      vistas: json['vistas'] ?? 0,
      fotos: fotosList,
      usuario: json['usuario'] != null ? UserModel.fromJson(Map<String, dynamic>.from(json['usuario'])) : null,
      sede: json['sede'] != null ? SedeModel.fromJson(Map<String, dynamic>.from(json['sede'])) : null,
      facultad: json['facultad'] != null ? FacultadModel.fromJson(Map<String, dynamic>.from(json['facultad'])) : null,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'titulo': titulo,
      'autor': autor,
      if (editorial != null) 'editorial': editorial,
      if (edicion != null) 'edicion': edicion,
      if (anoPublicacion != null) 'ano_publicacion': anoPublicacion,
      if (isbn != null) 'isbn': isbn,
      if (materia != null) 'materia': materia,
      if (semestreSugerido != null) 'semestre_sugerido': semestreSugerido,
      if (facultadId != null) 'facultad_id': facultadId,
      'sede_id': sedeId,
      'condicion_libro': condicionLibro,
      'modalidad': modalidad,
      'precio': precio,
      'descripcion': descripcion,
      if (interesIntercambio != null) 'interes_intercambio': interesIntercambio,
      'estado': estado,
      'vistas': vistas,
      'fotos_urls': fotos.map((f) => f.fotoUrl).toList(),
      if (usuario != null) 'usuario': usuario!.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get portadaUrl {
    if (fotos.isNotEmpty) {
      final portada = fotos.firstWhere((f) => f.esPortada, orElse: () => fotos.first);
      return portada.fotoUrl;
    }
    return 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c';
  }

  bool get esVenta => modalidad == 'VENTA' || modalidad == 'VENTA_O_INTERCAMBIO';
  bool get esTrueque => modalidad == 'INTERCAMBIO' || modalidad == 'VENTA_O_INTERCAMBIO';
  bool get esDonacion => modalidad == 'DONACION';
}

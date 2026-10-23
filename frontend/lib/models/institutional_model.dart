class SedeModel {
  final String id;
  final String nombre;
  final String ciudad;
  final String direccion;
  final bool activo;

  SedeModel({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.direccion,
    required this.activo,
  });

  factory SedeModel.fromJson(Map<String, dynamic> json) {
    return SedeModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      ciudad: json['ciudad'] ?? '',
      direccion: json['direccion'] ?? '',
      activo: json['activo'] ?? true,
    );
  }
}

class FacultadModel {
  final String id;
  final String nombre;
  final String? sigla;

  FacultadModel({
    required this.id,
    required this.nombre,
    this.sigla,
  });

  factory FacultadModel.fromJson(Map<String, dynamic> json) {
    return FacultadModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      sigla: json['sigla'],
    );
  }
}

class PuntoEncuentroModel {
  final String id;
  final String sedeId;
  final String nombre;
  final String descripcion;
  final String? referenciaVisual;

  PuntoEncuentroModel({
    required this.id,
    required this.sedeId,
    required this.nombre,
    required this.descripcion,
    this.referenciaVisual,
  });

  factory PuntoEncuentroModel.fromJson(Map<String, dynamic> json) {
    return PuntoEncuentroModel(
      id: json['id'] ?? '',
      sedeId: json['sede_id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      referenciaVisual: json['referencia_visual'],
    );
  }
}

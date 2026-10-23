import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_colors.dart';
import '../services/image_upload_service.dart';
import 'app_network_image.dart';

/// Elemento representativo de una foto (local en memoria o URL remota)
class BookPhotoItem {
  final String? url;
  final PickedImageResult? localImage;
  final String label;

  BookPhotoItem.fromUrl(this.url, {this.label = 'Foto'}) : localImage = null;
  BookPhotoItem.fromLocal(this.localImage, {this.label = 'Foto'}) : url = null;

  bool get isLocal => localImage != null;
  Uint8List? get bytes => localImage?.bytes;
}

class BookImagePickerWidget extends StatefulWidget {
  final List<BookPhotoItem> initialPhotos;
  final int maxPhotos;
  final ValueChanged<List<BookPhotoItem>> onPhotosChanged;

  const BookImagePickerWidget({
    super.key,
    required this.initialPhotos,
    this.maxPhotos = 4,
    required this.onPhotosChanged,
  });

  @override
  State<BookImagePickerWidget> createState() => BookImagePickerWidgetState();
}

class BookImagePickerWidgetState extends State<BookImagePickerWidget> {
  late List<BookPhotoItem> _photos;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
  }

  void _notifyChange() {
    widget.onPhotosChanged(_photos);
    setState(() {});
  }

  Future<void> _addFromCamera() async {
    if (_photos.length >= widget.maxPhotos) return;
    final picked = await ImageUploadService.pickImage(
      context: context,
      directSource: ImageSource.camera,
    );
    if (picked != null) {
      _photos.add(BookPhotoItem.fromLocal(
        picked,
        label: _photos.isEmpty ? 'Portada' : 'Foto ${_photos.length + 1}',
      ));
      _notifyChange();
    }
  }

  Future<void> _addFromGallery() async {
    final remaining = widget.maxPhotos - _photos.length;
    if (remaining <= 0) return;

    if (remaining == 1) {
      final picked = await ImageUploadService.pickImage(
        context: context,
        directSource: ImageSource.gallery,
      );
      if (picked != null) {
        _photos.add(BookPhotoItem.fromLocal(
          picked,
          label: _photos.isEmpty ? 'Portada' : 'Foto ${_photos.length + 1}',
        ));
        _notifyChange();
      }
    } else {
      final pickedList = await ImageUploadService.pickMultipleImages(maxImages: remaining);
      for (final picked in pickedList) {
        if (_photos.length < widget.maxPhotos) {
          _photos.add(BookPhotoItem.fromLocal(
            picked,
            label: _photos.isEmpty ? 'Portada' : 'Foto ${_photos.length + 1}',
          ));
        }
      }
      _notifyChange();
    }
  }

  void _showAddPhotoModal() {
    if (_photos.length >= widget.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se permite un máximo de ${widget.maxPhotos} fotos por ejemplar.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Agregar Fotos del Libro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Muestra el estado físico real (portada, contraportada, hojas). Disponibles: ${widget.maxPhotos - _photos.length} cupos.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Tomar Foto con Cámara'),
                subtitle: const Text('Captura instantánea desde tu teléfono'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.photo_library_rounded, color: Colors.blue),
                ),
                title: const Text('Seleccionar de la Galería'),
                subtitle: const Text('Permite selección múltiple de fotos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addFromGallery();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.menu_book_rounded, color: Colors.orange),
                ),
                title: const Text('Cargar Foto de Muestra Universitaria'),
                subtitle: const Text('Imagen de biblioteca académica'),
                onTap: () {
                  Navigator.pop(ctx);
                  _photos.add(BookPhotoItem.fromUrl(
                    'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600',
                    label: _photos.isEmpty ? 'Portada' : 'Foto ${_photos.length + 1}',
                  ));
                  _notifyChange();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    _photos.removeAt(index);
    _notifyChange();
  }

  /// Sube secuencialmente a Firebase Storage / Backend todas las fotos locales
  /// y retorna la lista completa de URLs definitivas
  Future<List<String>> uploadAllPhotos({required String bookId}) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusMessage = 'Iniciando subida de fotos...';
    });

    final List<String> finalUrls = [];
    final total = _photos.length;

    try {
      for (int i = 0; i < total; i++) {
        final item = _photos[i];
        if (item.isLocal && item.bytes != null) {
          setState(() {
            _uploadStatusMessage = 'Subiendo foto ${i + 1} de $total...';
            _uploadProgress = (i) / total;
          });

          final storagePath = ImageUploadService.bookImagePath(bookId, i);
          final url = await ImageUploadService.uploadImageBytes(
            bytes: item.bytes!,
            storagePath: storagePath,
            originalFileName: item.localImage?.fileName,
          );
          finalUrls.add(url);
        } else if (item.url != null && item.url!.isNotEmpty) {
          finalUrls.add(item.url!);
        }
      }

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatusMessage = '¡Fotos subidas exitosamente!';
      });
      return finalUrls;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Galería del Libro (1 a 4 fotos) *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '${_photos.length}/${widget.maxPhotos} fotos',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Barra de progreso de subida activa
        if (_isUploading) ...[
          LinearProgressIndicator(value: _uploadProgress, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            _uploadStatusMessage,
            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],

        // Grilla horizontal interactiva con miniaturas locales / remotas
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._photos.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 14, top: 4),
                      width: 82,
                      height: 98,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: idx == 0 ? AppColors.primary : AppColors.cardBorder,
                          width: idx == 0 ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.isLocal
                            ? Image.memory(
                                item.bytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _errorPlaceholder(),
                              )
                            : AppNetworkImage(
                                url: item.url,
                                fit: BoxFit.cover,
                                errorWidget: _errorPlaceholder(),
                              ),
                      ),
                    ),

                    // Badge de Portada
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: idx == 0 ? AppColors.primary : Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          idx == 0 ? 'Portada' : 'Foto ${idx + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Botón rojo 'X' para eliminar antes de publicar
                    Positioned(
                      top: 0,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removePhoto(idx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 3),
                            ],
                          ),
                          child: const Icon(Icons.close, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),

              // Botón '+' para agregar fotos faltantes
              if (_photos.length < widget.maxPhotos)
                GestureDetector(
                  onTap: _showAddPhotoModal,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 82,
                    height: 98,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Agregar',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
      ),
    );
  }
}

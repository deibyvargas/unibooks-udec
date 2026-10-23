import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_colors.dart';

/// Resultado enriquecido de la selección local de imagen
class PickedImageResult {
  final XFile file;
  final Uint8List bytes;
  final String fileName;

  PickedImageResult({
    required this.file,
    required this.bytes,
    required this.fileName,
  });
}

/// Servicio centralizado para captura, compresión local y subida de imágenes
/// Directo a Google Firebase Storage en la nube (sin servidores intermedios)
class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  // ===========================================================================
  // ESTRUCTURA ESTÁNDAR DE CARPETAS EN FIREBASE STORAGE
  // ===========================================================================
  static String userAvatarPath(String userId) => 'usuarios/$userId/avatar.jpg';
  static String bookImagePath(String libroId, int index) => 'libros/$libroId/foto_$index.jpg';
  static String chatMediaPath(String chatId) =>
      'chats/$chatId/media/${DateTime.now().millisecondsSinceEpoch}.jpg';

  // ===========================================================================
  // MODAL BOTTOM SHEET ESTILO WHATSAPP PARA ELEGIR CÁMARA O GALERÍA
  // ===========================================================================
  static Future<ImageSource?> showImageSourceModal(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seleccionar Fotografía',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Elige la fuente de imagen para tu evidencia en Unibooks:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton(
                      context: ctx,
                      icon: Icons.camera_alt_rounded,
                      label: 'Cámara',
                      color: const Color(0xFF00A884), // WhatsApp camera green
                      source: ImageSource.camera,
                    ),
                    _buildOptionButton(
                      context: ctx,
                      icon: Icons.photo_library_rounded,
                      label: 'Galería',
                      color: const Color(0xFF53BDEB), // Soft cyan
                      source: ImageSource.gallery,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required ImageSource source,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context, source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SELECCIÓN Y COMPRESIÓN DE FOTO INDIVIDUAL (CÁMARA O GALERÍA)
  // Max 1080px de ancho y calidad al 80%
  // ===========================================================================
  static Future<PickedImageResult?> pickImage({
    required BuildContext context,
    ImageSource? directSource,
  }) async {
    final source = directSource ?? await showImageSourceModal(context);
    if (source == null) return null;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile == null) return null;

      final bytes = await pickedFile.readAsBytes();
      return PickedImageResult(
        file: pickedFile,
        bytes: bytes,
        fileName: pickedFile.name,
      );
    } catch (e) {
      debugPrint('[ImageUploadService] Error al capturar imagen: $e');
      return null;
    }
  }

  // ===========================================================================
  // SELECCIÓN MÚLTIPLE DE FOTOS (ENTRE 1 Y 4 FOTOS DE LIBROS)
  // Max 800px de ancho y calidad al 70% para compresión óptima
  // ===========================================================================
  static Future<List<PickedImageResult>> pickMultipleImages({int maxImages = 4}) async {
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      final selected = pickedList.take(maxImages).toList();
      final List<PickedImageResult> results = [];

      for (final file in selected) {
        final bytes = await file.readAsBytes();
        results.add(PickedImageResult(
          file: file,
          bytes: bytes,
          fileName: file.name,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('[ImageUploadService] Error al seleccionar múltiples imágenes: $e');
      return [];
    }
  }

  // ===========================================================================
  // PROCESAMIENTO Y ALMACENAMIENTO DE IMÁGENES EN CLOUD FIRESTORE (100% GRATIS)
  // Almacenamiento directo en Base64 Data URI dentro del documento de Firestore
  // Sin requerir tarjeta de crédito ni plan de pago Blaze de Firebase Storage
  // ===========================================================================
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String storagePath,
    String? originalFileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.2);

    final cleanFileName = originalFileName ?? storagePath.split('/').last;

    // Determinar subtipo MIME según extensión
    String mimeSubtype = 'jpeg';
    final lowerName = cleanFileName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      mimeSubtype = 'png';
    } else if (lowerName.endsWith('.webp')) {
      mimeSubtype = 'webp';
    } else if (lowerName.endsWith('.gif')) {
      mimeSubtype = 'gif';
    }

    try {
      debugPrint('[DEBUG] [ImageUploadService] Codificando imagen optimizada para Firestore ($mimeSubtype, ${bytes.lengthInBytes} bytes)...');
      onProgress?.call(0.6);
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/$mimeSubtype;base64,$base64String';
      onProgress?.call(1.0);
      debugPrint('[DEBUG] [ImageUploadService] Imagen lista en formato Data URI Base64 (Almacenamiento Cloud Firestore).');
      return dataUri;
    } catch (e) {
      debugPrint('[ImageUploadService] Error al codificar imagen a Base64: $e');
      throw Exception('Error al codificar imagen: $e');
    }
  }
}

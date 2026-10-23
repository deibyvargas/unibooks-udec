import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/image_upload_service.dart';
import 'app_network_image.dart';

/// Widget interactivo para visualización y actualización de avatar de perfil estudiantil
/// Permite recortar/elegir foto desde cámara o galería y sincroniza con PostgreSQL y Storage
class ProfileAvatarPicker extends StatefulWidget {
  final double radius;
  final VoidCallback? onUpdateSuccess;

  const ProfileAvatarPicker({
    super.key,
    this.radius = 48,
    this.onUpdateSuccess,
  });

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  bool _isUploading = false;
  Uint8List? _previewBytes;

  Future<void> _changeAvatar() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final picked = await ImageUploadService.pickImage(context: context);
    if (picked == null || !mounted) return;

    setState(() {
      _previewBytes = picked.bytes;
      _isUploading = true;
    });

    try {
      final storagePath = ImageUploadService.userAvatarPath(user.id);
      final downloadUrl = await ImageUploadService.uploadImageBytes(
        bytes: picked.bytes,
        storagePath: storagePath,
        originalFileName: picked.fileName,
      );

      final success = await auth.updateAvatar(downloadUrl);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada en Unibooks UDEC'),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onUpdateSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Error al sincronizar con el servidor'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir la fotografía: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final avatarUrl = user?.avatarUrl;
    final initials = user != null && user.nombreCompleto.isNotEmpty
        ? user.nombreCompleto[0].toUpperCase()
        : 'U';

    return Stack(
      children: [
        // Avatar circular con soporte de bytes locales y URLs remotas
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: _isUploading
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                )
              : _previewBytes != null
                  ? ClipOval(
                      child: Image.memory(
                        _previewBytes!,
                        width: widget.radius * 2,
                        height: widget.radius * 2,
                        fit: BoxFit.cover,
                      ),
                    )
                  : avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: AppNetworkImage(
                            url: avatarUrl,
                            width: widget.radius * 2,
                            height: widget.radius * 2,
                            fit: BoxFit.cover,
                            errorWidget: _buildFallbackInitials(initials),
                          ),
                        )
                      : _buildFallbackInitials(initials),
        ),

        // Botón de lápiz/cámara superpuesto en la esquina inferior derecha
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploading ? null : _changeAvatar,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitials(String initials) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: widget.radius * 0.75,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}

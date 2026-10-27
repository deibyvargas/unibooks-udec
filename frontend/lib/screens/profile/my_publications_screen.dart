import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_network_image.dart';

class MyPublicationsScreen extends StatelessWidget {
  const MyPublicationsScreen({super.key});

  Future<void> _deletePublication(
    BuildContext context,
    String publicationId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('publicaciones').doc(publicationId).get();
    final estado = (doc.data()?['estado'] ?? 'DISPONIBLE').toString().toUpperCase().trim();
    if (estado != 'DISPONIBLE') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este libro ya no está disponible y no se puede eliminar.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final batch = firestore.batch();
    batch.delete(firestore.collection('publicaciones').doc(publicationId));
    batch.delete(firestore.collection('libros').doc(publicationId));

    final requests = await firestore
        .collection('solicitudes_intercambio')
        .where('publicacion_solicitada_id', isEqualTo: publicationId)
        .get();
    for (final doc in requests.docs) {
      batch.delete(doc.reference);
    }

    final offeredRequests = await firestore
        .collection('solicitudes_intercambio')
        .where('publicacion_ofrecida_id', isEqualTo: publicationId)
        .get();
    for (final doc in offeredRequests.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publicación eliminada correctamente.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: Text(
          '¿Deseas eliminar "$title"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await _deletePublication(context, id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar la publicación: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('No hay sesión activa')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('publicaciones')
        .where('usuario_id', isEqualTo: uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Publicaciones')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar publicaciones: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Aún no has publicado ningún libro.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = (data['estado'] ?? 'DISPONIBLE').toString().toUpperCase().trim();
              final available = status == 'DISPONIBLE';
              final photos = data['fotos_urls'] as List?;
              final imageUrl = photos != null && photos.isNotEmpty
                  ? photos.first.toString()
                  : '';

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: SizedBox(
                    width: 52,
                    height: 70,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.menu_book_rounded, size: 36)
                        : AppNetworkImage(url: imageUrl, fit: BoxFit.cover),
                  ),
                  title: Text(
                    data['titulo']?.toString() ?? 'Sin título',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      available ? 'Disponible' : 'NO DISPONIBLE',
                      style: TextStyle(
                        color: available ? AppColors.success : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: available ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                  trailing: available
                      ? IconButton(
                          tooltip: 'Eliminar publicación',
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _confirmDelete(
                            context,
                            doc.id,
                            data['titulo']?.toString() ?? 'este libro',
                          ),
                        )
                      : const Tooltip(
                          message: 'NO DISPONIBLE',
                          child: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

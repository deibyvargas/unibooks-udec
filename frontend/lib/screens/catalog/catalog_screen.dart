import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/publication_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import 'book_detail_screen.dart';
import '../publications/create_publication_screen.dart';
import '../../widgets/app_network_image.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  Future<void> _confirmDeleteBook(BuildContext context, PublicacionModel book) async {
    final estado = book.estado.toUpperCase().trim();
    if (estado != 'DISPONIBLE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar un libro que ya fue donado, vendido o intercambiado.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirmar eliminación de libro'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar permanentemente "${book.titulo}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta acción es irreversible: el libro será retirado del catálogo inmediatamente y se cancelarán '
              'automáticamente las solicitudes de intercambio y reservas pendientes asociadas.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar libro'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final success = await context.read<CatalogProvider>().deletePublication(book.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Libro eliminado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<CatalogProvider>().errorMessage ?? 'Error al eliminar libro',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final isAdmin = context.watch<AuthProvider>().currentUser?.isAdmin == true;
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Catálogo Unibooks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Universidad de Cundinamarca',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar catálogo',
            onPressed: () => catalog.loadCatalog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Búsqueda
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => catalog.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Buscar por título, autor, materia o ISBN...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => catalog.setSearchQuery(''),
                ),
              ),
            ),
          ),

          // Chips de Filtro por Sede Universitaria
          Container(
            color: Colors.white,
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _FilterChip(
                  label: 'Todas las Sedes',
                  isSelected: catalog.selectedSedeId == null,
                  onSelected: () => catalog.setSedeFilter(null),
                ),
                ...catalog.sedes.map((sede) => _FilterChip(
                  label: sede.nombre.replaceAll(' (Principal)', '').replaceAll('Seccional ', '').replaceAll('Extensión ', ''),
                  isSelected: catalog.selectedSedeId == sede.id,
                  onSelected: () => catalog.setSedeFilter(sede.id),
                )),
              ],
            ),
          ),

          // Chips de Filtro por Modalidad (Venta / Trueque / Donación)
          Container(
            color: Colors.white,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                _ModalidadChip(
                  label: 'Todos',
                  color: AppColors.primary,
                  isSelected: catalog.selectedModalidad == null,
                  onTap: () => catalog.setModalidadFilter(null),
                ),
                const SizedBox(width: 8),
                _ModalidadChip(
                  label: 'Venta',
                  color: AppColors.badgeVenta,
                  isSelected: catalog.selectedModalidad == 'VENTA',
                  onTap: () => catalog.setModalidadFilter('VENTA'),
                ),
                const SizedBox(width: 8),
                _ModalidadChip(
                  label: 'Trueque',
                  color: AppColors.badgeTrueque,
                  isSelected: catalog.selectedModalidad == 'INTERCAMBIO',
                  onTap: () => catalog.setModalidadFilter('INTERCAMBIO'),
                ),
                const SizedBox(width: 8),
                _ModalidadChip(
                  label: 'Donación',
                  color: AppColors.badgeDonacion,
                  isSelected: catalog.selectedModalidad == 'DONACION',
                  onTap: () => catalog.setModalidadFilter('DONACION'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),

          // Barra de Conteo de Resultados y Restablecimiento
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${catalog.publications.length} libros disponibles en UDEC',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                if (catalog.selectedSedeId != null || catalog.selectedModalidad != null || catalog.searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () {
                      catalog.setSedeFilter(null);
                      catalog.setModalidadFilter(null);
                      catalog.setSearchQuery('');
                    },
                    child: const Text(
                      'Restablecer filtros',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),

          // Listado de Libros
          Expanded(
            child: catalog.isLoading
                ? const Center(child: CircularProgressIndicator())
                : catalog.publications.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 64,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Aún no hay libros publicados. ¡Sé el primero en publicar uno!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Comparte tus libros académicos para venta, intercambio o donación en la comunidad UDEC.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: const Text('Crear Publicación'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreatePublicationScreen()),
                                  );
                                },
                              ),
                              if (catalog.selectedSedeId != null || catalog.selectedModalidad != null || catalog.searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    catalog.setSedeFilter(null);
                                    catalog.setModalidadFilter(null);
                                    catalog.setSearchQuery('');
                                  },
                                  child: const Text('Restablecer filtros'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 3
                                  : 2;

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: catalog.publications.length,
                            itemBuilder: (context, index) {
                              final book = catalog.publications[index];
                              final isDisponible = book.estado.toUpperCase().trim() == 'DISPONIBLE';
                              return _BookGridCard(
                                book: book,
                                currencyFormatter: currencyFormatter,
                                isAdmin: isAdmin,
                                onDelete: (isAdmin && isDisponible)
                                    ? () => _confirmDeleteBook(context, book)
                                    : null,
                                onTap: () async {
                                  final deleted = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookDetailScreen(bookId: book.id),
                                    ),
                                  );
                                  if (deleted == true && context.mounted) {
                                    context.read<CatalogProvider>().removeLocalPublication(book.id);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withOpacity(0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ModalidadChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModalidadChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(isSelected ? 1.0 : 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  final PublicacionModel book;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback? onDelete;

  const _BookGridCard({
    required this.book,
    required this.currencyFormatter,
    required this.onTap,
    this.isAdmin = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = AppColors.badgeVenta;
    String badgeText = 'VENTA';
    if (book.modalidad == 'INTERCAMBIO') {
      badgeColor = AppColors.badgeTrueque;
      badgeText = 'TRUEQUE';
    } else if (book.modalidad == 'DONACION') {
      badgeColor = AppColors.badgeDonacion;
      badgeText = 'DONACIÓN';
    } else if (book.modalidad == 'VENTA_O_INTERCAMBIO') {
      badgeColor = AppColors.primary;
      badgeText = 'VENTA O MATCH';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de Portada con Badge
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: book.portadaUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin && onDelete != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Tooltip(
                        message: 'Eliminar libro (Admin)',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delete_forever_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Información del Libro
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (book.esVenta && book.precio > 0)
                      Text(
                        currencyFormatter.format(book.precio),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(
                        book.modalidad == 'DONACION' ? 'Gratis (Donación)' : 'Intercambio',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            book.sede?.nombre ?? 'UDEC',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

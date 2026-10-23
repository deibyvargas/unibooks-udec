import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import 'chat_detail_screen.dart';
import '../../widgets/app_network_image.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().cargarConversaciones();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatFecha(DateTime fecha) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);

    if (fechaDia == hoy) {
      return DateFormat('hh:mm a').format(fecha);
    } else if (fechaDia == hoy.subtract(const Duration(days: 1))) {
      return 'Ayer';
    } else {
      return DateFormat('dd/MM/yyyy').format(fecha);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final todas = chatProvider.conversaciones;

    final conversaciones = todas.where((c) {
      if (_filterText.isEmpty) return true;
      final term = _filterText.toLowerCase();
      final nombre = c.otroUsuarioNombre.toLowerCase();
      final libro = (c.publicacionTitulo ?? '').toLowerCase();
      return nombre.contains(term) || libro.contains(term);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Mensajería UDEC'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar Conversaciones',
            onPressed: () => chatProvider.cargarConversaciones(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chatProvider.cargarConversaciones(),
        child: Column(
          children: [
            // Barra de búsqueda rápida
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _filterText = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar por compañero o título de libro...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _filterText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filterText = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Lista de Conversaciones o Estados
            Expanded(
              child: chatProvider.isLoading && todas.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : conversaciones.isEmpty
                      ? _buildEmptyState(_filterText.isNotEmpty)
                      : ListView.separated(
                          itemCount: conversaciones.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: AppColors.cardBorder,
                          ),
                          itemBuilder: (context, index) {
                            final conv = conversaciones[index];
                            return _buildConversationTile(conv);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversacionModel conv) {
    final tieneNoLeidos = conv.mensajesNoLeidos > 0;
    final esImagen = conv.ultimoMensajeTipo == 'IMAGE';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(conversacion: conv),
          ),
        );
        if (mounted) {
          context.read<ChatProvider>().cargarConversaciones(silent: true);
        }
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            backgroundImage: conv.otroUsuarioAvatarUrl != null
                ? appImageProvider(conv.otroUsuarioAvatarUrl!)
                : null,
            child: conv.otroUsuarioAvatarUrl == null
                ? Text(
                    conv.otroUsuarioNombre.isNotEmpty ? conv.otroUsuarioNombre[0] : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              conv.otroUsuarioNombre,
              style: TextStyle(
                fontWeight: tieneNoLeidos ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatFecha(conv.ultimoMensajeAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: tieneNoLeidos ? FontWeight.bold : FontWeight.normal,
              color: tieneNoLeidos ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          // Chip indicador del libro negociado
          if (conv.publicacionTitulo != null)
            Row(
              children: [
                const Icon(Icons.book_outlined, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    conv.publicacionTitulo!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 3),
          // Último mensaje
          Row(
            children: [
              if (esImagen) ...[
                const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  conv.ultimoMensajeTexto ?? 'Conversación activa',
                  style: TextStyle(
                    fontSize: 13,
                    color: tieneNoLeidos ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: tieneNoLeidos ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tieneNoLeidos)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${conv.mensajesNoLeidos}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isFiltering) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltering
                  ? 'No se encontraron conversaciones'
                  : 'Aún no tienes conversaciones de libros',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Prueba con otro nombre de estudiante o título de libro.'
                  : 'Cuando encuentres un libro en el Catálogo institucional, presiona "Contactar por Chat" para acordar el trueque o la compra.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

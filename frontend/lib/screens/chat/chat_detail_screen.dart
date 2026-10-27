import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/image_upload_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/chat_photo_preview_screen.dart';
import '../../widgets/app_network_image.dart';

/// Modelo de mensaje local optimista mientras se sube a Firebase Storage / Backend
class PendingChatImage {
  final String id;
  final Uint8List bytes;
  final String caption;
  final DateTime createdAt;
  bool isUploading;
  String? error;

  PendingChatImage({
    required this.id,
    required this.bytes,
    required this.caption,
    required this.createdAt,
    this.isUploading = true,
    this.error,
  });
}

class ChatDetailScreen extends StatefulWidget {
  final ConversacionModel conversacion;

  const ChatDetailScreen({super.key, required this.conversacion});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<PendingChatImage> _pendingImages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final chatProvider = context.read<ChatProvider>();
    chatProvider.cargarMensajes(widget.conversacion.id);
    chatProvider.startRealtimePolling(widget.conversacion.id);

    // Auto scroll al cargar
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    context.read<ChatProvider>().stopRealtimePolling();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _enviarTexto(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    setState(() => _isSending = true);

    final success = await context.read<ChatProvider>().enviarMensaje(
      conversacionId: widget.conversacion.id,
      contenido: clean,
      tipo: 'TEXT',
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _scrollToBottom();
      }
    }
  }

  /// Flujo completo estilo WhatsApp:
  /// 1. Captura con compresión (max 1080px, 80% calidad)
  /// 2. Previsualización y edición de pie de foto en ChatPhotoPreviewScreen
  /// 3. Inserción optimista de burbuja 'Subiendo...'
  /// 4. Subida a Firebase Storage y confirmación a 'Enviado' con doble check
  Future<void> _capturarYEnviarFoto(ImageSource source) async {
    final picked = await ImageUploadService.pickImage(
      context: context,
      directSource: source,
    );

    if (picked == null || !mounted) return;

    // Mostrar pantalla de previsualización previa al envío
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPhotoPreviewScreen(
          imageBytes: picked.bytes,
          fileName: picked.fileName,
        ),
      ),
    );

    if (result != null && result['confirmed'] == true && mounted) {
      final caption = (result['caption'] as String?) ?? '';
      _procesarEnvioLocal(picked.bytes, caption, picked.fileName);
    }
  }

  Future<void> _procesarEnvioLocal(
    Uint8List bytes,
    String caption,
    String fileName,
  ) async {
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pendingMsg = PendingChatImage(
      id: pendingId,
      bytes: bytes,
      caption: caption,
      createdAt: DateTime.now(),
    );

    setState(() {
      _pendingImages.add(pendingMsg);
    });
    _scrollToBottom();

    try {
      final storagePath = ImageUploadService.chatMediaPath(
        widget.conversacion.id,
      );
      final downloadUrl = await ImageUploadService.uploadImageBytes(
        bytes: bytes,
        storagePath: storagePath,
        originalFileName: fileName,
      );

      if (!mounted) return;

      final success = await context.read<ChatProvider>().enviarMensaje(
        conversacionId: widget.conversacion.id,
        contenido: caption,
        tipo: 'IMAGE',
        fotoUrl: downloadUrl,
      );

      if (mounted) {
        setState(() {
          _pendingImages.removeWhere((item) => item.id == pendingId);
        });
        if (success) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pendingMsg.isUploading = false;
          pendingMsg.error = 'Fallo al subir: $e';
        });
      }
    }
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
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
                Row(
                  children: const [
                    Icon(Icons.photo_library_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Compartir Evidencia Fotográfica',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Muestra el estado físico real del libro acordado en la UDEC:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF00A884),
                    ),
                  ),
                  title: const Text('Tomar Foto con Cámara'),
                  subtitle: const Text(
                    'Captura instantánea del libro o portada',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturarYEnviarFoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  title: const Text('Elegir de la Galería'),
                  subtitle: const Text(
                    'Seleccionar foto guardada en tu dispositivo',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturarYEnviarFoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.menu_book_rounded, color: Colors.orange),
                  ),
                  title: const Text('Foto de Muestra Institucional'),
                  subtitle: const Text('Ejemplo de páginas interiores limpias'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _enviarFotoDirecta(
                      'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600',
                      'Te comparto la portada y estado del libro.',
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E5F5),
                    child: Icon(Icons.link_rounded, color: Colors.purple),
                  ),
                  title: const Text('Ingresar Enlace URL de Imagen'),
                  subtitle: const Text('Pega una URL HTTPS directa'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUrlInputDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _enviarFotoDirecta(String url, String descripcion) async {
    setState(() => _isSending = true);

    final success = await context.read<ChatProvider>().enviarMensaje(
      conversacionId: widget.conversacion.id,
      contenido: descripcion,
      tipo: 'IMAGE',
      fotoUrl: url,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _scrollToBottom();
      }
    }
  }

  void _showUrlInputDialog() {
    final urlCtrl = TextEditingController();
    final captionCtrl = TextEditingController(
      text: 'Fotografía compartida del libro',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Imagen por URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL de la imagen (HTTPS)',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje descriptivo',
                prefixIcon: Icon(Icons.comment_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _enviarFotoDirecta(
                  urlCtrl.text.trim(),
                  captionCtrl.text.trim(),
                );
              }
            },
            child: const Text('Enviar Foto'),
          ),
        ],
      ),
    );
  }

  /// Visor a pantalla completa con soporte de Zoom (InteractiveViewer) y animación Hero
  void _openPhotoViewer({
    String? imageUrl,
    Uint8List? memoryBytes,
    required String heroTag,
    required String caption,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo oscuro translúcido
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(color: Colors.black.withOpacity(0.94)),
              ),
              // Imagen interactiva con zoom táctil y desplazamiento (Pan & Zoom)
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Hero(
                    tag: heroTag,
                    child: memoryBytes != null
                        ? Image.memory(memoryBytes, fit: BoxFit.contain)
                        : AppNetworkImage(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            errorWidget: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white70,
                              size: 64,
                            ),
                          ),
                  ),
                ),
              ),
              // Barra superior con botón de cerrar
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              // Pie de foto descriptivo si existe
              if (caption.isNotEmpty)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final chatProvider = context.watch<ChatProvider>();
    final mensajes = chatProvider.getMensajes(widget.conversacion.id);

    final totalCount = mensajes.length + _pendingImages.length;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // Fondo WhatsApp cálido
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.accentGold.withOpacity(0.2),
              backgroundImage: widget.conversacion.otroUsuarioAvatarUrl != null
                  ? appImageProvider(widget.conversacion.otroUsuarioAvatarUrl!)
                  : null,
              child: widget.conversacion.otroUsuarioAvatarUrl == null
                  ? Text(
                      widget.conversacion.otroUsuarioNombre.isNotEmpty
                          ? widget.conversacion.otroUsuarioNombre[0]
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversacion.otroUsuarioNombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.conversacion.otroUsuarioSede != null
                        ? 'UDEC • Sede ${widget.conversacion.otroUsuarioSede}'
                        : 'Compañero UDEC',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Detalles del Libro',
            onPressed: () => _showBookSummaryDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Fijo del Libro en Negociación
          _buildBookTopBanner(),

          // Flujo de Mensajes (incluyendo optimistas con barra de subida)
          Expanded(
            child: totalCount == 0
                ? _buildEmptyChatState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: totalCount,
                    itemBuilder: (context, index) {
                      if (index < mensajes.length) {
                        final msg = mensajes[index];
                        final esMio = msg.esMio(myId);
                        return _buildMessageBubble(msg, esMio);
                      } else {
                        // Renderizar mensajes pendientes en estado "Subiendo..."
                        final pendingIndex = index - mensajes.length;
                        final pendingMsg = _pendingImages[pendingIndex];
                        return _buildPendingBubble(pendingMsg);
                      }
                    },
                  ),
          ),

          // Barra Inferior de Entrada (WhatsApp-Style con Cámara y Clip)
          ChatInputBar(
            isUploading: _isSending,
            onSendText: _enviarTexto,
            onCameraTap: () => _capturarYEnviarFoto(ImageSource.camera),
            onGalleryTap: _showMediaPickerSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildBookTopBanner() {
    final conv = widget.conversacion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: conv.publicacionPortadaUrl != null
                ? AppNetworkImage(
                    url: conv.publicacionPortadaUrl,
                    width: 38,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 38,
                      height: 48,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.book,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Container(
                    width: 38,
                    height: 48,
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.book,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.publicacionTitulo ?? 'Consulta de Libro',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        conv.publicacionModalidad ?? 'DISPONIBLE',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (conv.publicacionPrecio != null &&
                        conv.publicacionPrecio! > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        NumberFormat.currency(
                          locale: 'es_CO',
                          symbol: '\$',
                          decimalDigits: 0,
                        ).format(conv.publicacionPrecio),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.badgeVenta,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _showBookSummaryDialog,
            child: const Text('Ver Libro', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.primary,
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text(
              'Conversación Segura UDEC',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Coordina la entrega de "${widget.conversacion.publicacionTitulo}" dentro de los campus universitarios.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¡Toma una foto con la cámara o comparte imágenes del libro!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Burbuja de mensaje estándar (Texto o Imagen remota)
  Widget _buildMessageBubble(MensajeModel msg, bool esMio) {
    final hora = DateFormat('hh:mm a').format(msg.createdAt);
    final heroTag = 'msg_hero_${msg.id}';

    final bubble = Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: esMio ? const Color(0xFFE7FFDB) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: esMio
                  ? const Radius.circular(12)
                  : const Radius.circular(2),
              bottomRight: esMio
                  ? const Radius.circular(2)
                  : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Si es foto remota, renderizar tarjeta con soporte de zoom
              if (msg.esImagen && msg.fotoUrl != null) ...[
                GestureDetector(
                  onTap: () => _openPhotoViewer(
                    imageUrl: msg.fotoUrl,
                    heroTag: heroTag,
                    caption: msg.contenido,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Hero(
                          tag: heroTag,
                          child: AppNetworkImage(
                            url: msg.fotoUrl,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              height: 140,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Texto del mensaje o pie de foto
              if (msg.contenido.isNotEmpty)
                Text(
                  msg.contenido,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),

              const SizedBox(height: 2),

              // Hora y Doble Check
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    hora,
                    style: TextStyle(
                      fontSize: 10,
                      color: esMio ? Colors.black54 : AppColors.textMuted,
                    ),
                  ),
                  if (esMio) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.leido ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: msg.leido
                          ? const Color(0xFF34B7F1)
                          : Colors.black45,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!esMio) return bubble;
    return GestureDetector(
      onLongPress: () => _confirmDeleteMessage(msg),
      child: bubble,
    );
  }

  Future<void> _confirmDeleteMessage(MensajeModel msg) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Quieres eliminar este mensaje enviado por ti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final deleted = await context.read<ChatProvider>().eliminarMensaje(
      conversacionId: widget.conversacion.id,
      mensajeId: msg.id,
    );
    if (!deleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ChatProvider>().errorMessage ??
                'No se pudo eliminar el mensaje',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Burbuja optimista con indicador de subida en tiempo real ("Subiendo...")
  Widget _buildPendingBubble(PendingChatImage pending) {
    final hora = DateFormat('hh:mm a').format(pending.createdAt);
    final heroTag = 'pending_hero_${pending.id}';

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE7FFDB),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen local con overlay de carga
              GestureDetector(
                onTap: () => _openPhotoViewer(
                  memoryBytes: pending.bytes,
                  heroTag: heroTag,
                  caption: pending.caption,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: Image.memory(
                          pending.bytes,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (pending.isUploading)
                        Container(
                          width: double.infinity,
                          height: 180,
                          color: Colors.black45,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Subiendo a la nube...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (pending.error != null)
                        Container(
                          width: double.infinity,
                          height: 180,
                          color: Colors.red.withOpacity(0.6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Error en subida',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (pending.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  pending.caption,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],

              const SizedBox(height: 2),

              // Indicador de estado de subida (reloj o spinner)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    hora,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  if (pending.isUploading)
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.black45,
                    )
                  else if (pending.error != null)
                    const Icon(Icons.error_rounded, size: 14, color: Colors.red)
                  else
                    const Icon(
                      Icons.done_rounded,
                      size: 15,
                      color: Colors.black45,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookSummaryDialog() {
    final conv = widget.conversacion;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.menu_book_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Libro en Negociación', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conv.publicacionPortadaUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    url: conv.publicacionPortadaUrl,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              conv.publicacionTitulo ?? 'Publicación',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Modalidad: ${conv.publicacionModalidad ?? "No especificada"}',
            ),
            if (conv.publicacionPrecio != null && conv.publicacionPrecio! > 0)
              Text(
                'Precio: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(conv.publicacionPrecio)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.badgeVenta,
                ),
              ),
            const SizedBox(height: 8),
            Text('Interlocutor: ${conv.otroUsuarioNombre}'),
            if (conv.otroUsuarioEmail != null)
              Text(
                'Email: ${conv.otroUsuarioEmail}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

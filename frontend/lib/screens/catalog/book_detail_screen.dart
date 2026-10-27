import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/institutional_model.dart';
import '../../models/publication_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trade_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/catalog_provider.dart';
import '../chat/chat_detail_screen.dart';
import '../../widgets/app_network_image.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  PublicacionModel? _book;
  bool _isLoading = true;
  String? _error;
  int _selectedPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBookDetail();
  }

  Future<void> _loadBookDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('publicaciones')
          .doc(widget.bookId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        setState(() {
          _book = PublicacionModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Publicación no encontrada';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _iniciarChatConVendedor() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null ||
        auth.currentUser!.isSuspended ||
        !auth.currentUser!.isActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta ha sido suspendida por un administrador'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final book = _book;
    if (book == null || book.usuario == null) return;

    final chatProvider = context.read<ChatProvider>();
    final conv = await chatProvider.iniciarOObtenerConversacion(
      destinatarioId: book.usuario!.id,
      publicacionId: book.id,
    );

    if (mounted && conv != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatDetailScreen(conversacion: conv)),
      );
    }
  }

  Future<void> _showTradeProposalDialog() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null ||
        auth.currentUser!.isSuspended ||
        !auth.currentUser!.isActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta ha sido suspendida por un administrador'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final messageController = TextEditingController();
    final uid = auth.currentUser!.firebaseUid.isNotEmpty
        ? auth.currentUser!.firebaseUid
        : auth.currentUser!.id;
    final availableBooks = <Map<String, dynamic>>[];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('publicaciones')
          .where('usuario_id', isEqualTo: uid)
          .get();
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (doc.id != widget.bookId && data['estado'] == 'DISPONIBLE') {
          data['id'] = doc.id;
          availableBooks.add(data);
        }
      }
    } catch (_) {
      // The proposal may omit an offered book if the catalogue cannot be loaded.
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? offeredBookId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Proponer Intercambio de Libro'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Libro de interés: ${_book?.titulo}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: offeredBookId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Libro que ofreces (opcional)',
                  ),
                  items: availableBooks.map((book) {
                    return DropdownMenuItem<String>(
                      value: book['id'] as String,
                      child: Text(book['titulo']?.toString() ?? 'Libro'),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setDialogState(() => offeredBookId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el libro que ofreces o tu propuesta...',
                    labelText: 'Mensaje de propuesta institucional',
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
                onPressed: () async {
                  final msg = messageController.text.trim();
                  if (msg.isEmpty) return;
                  Navigator.pop(ctx);

                  final success = await context
                      .read<TradeProvider>()
                      .proposeTrade(
                        publicacionSolicitadaId: widget.bookId,
                        mensaje: msg,
                        publicacionOfrecidaId: offeredBookId,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '¡Propuesta de trueque enviada exitosamente!'
                              : 'Error al enviar propuesta',
                        ),
                        backgroundColor: success
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    );
                  }
                },
                child: const Text('Enviar Propuesta'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReservationDialog() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null ||
        auth.currentUser!.isSuspended ||
        !auth.currentUser!.isActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta ha sido suspendida por un administrador'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_book == null) return;

    List<PuntoEncuentroModel> puntos = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('puntos_encuentro')
          .where('sede_id', isEqualTo: _book!.sedeId)
          .get();

      if (snap.docs.isNotEmpty) {
        puntos = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return PuntoEncuentroModel.fromJson(data);
        }).toList();
      }
    } catch (_) {}

    // Puntos seguros por defecto si aún no han sido sembrados en Firestore
    if (puntos.isEmpty) {
      puntos = [
        PuntoEncuentroModel(
          id: '44444444-4444-4444-4444-444444444401',
          sedeId: _book!.sedeId,
          nombre: 'Biblioteca Central - Entrada Principal (Punto Seguro)',
          descripcion: 'Zona iluminada con recepción y seguridad institucional permanente.',
        ),
        PuntoEncuentroModel(
          id: '44444444-4444-4444-4444-444444444402',
          sedeId: _book!.sedeId,
          nombre: 'Plazoleta de los Fundadores (Punto Seguro)',
          descripcion: 'Espacio abierto central de alto tráfico y visibilidad estudiantil.',
        ),
      ];
    }

    String selectedPuntoId = puntos.first.id;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Solicitar adquisición'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona el lugar vigilado. El dueño aprobará la solicitud antes de activar el PIN:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPuntoId,
                isExpanded: true,
                items: puntos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.nombre,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedPuntoId = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Punto de encuentro seguro',
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
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final success = await context
                      .read<TradeProvider>()
                      .requestAcquisition(
                        publicacionId: widget.bookId,
                        puntoEncuentroId: selectedPuntoId,
                        fechaEncuentro: DateTime.now().add(
                          const Duration(days: 2),
                        ),
                        monto: _book!.precio,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Solicitud enviada. El dueño debe aprobarla antes de generar el PIN.'
                              : 'No fue posible enviar la solicitud.',
                        ),
                        backgroundColor: success
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    );
                    if (success) _loadBookDetail();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              child: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBookByAdmin(PublicacionModel book) async {
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Eliminar Libro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas eliminar permanentemente este libro de la plataforma?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Título: "${book.titulo}"\nAutor: ${book.autor}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta acción no se puede deshacer y cancelará las solicitudes o entregas pendientes asociadas.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar definitivamente',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final catalogProvider = context.read<CatalogProvider>();
      final success = await catalogProvider.deletePublication(book.id);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Libro eliminado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar el libro'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Libro')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Libro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'No se pudo cargar la publicación'),
              ElevatedButton(
                onPressed: _loadBookDetail,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final book = _book!;
    final isMyBook = currentUser?.id == book.usuarioId;

    return Scaffold(
      appBar: AppBar(
        title: Text(book.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (currentUser?.isAdmin == true && book.estado.toUpperCase().trim() == 'DISPONIBLE')
            IconButton(
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Eliminar libro (Admin)',
              onPressed: () => _confirmDeleteBookByAdmin(book),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galería / Imagen de Portada con Selector de Miniaturas
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppNetworkImage(
                  url:
                      book.fotos.isNotEmpty &&
                          _selectedPhotoIndex < book.fotos.length
                      ? book.fotos[_selectedPhotoIndex].fotoUrl
                      : book.portadaUrl,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: 280,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            if (book.fotos.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: book.fotos.length,
                  itemBuilder: (ctx, i) {
                    final isSel = i == _selectedPhotoIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPhotoIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AppNetworkImage(
                            url: book.fotos[i].fotoUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Título, Autor y Precio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.titulo,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Por ${book.autor}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (book.esVenta && book.precio > 0)
                  Text(
                    currencyFormatter.format(book.precio),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Badges informativos
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailBadge(
                  icon: Icons.bookmark_border_rounded,
                  label: book.modalidad.replaceAll('_', ' '),
                  color: AppColors.primary,
                ),
                _DetailBadge(
                  icon: Icons.thumb_up_alt_outlined,
                  label: book.condicionLibro.replaceAll('_', ' '),
                  color: Colors.teal,
                ),
                _DetailBadge(
                  icon: Icons.location_on_outlined,
                  label: book.sede?.nombre ?? 'Sede UDEC',
                  color: AppColors.textSecondary,
                ),
                if (book.semestreSugerido != null)
                  _DetailBadge(
                    icon: Icons.school_outlined,
                    label: 'Semestre ${book.semestreSugerido}',
                    color: AppColors.accentGold,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Descripción
            const Text(
              'Descripción del libro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              book.descripcion,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),

            if (book.interesIntercambio != null &&
                book.interesIntercambio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.badgeTrueque.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.badgeTrueque.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.badgeTrueque,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Interés de Trueque del Compañero:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.badgeTrueque,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(book.interesIntercambio!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tarjeta del Vendedor / Compañero UDEC
            if (book.usuario != null) ...[
              const Text(
                'Publicado por',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          book.usuario!.nombreCompleto.isNotEmpty
                              ? book.usuario!.nombreCompleto[0]
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.usuario!.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              book.usuario!.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  book.usuario!.totalCalificaciones == 0
                                      ? 'Sin calificaciones'
                                      : '${book.usuario!.reputacionPromedio.toStringAsFixed(1)} ★ (${book.usuario!.totalCalificaciones} calificaciones)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Botones de Acción
            if (!isMyBook && book.estado == 'DISPONIBLE') ...[
              // Botón Principal de Chat estilo WhatsApp
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text(
                    'Contactar por Chat (WhatsApp UDEC)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _iniciarChatConVendedor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (book.esTrueque)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Proponer Trueque'),
                        onPressed: _showTradeProposalDialog,
                      ),
                    ),
                  if (book.esTrueque && (book.esVenta || book.esDonacion))
                    const SizedBox(width: 12),
                  if (book.esVenta || book.esDonacion)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.handshake_rounded),
                        label: Text(
                          book.esDonacion
                              ? 'Solicitar Donación'
                              : 'Adquirir libro',
                        ),
                        onPressed: _showReservationDialog,
                      ),
                    ),
                ],
              ),
            ] else if (isMyBook) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Esta es tu propia publicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Este libro actualmente se encuentra: ${book.estado}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
            ],
            if (currentUser?.isAdmin == true) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.red,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Moderación de Administrador',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (book.estado.toUpperCase().trim() == 'DISPONIBLE') ...[
                      const Text(
                        'Como Administrador institucional, tienes permisos para dar de baja y eliminar permanentemente cualquier libro de la plataforma.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text('Eliminar libro de la plataforma'),
                        onPressed: () => _confirmDeleteBookByAdmin(book),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este libro ya fue completado (donado, vendido o intercambiado). Está protegido como parte del historial institucional y no puede ser eliminado.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

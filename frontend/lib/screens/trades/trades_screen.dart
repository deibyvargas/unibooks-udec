import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/trade_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/trade_provider.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TradeProvider>().loadTradesAndTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showConfirmDeliveryDialog(TransaccionModel tx) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Entrega en Campus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Punto Seguro: ${tx.puntoEncuentro?.nombre ?? "Campus UDEC"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pide al solicitante que te dicte el PIN de 4 dígitos que tiene asignado para validar la entrega física:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
              decoration: const InputDecoration(
                labelText: 'Ingresa el PIN de 4 dígitos',
                hintText: '••••',
                counterText: '',
                prefixIcon: Icon(Icons.lock_outline),
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
              final pin = pinController.text.trim();
              if (pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, ingresa el código PIN de 4 dígitos.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);

              final success = await context
                  .read<TradeProvider>()
                  .confirmDelivery(tx.id, pin);
              if (mounted) {
                final errorMsg =
                    context.read<TradeProvider>().errorMessage ??
                    'PIN incorrecto, verifica con el solicitante';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '¡Entrega confirmada con éxito! Transacción completada y libro retirado del catálogo.'
                          : errorMsg,
                    ),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                );
                if (success) {
                  _showRatingDialog(tx);
                }
              }
            },
            child: const Text('Confirmar Entrega'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(TransaccionModel tx) {
    int rating = 0;
    int punctuality = 5;
    int bookFidelity = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.star_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Calificar Intercambio', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evalúa la experiencia de entrega para "${tx.publicacion?.titulo ?? "Libro"}":',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Puntuación General:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Puntualidad en el Punto Seguro:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Slider(
                  value: punctuality.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$punctuality / 5',
                  activeColor: AppColors.primary,
                  onChanged: (val) =>
                      setDialogState(() => punctuality = val.round()),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fidelidad del Estado del Libro:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Slider(
                  value: bookFidelity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$bookFidelity / 5',
                  activeColor: AppColors.primary,
                  onChanged: (val) =>
                      setDialogState(() => bookFidelity = val.round()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comentario sobre el compañero...',
                    hintText:
                        'Excelente puntualidad y libro en estado impecable.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (rating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Selecciona una puntuación de 1 a 5 estrellas.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<TradeProvider>().skipRating(
                  tx.id,
                );
                if (mounted && !ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esta entrega ya fue evaluada u omitida.'),
                    ),
                  );
                }
              },
              child: const Text('Omitir'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await context.read<TradeProvider>().rateTransaction(
                  transactionId: tx.id,
                  puntuacion: rating,
                  comentario: commentCtrl.text.trim(),
                  puntualidad: punctuality,
                  estadoLibroFiel: bookFidelity,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? '¡Calificación enviada! La reputación del compañero se ha actualizado.'
                            : 'No fue posible registrar la calificación.',
                      ),
                      backgroundColor: ok
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  );
                }
              },
              child: const Text('Enviar Calificación'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tradeProvider = context.watch<TradeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulo de Intercambio y Entregas'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Recibidas', icon: Icon(Icons.inbox_rounded, size: 20)),
            Tab(text: 'Enviadas', icon: Icon(Icons.outbox_rounded, size: 20)),
            Tab(
              text: 'Entregas Campus',
              icon: Icon(Icons.meeting_room_rounded, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Pestaña de Recibidas
          RefreshIndicator(
            onRefresh: () => tradeProvider.loadTradesAndTransactions(),
            child: tradeProvider.recibidas.isEmpty
                ? const _EmptyState(
                    icon: Icons.inbox_outlined,
                    message: 'No tienes propuestas de trueque recibidas en este momento.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tradeProvider.recibidas.length,
                    itemBuilder: (context, index) {
                      final trade = tradeProvider.recibidas[index];
                      return _TradeCard(
                        trade: trade,
                        isReceived: true,
                        onAccept: () =>
                            tradeProvider.respondTrade(trade.id, true),
                        onReject: () => tradeProvider.respondTrade(
                          trade.id,
                          false,
                          motivo: 'No disponible por el momento',
                        ),
                      );
                    },
                  ),
          ),

          // 2. Pestaña de Enviadas
          RefreshIndicator(
            onRefresh: () => tradeProvider.loadTradesAndTransactions(),
            child: tradeProvider.enviadas.isEmpty
                ? const _EmptyState(
                    icon: Icons.outbox_outlined,
                    message: 'No has enviado propuestas de trueque todavía.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tradeProvider.enviadas.length,
                    itemBuilder: (context, index) {
                      final trade = tradeProvider.enviadas[index];
                      return _TradeCard(trade: trade, isReceived: false);
                    },
                  ),
          ),

          // 3. Pestaña de Entregas y Reservas Activas en el Campus
          RefreshIndicator(
            onRefresh: () => tradeProvider.loadTradesAndTransactions(),
            child: tradeProvider.transacciones.isEmpty
                ? const _EmptyState(
                    icon: Icons.handshake_outlined,
                    message: 'No tienes transacciones activas o pendientes de encuentro.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tradeProvider.transacciones.length,
                    itemBuilder: (context, index) {
                      final tx = tradeProvider.transacciones[index];
                      return _TransactionCard(
                        tx: tx,
                        onConfirmDelivery: () => _showConfirmDeliveryDialog(tx),
                        onRate: () => _showRatingDialog(tx),
                        onRespondAcquisition: (accept) =>
                            tradeProvider.respondAcquisition(tx.id, accept),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  final SolicitudIntercambioModel trade;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _TradeCard({
    required this.trade,
    required this.isReceived,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.orange;
    if (trade.esAceptada) statusColor = AppColors.success;
    if (trade.esRechazada) statusColor = AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isReceived
                        ? 'Propuesta de: ${trade.usuarioSolicitante?.nombreCompleto ?? "Compañero UDEC"}'
                        : 'Publicado por: ${trade.publicacionSolicitada?.usuario?.nombreCompleto ?? "Compañero UDEC"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    trade.estado,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final participant = isReceived
                    ? trade.usuarioSolicitante
                    : trade.publicacionSolicitada?.usuario;
                final ratingText =
                    participant == null || participant.totalCalificaciones == 0
                    ? 'Sin calificaciones'
                    : '${participant.reputacionPromedio.toStringAsFixed(1)} ★ (${participant.totalCalificaciones})';
                return Text(
                  'Satisfacción del usuario: $ratingText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Libro solicitado: ${trade.publicacionSolicitada?.titulo ?? "Libro"}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.swap_horiz,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Libro ofrecido: ${trade.publicacionOfrecida?.titulo ?? "No se registró un libro ofrecido"}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${trade.mensajePropuesta}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
            if (isReceived && trade.esPendiente) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransaccionModel tx;
  final VoidCallback onConfirmDelivery;
  final VoidCallback? onRate;
  final Future<bool> Function(bool accept)? onRespondAcquisition;

  const _TransactionCard({
    required this.tx,
    required this.onConfirmDelivery,
    this.onRate,
    this.onRespondAcquisition,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = tx.estado == 'PENDIENTE_ENCUENTRO';
    final isApprovalPending = tx.estado == 'SOLICITUD_PENDIENTE';
    final isCompleted = tx.estado == 'COMPLETADA';
    final isCancelled = tx.estado == 'CANCELADA';
    final currentUserId = context.watch<TradeProvider>().currentUserId;
    final isSolicitante = currentUserId == tx.compradorId;
    final isEntregador = currentUserId == tx.vendedorId;
    final evaluation = currentUserId == null
        ? null
        : tx.evaluaciones[currentUserId];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx.publicacion?.titulo ?? 'Transacción de Libro',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isPending || isApprovalPending)
                        ? Colors.blue.withOpacity(0.12)
                        : isCancelled
                        ? AppColors.danger.withOpacity(0.12)
                        : AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx.estado.replaceAll('_', ' '),
                    style: TextStyle(
                      color: (isPending || isApprovalPending)
                          ? Colors.blue
                          : isCancelled
                          ? AppColors.danger
                          : AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (tx.publicacionOfrecida != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Intercambio por: ${tx.publicacionOfrecida!.titulo}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Punto Seguro: ${tx.puntoEncuentro?.nombre ?? "Campus UDEC"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Fecha programada: ${tx.fechaHoraEncuentro.day}/${tx.fechaHoraEncuentro.month}/${tx.fechaHoraEncuentro.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isApprovalPending && isEntregador) ...[
              const Text(
                'Solicitud pendiente de aprobación. El libro seguirá disponible hasta completar la entrega.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => onRespondAcquisition?.call(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => onRespondAcquisition?.call(true),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
            if (isPending && isSolicitante) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key, color: Colors.brown, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tu PIN de entrega: ${tx.codigoVerificacionEntrega}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.brown,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Proporciona este PIN de 4 dígitos verbalmente al entregador al momento de recibir el libro.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending && isEntregador)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pide el PIN al solicitante al entregar el libro',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Confirmar Entrega'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onConfirmDelivery,
                  ),
                ],
              ),
            if (isCompleted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '✓ Entrega completada',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (evaluation == null && onRate != null)
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      label: const Text('Calificar Compañero'),
                      onPressed: onRate,
                    ),
                  if (evaluation != null)
                    Text(
                      evaluation['estado'] == 'OMITIDA'
                          ? 'Calificación omitida'
                          : 'Tu puntaje: ${evaluation['puntuacion'] ?? '-'} / 5',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

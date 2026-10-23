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

class _TradesScreenState extends State<TradesScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Validación de Entrega en Campus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Punto Seguro: ${tx.puntoEncuentro?.nombre ?? "Campus UDEC"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tu PIN de seguridad asignado es: ${tx.codigoVerificacionEntrega}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Ingresa el código PIN recibido',
                hintText: '6 dígitos',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 6) return;
              Navigator.pop(ctx);

              final success = await context.read<TradeProvider>().confirmDelivery(tx.id, pin);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '¡Entrega confirmada con éxito! Transacción completada.'
                          : 'PIN incorrecto o error al confirmar entrega.',
                    ),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
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
    int rating = 5;
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
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text('Puntuación General:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Puntualidad en el Punto Seguro:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Slider(
                  value: punctuality.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$punctuality / 5',
                  activeColor: AppColors.primary,
                  onChanged: (val) => setDialogState(() => punctuality = val.round()),
                ),
                const SizedBox(height: 8),
                const Text('Fidelidad del Estado del Libro:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Slider(
                  value: bookFidelity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$bookFidelity / 5',
                  activeColor: AppColors.primary,
                  onChanged: (val) => setDialogState(() => bookFidelity = val.round()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comentario sobre el compañero...',
                    hintText: 'Excelente puntualidad y libro en estado impecable.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Omitir')),
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
                      content: Text(ok ? '¡Calificación enviada! La reputación del compañero se ha actualizado.' : 'No fue posible registrar la calificación.'),
                      backgroundColor: ok ? AppColors.success : AppColors.danger,
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
            Tab(text: 'Entregas Campus', icon: Icon(Icons.meeting_room_rounded, size: 20)),
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
                        onAccept: () => tradeProvider.respondTrade(trade.id, true),
                        onReject: () => tradeProvider.respondTrade(trade.id, false, motivo: 'No disponible por el momento'),
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
                      return _TradeCard(
                        trade: trade,
                        isReceived: false,
                      );
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
                        : 'Propuesta enviada',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    trade.estado,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Libro solicitado: ${trade.publicacionSolicitada?.titulo ?? "Libro"}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
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
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ),
            if (isReceived && trade.esPendiente) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Aceptar Trueque'),
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

  const _TransactionCard({
    required this.tx,
    required this.onConfirmDelivery,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = tx.estado == 'PENDIENTE_ENCUENTRO';
    final isCompleted = tx.estado == 'COMPLETADA';

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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.blue.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx.estado.replaceAll('_', ' '),
                    style: TextStyle(
                      color: isPending ? Colors.blue : AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Punto Seguro: ${tx.puntoEncuentro?.nombre ?? "Campus UDEC"}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Fecha programada: ${tx.fechaHoraEncuentro.day}/${tx.fechaHoraEncuentro.month}/${tx.fechaHoraEncuentro.year}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PIN: ${tx.codigoVerificacionEntrega}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                  ),
                ),
                if (isPending)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Validar PIN'),
                    onPressed: onConfirmDelivery,
                  ),
                if (isCompleted && onRate != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    label: const Text('Calificar Compañero'),
                    onPressed: onRate,
                  ),
              ],
            ),
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

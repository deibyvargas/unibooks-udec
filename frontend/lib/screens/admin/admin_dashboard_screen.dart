import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/app_network_image.dart';

/// Dashboard Integral de Unibooks: Analítica, Métricas de Impacto y Panel de Control RBAC
/// Optimizado tanto para Flutter Web (pantallas amplias) como para Android APK (móvil).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _booksSub;
  StreamSubscription<QuerySnapshot>? _txSub;
  StreamSubscription<QuerySnapshot>? _ratingsSub;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _usersList = [];
  List<Map<String, dynamic>> _booksList = [];
  List<Map<String, dynamic>> _transactionsList = [];
  double _globalRatingAverage = 0;
  int _globalRatingCount = 0;

  String _userSearchQuery = '';
  String _bookSearchQuery = '';
  String _selectedSedeFilter = 'Todas las Sedes';

  final currencyFormatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // Lista oficial de Sedes de la Universidad de Cundinamarca
  static const List<String> sedesUdec = [
    'Todas las Sedes',
    'Fusagasugá',
    'Girardot',
    'Facatativá',
    'Ubaté',
    'Chía',
    'Soacha',
    'Zipaquirá',
    'Chocontá',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initLiveSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usersSub?.cancel();
    _booksSub?.cancel();
    _txSub?.cancel();
    _ratingsSub?.cancel();
    super.dispose();
  }

  void _initLiveSubscriptions() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Suscripción en tiempo real a Usuarios
    _usersSub = _firestore
        .collection('usuarios')
        .snapshots()
        .listen(
          (snap) {
            final users = snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList();

            if (mounted) {
              setState(() {
                _usersList = users;
                _isLoading = false;
              });
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Error al sincronizar usuarios: $err';
                _isLoading = false;
              });
            }
          },
        );

    // 2. Suscripción en tiempo real a Publicaciones (Libros)
    _booksSub = _firestore
        .collection('publicaciones')
        .snapshots()
        .listen(
          (snap) {
            final books = snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList();

            if (mounted) {
              setState(() {
                _booksList = books;
              });
            }
          },
          onError: (err) {
            debugPrint('[AdminDashboard] Error en libros: $err');
          },
        );

    // 3. Suscripción en tiempo real a Transacciones y Trueques en Campus
    _txSub = _firestore
        .collection('transacciones')
        .snapshots()
        .listen(
          (snap) {
            final txs = snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList();

            if (mounted) {
              setState(() {
                _transactionsList = txs;
              });
            }
          },
          onError: (err) {
            debugPrint('[AdminDashboard] Nota en transacciones: $err');
          },
        );

    _ratingsSub = _firestore.collection('calificaciones').snapshots().listen((
      snap,
    ) {
      var total = 0.0;
      for (final doc in snap.docs) {
        total +=
            double.tryParse(doc.data()['puntuacion']?.toString() ?? '0') ?? 0;
      }
      if (mounted) {
        setState(() {
          _globalRatingCount = snap.docs.length;
          _globalRatingAverage = snap.docs.isEmpty
              ? 0
              : double.parse((total / snap.docs.length).toStringAsFixed(1));
        });
      }
    });
  }

  /// Muestra modal de confirmación antes de suspender o reactivar una cuenta
  Future<void> _confirmToggleUserStatus(Map<String, dynamic> user) async {
    // AuthProvider watches usuarios/{firebase_uid}; use that same document
    // instead of the SQL UUID stored in the profile payload.
    final String docId =
        (user['firebase_uid'] != null &&
            user['firebase_uid'].toString().isNotEmpty)
        ? user['firebase_uid'].toString()
        : (user['id']?.toString() ?? '');

    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Identificador de usuario no válido'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bool estaActivo =
        (user['activo'] != false &&
        user['estado'] != 'SUSPENDIDO' &&
        user['status'] != 'suspended' &&
        user['is_suspended'] != true);
    final String accion = estaActivo ? 'Suspender' : 'Reactivar';
    final String nuevoEstado = estaActivo ? 'SUSPENDIDO' : 'ACTIVO';
    final String nombreUsuario =
        user['nombre_completo'] ?? user['email'] ?? 'Usuario';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              estaActivo ? Icons.block_rounded : Icons.check_circle_outline,
              color: estaActivo ? AppColors.danger : AppColors.success,
            ),
            const SizedBox(width: 8),
            Text('$accion cuenta de usuario'),
          ],
        ),
        content: Text(
          estaActivo
              ? '¿Estás seguro de que deseas suspender la cuenta de $nombreUsuario?\n\n'
                    'El usuario no podrá iniciar sesión ni interactuar en la plataforma.'
              : '¿Deseas reactivar el acceso para $nombreUsuario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: estaActivo
                  ? AppColors.danger
                  : AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$accion Cuenta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bool suspendiendo = estaActivo;
      final updateData = {
        'estado': nuevoEstado,
        'status': suspendiendo ? 'suspended' : 'active',
        'is_suspended': suspendiendo,
        'activo': !suspendiendo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('usuarios').doc(docId).update(updateData);

      if (mounted) {
        setState(() {
          final idx = _usersList.indexWhere(
            (u) => u['id'] == docId || u['firebase_uid'] == docId,
          );
          if (idx != -1) {
            _usersList[idx]['estado'] = nuevoEstado;
            _usersList[idx]['status'] = suspendiendo ? 'suspended' : 'active';
            _usersList[idx]['is_suspended'] = suspendiendo;
            _usersList[idx]['activo'] = !suspendiendo;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              suspendiendo
                  ? 'Cuenta de $nombreUsuario suspendida correctamente.'
                  : 'Cuenta reactivada exitosamente.',
            ),
            backgroundColor: suspendiendo
                ? AppColors.danger
                : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al modificar estado: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Muestra modal de confirmación antes de eliminar un libro permanentemente
  Future<void> _confirmDeleteBook(Map<String, dynamic> book) async {
    final bookId = book['id'] ?? '';
    final titulo = book['titulo'] ?? 'este libro';
    final estado = (book['estado'] ?? 'DISPONIBLE')
        .toString()
        .toUpperCase()
        .trim();
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
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirmar eliminación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar permanentemente "$titulo"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta acción es irreversible: el libro será retirado del catálogo activo y se cancelarán '
              'automáticamente las solicitudes de trueque asociadas.',
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
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final success = await context.read<CatalogProvider>().deletePublication(
        bookId,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _booksList.removeWhere((b) => b['id'] == bookId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Libro eliminado correctamente del ecosistema'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<CatalogProvider>().errorMessage ??
                    'Error al eliminar el libro.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar libro: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        toolbarHeight: MediaQuery.sizeOf(context).width < 420
            ? 78
            : kToolbarHeight,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panel de Control Administrativo',
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 420
                          ? 13
                          : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Universidad de Cundinamarca • RBAC Admin',
                    maxLines: 2,
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sincronizar métricas en tiempo real',
            onPressed: _initLiveSubscriptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(
              icon: Icon(Icons.insights_rounded),
              text: 'Analítica & Impacto',
            ),
            Tab(
              icon: const Icon(Icons.people_alt_rounded),
              text: 'Cuentas (${_usersList.length})',
            ),
            Tab(
              icon: const Icon(Icons.menu_book_rounded),
              text: 'Catálogo (${_booksList.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_person_rounded,
                      size: 54,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Error de Sincronización',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _initLiveSubscriptions,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar sincronización'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Analítica e Impacto del Campus (Streamlit-inspired)
                _buildAnalyticsTab(),

                // Tab 2: Moderación y Auditoría de Usuarios
                _buildUsersTab(),

                // Tab 3: Moderación y Eliminación de Libros
                _buildBooksTab(),
              ],
            ),
    );
  }

  // ===========================================================================
  // TAB 1: ANALÍTICA, KPIs E IMPACTO DEL CAMPUS
  // ===========================================================================
  Widget _buildAnalyticsTab() {
    // Filtrado de libros por Sede Universitaria seleccionada
    final filteredBooks = _selectedSedeFilter == 'Todas las Sedes'
        ? _booksList
        : _booksList.where((b) {
            final s = (b['sede_nombre'] ?? b['sede'] ?? '')
                .toString()
                .toLowerCase();
            return s.contains(_selectedSedeFilter.toLowerCase());
          }).toList();

    // Cálculos estadísticos
    final totalLibros = filteredBooks.length;
    final librosDisponibles = filteredBooks
        .where((b) => b['estado'] == 'DISPONIBLE' || b['estado'] == null)
        .length;
    final librosReservados = filteredBooks
        .where((b) => b['estado'] == 'RESERVADO')
        .length;

    // Modalidades
    final librosVenta = filteredBooks.where((b) {
      final m = (b['modalidad'] ?? '').toString().toUpperCase();
      return m == 'VENTA';
    }).length;
    final librosTrueque = filteredBooks.where((b) {
      final m = (b['modalidad'] ?? '').toString().toUpperCase();
      return m == 'INTERCAMBIO';
    }).length;
    final librosVentaOTrueque = filteredBooks.where((b) {
      final m = (b['modalidad'] ?? '').toString().toUpperCase();
      return m == 'VENTA_O_INTERCAMBIO';
    }).length;
    final librosDonacion = filteredBooks.where((b) {
      final m = (b['modalidad'] ?? '').toString().toUpperCase();
      return m == 'DONACION';
    }).length;

    final totalUsuarios = _usersList.length;
    final totalEstudiantes = _usersList
        .where((u) => u['rol'] == 'ESTUDIANTE')
        .length;
    final usuariosSuspendidos = _usersList
        .where(
          (u) =>
              u['activo'] == false ||
              u['estado'] == 'SUSPENDIDO' ||
              u['status'] == 'suspended',
        )
        .length;

    final int totalTransacciones = _transactionsList.length;
    final int entregasExitosas = _transactionsList
        .where(
          (t) =>
              t['estado'] == 'COMPLETADA' ||
              t['estado'] == 'COMPLETADO' ||
              t['estado'] == 'ENTREGADO',
        )
        .length;
    final double tasaExito = totalTransacciones > 0
        ? (entregasExitosas / totalTransacciones) * 100
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminBanner(),
              const SizedBox(height: 18),

              // Barra de Filtro de Sede Universitaria (Estilo Streamlit)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Filtrar Observatorio por Sede:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSedeFilter,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                              color: AppColors.primary,
                            ),
                            items: sedesUdec.map((sede) {
                              return DropdownMenuItem<String>(
                                value: sede,
                                child: Text(
                                  sede,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSedeFilter = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Encabezado de KPIs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Indicadores Clave de Desempeño (KPIs)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.bolt_rounded, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Sincronización en Vivo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rejilla de KPIs principales
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  return GridView.count(
                    crossAxisCount: isMobile ? 1 : 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isMobile ? 2.2 : 1.8,
                    children: [
                      _buildMetricCard(
                        title: 'Libros en Catálogo',
                        value: '$totalLibros',
                        deltaText: '$librosDisponibles disponibles',
                        deltaColor: AppColors.success,
                        icon: Icons.menu_book_rounded,
                        color: AppColors.primary,
                      ),
                      _buildMetricCard(
                        title: 'Tasa de Entrega Segura',
                        value: '${tasaExito.toStringAsFixed(1)}%',
                        deltaText: '✓ Con validación PIN',
                        deltaColor: Colors.blue,
                        icon: Icons.verified_user_rounded,
                        color: Colors.blue,
                      ),
                      _buildMetricCard(
                        title: 'Satisfacción Global',
                        value: _globalRatingCount == 0
                            ? 'Sin calificaciones'
                            : '${_globalRatingAverage.toStringAsFixed(1)} ★',
                        deltaText: '$_globalRatingCount evaluaciones reales',
                        deltaColor: Colors.amber.shade800,
                        icon: Icons.star_rounded,
                        color: Colors.amber.shade800,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Sección: Distribución Multisede UDEC y Dinámica de Modalidades
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;

                  final leftWidget = _buildMultisedeDistribution(totalLibros);
                  final rightWidget = _buildModalityDistribution(
                    totalLibros: totalLibros,
                    venta: librosVenta,
                    trueque: librosTrueque,
                    ventaOTrueque: librosVentaOTrueque,
                    donacion: librosDonacion,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leftWidget),
                        const SizedBox(width: 16),
                        Expanded(child: rightWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        leftWidget,
                        const SizedBox(height: 16),
                        rightWidget,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // Resumen de Seguridad y Moderación RBAC
              _buildSecuritySummary(
                totalUsuarios: totalUsuarios,
                estudiantes: totalEstudiantes,
                suspendidos: usuariosSuspendidos,
                reservados: librosReservados,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: DISTRIBUCIÓN MULTISEDE UDEC
  // ===========================================================================
  Widget _buildMultisedeDistribution(int totalLibros) {
    // Cálculo por sede
    final sedesConfig = [
      {
        'nombre': 'Fusagasugá (Principal)',
        'key': 'fusagasugá',
        'color': const Color(0xFF0F5132),
      },
      {
        'nombre': 'Girardot',
        'key': 'girardot',
        'color': const Color(0xFF198754),
      },
      {
        'nombre': 'Facatativá',
        'key': 'facatativá',
        'color': const Color(0xFF0D6EFD),
      },
      {'nombre': 'Ubaté', 'key': 'ubaté', 'color': const Color(0xFFD4AF37)},
      {'nombre': 'Chía', 'key': 'chía', 'color': const Color(0xFF6F42C1)},
      {'nombre': 'Soacha', 'key': 'soacha', 'color': const Color(0xFFE83E8C)},
      {
        'nombre': 'Zipaquirá',
        'key': 'zipaquirá',
        'color': const Color(0xFFFD7E14),
      },
      {
        'nombre': 'Chocontá',
        'key': 'chocontá',
        'color': const Color(0xFF20C997),
      },
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.location_city_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Presencia y Distribución por Sedes UDEC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Porcentaje de actividad y volumen bibliográfico en las sedes universitarias.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...sedesConfig.map((sede) {
              final nombre = sede['nombre'] as String;
              final key = sede['key'] as String;
              final color = sede['color'] as Color;

              final count = _booksList.where((b) {
                final s = (b['sede_nombre'] ?? b['sede'] ?? '')
                    .toString()
                    .toLowerCase();
                return s.contains(key);
              }).length;

              final double pct = totalLibros > 0
                  ? (count / totalLibros)
                  : (key == 'fusagasugá' ? 0.35 : 0.1);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$count libros (${(pct * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.02, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 7,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: DINÁMICA DE MODALIDADES DE TRASPASO
  // ===========================================================================
  Widget _buildModalityDistribution({
    required int totalLibros,
    required int venta,
    required int trueque,
    required int ventaOTrueque,
    required int donacion,
  }) {
    final modalities = [
      {
        'label': 'Intercambio / Trueque',
        'count': trueque,
        'color': AppColors.badgeTrueque,
        'icon': Icons.swap_horiz_rounded,
        'desc': 'Sin dinero involucrado, libro por libro',
      },
      {
        'label': 'Venta Accesible',
        'count': venta,
        'color': AppColors.badgeVenta,
        'icon': Icons.attach_money_rounded,
        'desc': 'Precios justos para universitarios',
      },
      {
        'label': 'Venta o Trueque',
        'count': ventaOTrueque,
        'color': Colors.amber.shade700,
        'icon': Icons.all_inclusive_rounded,
        'desc': 'Flexibilidad a elección del estudiante',
      },
      {
        'label': 'Donación Solidaria',
        'count': donacion,
        'color': AppColors.badgeDonacion,
        'icon': Icons.volunteer_activism_rounded,
        'desc': 'Aporte sin costo a la comunidad',
      },
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Dinámica de Economía Circular & Modalidades',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Distribución de publicaciones según el tipo de traspaso acordado.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...modalities.map((m) {
              final label = m['label'] as String;
              final count = m['count'] as int;
              final color = m['color'] as Color;
              final icon = m['icon'] as IconData;
              final desc = m['desc'] as String;

              final double pct = totalLibros > 0
                  ? (count / totalLibros) * 100
                  : 25.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count ejemplares',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: color,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: RESUMEN DE SEGURIDAD Y AUDITORÍA RBAC
  // ===========================================================================
  Widget _buildSecuritySummary({
    required int totalUsuarios,
    required int estudiantes,
    required int suspendidos,
    required int reservados,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final heading = Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Auditoría y Puntos Seguros del Campus',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
                final action = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                  label: const Text(
                    'Moderar Cuentas',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _tabController.animateTo(1),
                );

                return isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: 10),
                          Align(alignment: Alignment.centerLeft, child: action),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 12),
                          action,
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 600 ? 1 : 3;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 4.2 : 1.65,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSmallAuditBadge(
                      icon: Icons.people_rounded,
                      label: 'Estudiantes / Cuentas',
                      value: '$estudiantes activos',
                      color: AppColors.primary,
                    ),
                    _buildSmallAuditBadge(
                      icon: Icons.block_rounded,
                      label: 'Cuentas Suspendidas',
                      value: '$suspendidos bloqueados',
                      color: suspendidos > 0 ? AppColors.danger : Colors.grey,
                    ),
                    _buildSmallAuditBadge(
                      icon: Icons.pin_drop_rounded,
                      label: 'En proceso de entrega',
                      value: '$reservados en punto seguro',
                      color: Colors.blue,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAuditBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatusBadge(bool estaActivo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: estaActivo ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: estaActivo ? Colors.green.shade600 : Colors.red.shade600,
        ),
      ),
      child: Text(
        estaActivo ? 'ACTIVO' : 'SUSPENDIDO',
        softWrap: false,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: estaActivo ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: GESTIÓN Y MODERACIÓN DE USUARIOS
  // ===========================================================================
  Widget _buildUsersTab() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final filteredUsers = _usersList.where((u) {
      if (_userSearchQuery.isEmpty) return true;
      final q = _userSearchQuery.toLowerCase();
      final n = (u['nombre_completo'] ?? '').toString().toLowerCase();
      final e = (u['email'] ?? '').toString().toLowerCase();
      final r = (u['rol'] ?? '').toString().toLowerCase();
      final id = (u['id'] ?? u['firebase_uid'] ?? '').toString().toLowerCase();
      return n.contains(q) || e.contains(q) || id.contains(q) || r.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminBanner(),
              const SizedBox(height: 20),

              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Moderación de Cuentas Universitarias',
                    softWrap: true,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredUsers.length} de ${_usersList.length} usuarios',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Buscador de usuarios
              TextField(
                onChanged: (val) =>
                    setState(() => _userSearchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo, ID o rol...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _userSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () =>
                              setState(() => _userSearchQuery = ''),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: filteredUsers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No se encontraron usuarios coincidentes.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.cardBorder,
                        ),
                        itemBuilder: (context, index) {
                          final u = filteredUsers[index];
                          final bool esAdmin =
                              (u['rol'] == 'ADMINISTRADOR' ||
                              u['rol'] == 'ADMIN' ||
                              u['email'] == 'vargasdeiby54@gmail.com');
                          final bool estaActivo =
                              (u['activo'] != false &&
                              u['estado'] != 'SUSPENDIDO' &&
                              u['status'] != 'suspended' &&
                              u['is_suspended'] != true);

                          final roleChip = Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              (u['rol'] ?? 'ESTUDIANTE').toString(),
                              softWrap: false,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                          final ratingCount =
                              int.tryParse(
                                u['total_calificaciones']?.toString() ?? '0',
                              ) ??
                              0;
                          final rating = ratingCount == 0
                              ? 'Sin calificaciones'
                              : '${double.tryParse(u['reputacion_promedio']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0'} ★ ($ratingCount)';
                          final action = esAdmin
                              ? const Chip(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    'Protegido',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: estaActivo
                                        ? Colors.red.shade50
                                        : Colors.green.shade50,
                                    foregroundColor: estaActivo
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                    side: BorderSide(
                                      color: estaActivo
                                          ? Colors.red.shade400
                                          : Colors.green.shade600,
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: Icon(
                                    estaActivo
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline,
                                    size: 15,
                                  ),
                                  label: Text(
                                    estaActivo ? 'Suspender' : 'Reactivar',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () => _confirmToggleUserStatus(u),
                                );

                          return ListTile(
                            isThreeLine: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: esAdmin
                                  ? Colors.amber.withOpacity(0.2)
                                  : estaActivo
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.12),
                              child: Icon(
                                esAdmin
                                    ? Icons.shield_rounded
                                    : estaActivo
                                    ? Icons.person
                                    : Icons.block_rounded,
                                color: esAdmin
                                    ? Colors.amber.shade800
                                    : estaActivo
                                    ? AppColors.primary
                                    : Colors.red,
                              ),
                            ),
                            title: isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u['nombre_completo'] ?? 'Usuario UDEC',
                                        softWrap: true,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildUserStatusBadge(
                                          estaActivo,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          u['nombre_completo'] ??
                                              'Usuario UDEC',
                                          softWrap: true,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildUserStatusBadge(estaActivo),
                                    ],
                                  ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  u['email'] ?? 'Sin correo',
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      rating,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isMobile) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(child: roleChip),
                                      const Spacer(),
                                      Flexible(child: action),
                                    ],
                                  ),
                                ],
                                if (!estaActivo)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      '⚠ Acceso suspendido por Administración',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isMobile
                                ? null
                                : SizedBox(width: 130, child: action),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: GESTIÓN Y MODERACIÓN DE LIBROS
  // ===========================================================================
  Widget _buildBooksTab() {
    final filteredBooks = _booksList.where((b) {
      if (_bookSearchQuery.isEmpty) return true;
      final q = _bookSearchQuery.toLowerCase();
      final t = (b['titulo'] ?? '').toString().toLowerCase();
      final a = (b['autor'] ?? '').toString().toLowerCase();
      final m = (b['modalidad'] ?? '').toString().toLowerCase();
      return t.contains(q) || a.contains(q) || m.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Moderación y Eliminación de Publicaciones',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredBooks.length} de ${_booksList.length} libros',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Como Administrador, puedes eliminar cualquier publicación que incumpla los lineamientos '
                'institucionales. La eliminación retirará el libro de inmediato del catálogo.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // Buscador de libros
              TextField(
                onChanged: (val) =>
                    setState(() => _bookSearchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar libro por título, autor o modalidad...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _bookSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () =>
                              setState(() => _bookSearchQuery = ''),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: filteredBooks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No se encontraron libros que coincidan con la búsqueda.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredBooks.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.cardBorder,
                        ),
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          final fotos = book['fotos_urls'] as List?;
                          final portada = (fotos != null && fotos.isNotEmpty)
                              ? fotos.first.toString()
                              : '';
                          final precio =
                              double.tryParse(
                                book['precio']?.toString() ?? '0',
                              ) ??
                              0.0;
                          final estado = (book['estado'] ?? 'DISPONIBLE')
                              .toString()
                              .toUpperCase()
                              .trim();
                          final bool isDisponible = estado == 'DISPONIBLE';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 50,
                                height: 65,
                                child: portada.isNotEmpty
                                    ? AppNetworkImage(
                                        url: portada,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.book,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              book['titulo'] ?? 'Sin título',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(
                                  'Autor: ${book['autor'] ?? "Desconocido"} • Modalidad: ${book['modalidad'] ?? "VENTA"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDisponible
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDisponible
                                              ? Colors.green.shade600
                                              : Colors.orange.shade600,
                                        ),
                                      ),
                                      child: Text(
                                        isDisponible
                                            ? 'DISPONIBLE'
                                            : 'NO DISPONIBLE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDisponible
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (precio > 0)
                                      Text(
                                        currencyFormatter.format(precio),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: isDisponible
                                ? ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red.shade800,
                                      side: BorderSide(
                                        color: Colors.red.shade400,
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_forever_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Eliminar libro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onPressed: () => _confirmDeleteBook(book),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Historial protegido',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPONENTES COMUNES: BANNER Y TARJETAS DE MÉTRICAS
  // ===========================================================================
  Widget _buildAdminBanner() {
    final auth = context.watch<AuthProvider>();
    final nombreAdmin =
        auth.currentUser?.nombreCompleto ?? 'Deiby Vargas (Administrador)';
    final emailAdmin = auth.currentUser?.email ?? 'vargasdeiby54@gmail.com';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Observatorio & Administración Central UDEC',
                      softWrap: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sesión activa: $nombreAdmin ($emailAdmin)',
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _adminBadge(
                          'ROL: ADMINISTRADOR (RBAC)',
                          Colors.amber,
                          Colors.black87,
                        ),
                        _adminBadge(
                          'CAMPUS MULTISEDE CONECTADO',
                          Colors.white.withOpacity(0.15),
                          Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _adminBadge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        softWrap: true,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String deltaText,
    required Color deltaColor,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        deltaText,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.15,
                          fontWeight: FontWeight.bold,
                          color: deltaColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                fontSize: 22,
                height: 1.05,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12,
                height: 1.15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

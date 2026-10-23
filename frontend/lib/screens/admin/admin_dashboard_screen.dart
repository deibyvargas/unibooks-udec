import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _stats;
  List<dynamic> _usersList = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usersSnap = await _firestore.collection('usuarios').get();
      final pubSnap = await _firestore.collection('publicaciones').get();
      final txSnap = await _firestore.collection('transacciones').get();

      final users = usersSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();

      final totalEstudiantes = users.where((u) => u['rol'] == 'ESTUDIANTE').length;

      setState(() {
        _stats = {
          'admin': 'Deiby Vargas',
          'metricas': {
            'total_usuarios': users.length,
            'total_estudiantes': totalEstudiantes,
            'total_publicaciones': pubSnap.docs.length,
            'transacciones_totales': txSnap.docs.length,
          }
        };
        _usersList = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUserStatus(String userId, String currentStatus) async {
    try {
      final nuevoEstado = (currentStatus == 'ACTIVO') ? 'SUSPENDIDO' : 'ACTIVO';
      await _firestore.collection('usuarios').doc(userId).update({
        'estado': nuevoEstado,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a $nuevoEstado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al modificar estado: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Panel de Control Administrativo (RBAC)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar métricas',
            onPressed: _loadAdminData,
          ),
        ],
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
                        const Icon(Icons.lock_person_rounded, size: 54, color: AppColors.danger),
                        const SizedBox(height: 12),
                        const Text(
                          'Acceso Restringido por RBAC',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAdminData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner de Privilegios Administrativos
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 32),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Administrador Principal del Sistema',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Sesión activa: ${_stats?["admin"] ?? "Deiby Vargas"} (vargasdeiby54@gmail.com)',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ROL: ADMINISTRADOR (INMUTABLE)',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Métricas clave del sistema
                          const Text(
                            'Métricas Generales de la Comunidad',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          _buildStatsGrid(),
                          const SizedBox(height: 28),

                          // Moderación de Cuentas de Usuario
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Gestión de Cuentas y Moderación (RBAC)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_usersList.length} cuentas registradas',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Lista de Usuarios
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _usersList.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final u = _usersList[index];
                                final bool esAdmin = (u['rol'] == 'ADMINISTRADOR' || u['rol'] == 'ADMIN');
                                final bool estaActivo = (u['activo'] == true || u['estado'] == 'ACTIVO');

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: esAdmin
                                        ? Colors.amber.withOpacity(0.2)
                                        : AppColors.primary.withOpacity(0.1),
                                    child: Icon(
                                      esAdmin ? Icons.shield : Icons.person,
                                      color: esAdmin ? Colors.amber.shade800 : AppColors.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        u['nombre_completo'] ?? 'Usuario',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: esAdmin ? Colors.amber : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          u['rol'] ?? 'ESTUDIANTE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: esAdmin ? Colors.black87 : Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${u['email']} • Estado: ${estaActivo ? "ACTIVO" : "SUSPENDIDO"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: estaActivo ? AppColors.textSecondary : Colors.red,
                                    ),
                                  ),
                                  trailing: esAdmin
                                      ? const Chip(
                                          label: Text('Protegido', style: TextStyle(fontSize: 11)),
                                          backgroundColor: Colors.transparent,
                                        )
                                      : OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: estaActivo ? Colors.red : AppColors.primary,
                                            side: BorderSide(color: estaActivo ? Colors.red : AppColors.primary),
                                          ),
                                          onPressed: () => _toggleUserStatus(u['id'], u['estado']),
                                          child: Text(estaActivo ? 'Suspender' : 'Reactivar'),
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
                ),
    );
  }

  Widget _buildStatsGrid() {
    final metricas = _stats?['metricas'] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMobile ? 1.4 : 1.6,
          children: [
            _buildMetricCard(
              title: 'Total Usuarios',
              value: '${metricas["total_usuarios"] ?? 0}',
              icon: Icons.people_alt_rounded,
              color: Colors.blue,
            ),
            _buildMetricCard(
              title: 'Estudiantes',
              value: '${metricas["total_estudiantes"] ?? 0}',
              icon: Icons.school_rounded,
              color: AppColors.primary,
            ),
            _buildMetricCard(
              title: 'Libros Catálogo',
              value: '${metricas["total_publicaciones"] ?? 0}',
              icon: Icons.menu_book_rounded,
              color: Colors.purple,
            ),
            _buildMetricCard(
              title: 'Transacciones',
              value: '${metricas["transacciones_totales"] ?? 0}',
              icon: Icons.swap_horiz_rounded,
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

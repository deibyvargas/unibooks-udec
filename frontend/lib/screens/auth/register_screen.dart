import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefonoController = TextEditingController();

  String? _selectedSedeId;
  String? _selectedProgramaId;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogProvider>();
    if (catalog.sedes.isNotEmpty) {
      _selectedSedeId = catalog.sedes.first.id;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nombreCompleto: _nombreController.text.trim(),
      sedeId: _selectedSedeId,
      programaId: _selectedProgramaId,
      telefono: _telefonoController.text.trim(),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta institucional creada exitosamente! Bienvenido a Unibooks.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Error al registrar la cuenta'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Registro Institucional UDEC'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabecera institucional
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, size: 40, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Crear Cuenta en Unibooks',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Comunidad universitaria de la Universidad de Cundinamarca',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),

                      // Regla de Negocio: Aviso de Dominio Obligatorio
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Solo correos institucionales (@ucundinamarca.edu.co)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nombre Completo
                      TextFormField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y Apellidos completos *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 3) {
                            return 'Ingresa tu nombre completo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Correo Electrónico Institucional
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Institucional *',
                          hintText: 'ejemplo@ucundinamarca.edu.co',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa tu correo institucional';
                          }
                          final clean = val.trim().toLowerCase();
                          // Validación estricta con excepción del Administrador Principal
                          if (clean != 'vargasdeiby54@gmail.com' && !clean.endsWith('@ucundinamarca.edu.co')) {
                            return 'Debes utilizar tu correo institucional de la Universidad de Cundinamarca (@ucundinamarca.edu.co)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sede Universitaria
                      DropdownButtonFormField<String>(
                        value: _selectedSedeId,
                        decoration: const InputDecoration(
                          labelText: 'Sede Principal UDEC *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: catalog.sedes.isNotEmpty
                            ? catalog.sedes
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)))
                                .toList()
                            : const [
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111101',
                                  child: Text('Sede Fusagasugá (Principal)'),
                                ),
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111102',
                                  child: Text('Seccional Girardot'),
                                ),
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111103',
                                  child: Text('Seccional Ubaté'),
                                ),
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111104',
                                  child: Text('Extensión Facatativá'),
                                ),
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111105',
                                  child: Text('Extensión Chía'),
                                ),
                                DropdownMenuItem(
                                  value: '11111111-1111-1111-1111-111111111106',
                                  child: Text('Extensión Soacha'),
                                ),
                              ],
                        onChanged: (val) => setState(() => _selectedSedeId = val),
                      ),
                      const SizedBox(height: 14),

                      // Carrera / Programa Académico
                      DropdownButtonFormField<String>(
                        value: _selectedProgramaId ?? '33333333-3333-3333-3333-333333333301',
                        decoration: const InputDecoration(
                          labelText: 'Programa Académico / Carrera *',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '33333333-3333-3333-3333-333333333301',
                            child: Text('Ingeniería de Sistemas y Computación'),
                          ),
                          DropdownMenuItem(
                            value: '33333333-3333-3333-3333-333333333302',
                            child: Text('Ingeniería Electrónica'),
                          ),
                          DropdownMenuItem(
                            value: '33333333-3333-3333-3333-333333333305',
                            child: Text('Agronomía'),
                          ),
                          DropdownMenuItem(
                            value: '33333333-3333-3333-3333-333333333307',
                            child: Text('Administración de Empresas'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedProgramaId = val),
                      ),
                      const SizedBox(height: 14),

                      // Teléfono
                      TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono Móvil (WhatsApp de contacto)',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña (mínimo 6 caracteres) *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'La contraseña debe tener mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirmar Contraseña
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Contraseña *',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (val) {
                          if (val != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      if (auth.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Botón de Registro
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Registrarme en Unibooks UDEC'),
                        onPressed: auth.isLoading ? null : _submitRegister,
                      ),
                      const SizedBox(height: 16),

                      // Enlace a Iniciar Sesión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿Ya tienes cuenta?', style: TextStyle(fontSize: 13)),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Conectado a Google Firebase Cloud (BaaS)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

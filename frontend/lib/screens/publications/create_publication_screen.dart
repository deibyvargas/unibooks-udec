import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/book_image_picker_widget.dart';

class CreatePublicationScreen extends StatefulWidget {
  final VoidCallback? onPublishedSuccess;
  const CreatePublicationScreen({super.key, this.onPublishedSuccess});

  @override
  State<CreatePublicationScreen> createState() => _CreatePublicationScreenState();
}

class _CreatePublicationScreenState extends State<CreatePublicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<BookImagePickerWidgetState> _imagePickerKey = GlobalKey<BookImagePickerWidgetState>();

  final _tituloController = TextEditingController();
  final _autorController = TextEditingController();
  final _editorialController = TextEditingController();
  final _edicionController = TextEditingController();
  final _anoController = TextEditingController();
  final _isbnController = TextEditingController();
  final _materiaController = TextEditingController();
  final _precioController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _interesController = TextEditingController();
  List<BookPhotoItem> _selectedPhotos = [];

  String? _selectedSedeId;
  String? _selectedFacultadId;
  int _selectedSemestre = 1;
  String _selectedCondicion = 'BUEN_ESTADO';
  String _selectedModalidad = 'VENTA_O_INTERCAMBIO';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogProvider>();
    if (catalog.sedes.isNotEmpty) {
      _selectedSedeId = catalog.sedes.first.id;
    }
    if (catalog.facultades.isNotEmpty) {
      _selectedFacultadId = catalog.facultades.first.id;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _editorialController.dispose();
    _edicionController.dispose();
    _anoController.dispose();
    _isbnController.dispose();
    _materiaController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    _interesController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _submitForm() async {
    // 1. [DEBUG] Botón presionado.
    debugPrint('[DEBUG] Botón presionado.');

    if (_isSubmitting) {
      debugPrint('[DEBUG] Proceso ya en ejecución, ignorando pulsación duplicada.');
      return;
    }

    // 2. [DEBUG] Estado de validación del formulario (¿es válido o qué campo falló?).
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      String failedReason = 'Por favor completa todos los campos requeridos con datos válidos.';
      if (_tituloController.text.trim().length < 2) {
        failedReason = 'Error en el Título: Debe tener al menos 2 caracteres.';
      } else if (_autorController.text.trim().length < 2) {
        failedReason = 'Error en el Autor: Debe tener al menos 2 caracteres.';
      } else if ((_selectedModalidad == 'VENTA' || _selectedModalidad == 'VENTA_O_INTERCAMBIO') &&
                 (double.tryParse(_precioController.text.trim()) == null ||
                  double.parse(_precioController.text.trim()) < 0)) {
        failedReason = 'Error en el Precio: Ingresa un precio numérico válido mayor o igual a 0.';
      } else if (_descripcionController.text.trim().length < 10) {
        failedReason = 'Error en la Descripción: Debe tener al menos 10 caracteres describiendo el libro.';
      }

      debugPrint('[DEBUG] Estado de validación del formulario: INVÁLIDO. Detalle: $failedReason');
      _showErrorSnackBar(failedReason);
      return;
    }
    debugPrint('[DEBUG] Estado de validación del formulario: VÁLIDO.');

    // Validar Sede obligatoria
    final catalog = context.read<CatalogProvider>();
    final effectiveSedeId = _selectedSedeId ?? (catalog.sedes.isNotEmpty ? catalog.sedes.first.id : null);
    if (effectiveSedeId == null || effectiveSedeId.isEmpty) {
      const msg = 'Error: Debes seleccionar una sede física de la UDEC.';
      debugPrint('[DEBUG] Validación falló: $msg');
      _showErrorSnackBar(msg);
      return;
    }

    // 3. [DEBUG] Estado de las fotos seleccionadas (rutas o bytes).
    debugPrint('[DEBUG] Estado de las fotos seleccionadas: Total ${_selectedPhotos.length} fotos.');
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final p = _selectedPhotos[i];
      debugPrint('  -> [Foto $i] esLocal=${p.isLocal}, bytes=${p.bytes?.lengthInBytes ?? 0}b, url=${p.url}');
    }

    if (_selectedPhotos.isEmpty) {
      const msg = 'Error: Debes adjuntar al menos una fotografía del ejemplar para verificar su condición física.';
      debugPrint('[DEBUG] Validación falló: $msg');
      _showErrorSnackBar(msg);
      return;
    }

    // Validar sesión de usuario y estado activo
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      const msg = 'Error 401: No has iniciado sesión. Ingresa con tu cuenta institucional para publicar.';
      debugPrint('[DEBUG] Error de autenticación: $msg');
      _showErrorSnackBar(msg);
      return;
    }

    if (auth.currentUser?.isSuspended == true || auth.currentUser?.isActivo == false) {
      const msg = 'Tu cuenta ha sido suspendida por un administrador';
      debugPrint('[DEBUG] Usuario suspendido: $msg');
      _showErrorSnackBar(msg);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Subida de imágenes locales al backend o almacenamiento
      List<String> uploadedUrls = [];
      try {
        final tempBookId = 'pub_${DateTime.now().millisecondsSinceEpoch}';
        uploadedUrls = await _imagePickerKey.currentState?.uploadAllPhotos(bookId: tempBookId) ?? [];
        debugPrint('[DEBUG] URLs de fotos obtenidas: $uploadedUrls');
      } catch (uploadError) {
        debugPrint('[DEBUG] Error al subir imágenes locales: $uploadError');
        _showErrorSnackBar('Error al procesar las fotografías: $uploadError');
        return;
      }

      final double parsedPrecio = double.tryParse(_precioController.text.trim()) ?? 0.0;
      final double effectivePrecio = (_selectedModalidad == 'DONACION' || _selectedModalidad == 'INTERCAMBIO')
          ? 0.0
          : parsedPrecio;
      final int? ano = int.tryParse(_anoController.text.trim());

      final finalFotos = uploadedUrls.isNotEmpty
          ? uploadedUrls
          : _selectedPhotos.where((p) => p.url != null && p.url!.isNotEmpty).map((p) => p.url!).toList();

      final List<String> fotosParaEnviar = finalFotos.isNotEmpty
          ? finalFotos
          : ['https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c'];

      final currentUser = auth.currentUser;
      final userId = currentUser?.id ?? currentUser?.firebaseUid ?? '';

      // 4. [Cloud Firestore] Payload del documento
      final body = <String, dynamic>{
        'usuario_id': userId,
        if (currentUser != null) 'usuario': currentUser.toJson(),
        'titulo': _tituloController.text.trim(),
        'autor': _autorController.text.trim(),
        if (_editorialController.text.isNotEmpty) 'editorial': _editorialController.text.trim(),
        if (_edicionController.text.isNotEmpty) 'edicion': _edicionController.text.trim(),
        if (ano != null) 'ano_publicacion': ano,
        if (_isbnController.text.isNotEmpty) 'isbn': _isbnController.text.trim(),
        if (_materiaController.text.isNotEmpty) 'materia': _materiaController.text.trim(),
        'semestre_sugerido': _selectedSemestre,
        'sede_id': effectiveSedeId,
        if (_selectedFacultadId != null) 'facultad_id': _selectedFacultadId,
        'condicion_libro': _selectedCondicion,
        'modalidad': _selectedModalidad,
        'precio': effectivePrecio,
        'descripcion': _descripcionController.text.trim(),
        if (_interesController.text.isNotEmpty) 'interes_intercambio': _interesController.text.trim(),
        'fotos_urls': fotosParaEnviar,
      };

      debugPrint('[DEBUG] Payload a guardar en Cloud Firestore:');
      debugPrint(const JsonEncoder.withIndent('  ').convert(body));

      // 5. Inserción directa en Cloud Firestore
      final success = await catalog.createPublication(body);

      if (!mounted) return;

      if (success) {
        debugPrint('[DEBUG] ¡Publicación registrada exitosamente en la base de datos!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('¡Libro publicado exitosamente en la UDEC!')),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Resetear formulario
        _formKey.currentState?.reset();
        _tituloController.clear();
        _autorController.clear();
        _editorialController.clear();
        _edicionController.clear();
        _anoController.clear();
        _isbnController.clear();
        _materiaController.clear();
        _precioController.clear();
        _descripcionController.clear();
        _interesController.clear();
        setState(() {
          _selectedPhotos.clear();
        });

        // Redirigir al catálogo principal
        if (widget.onPublishedSuccess != null) {
          widget.onPublishedSuccess!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        final errorMsg = catalog.errorMessage ?? 'Error desconocido al registrar el ejemplar en el backend.';
        debugPrint('[DEBUG] Fallo reportado por CatalogProvider: $errorMsg');
        _showErrorSnackBar(errorMsg);
      }
    } catch (e, stackTrace) {
      debugPrint('[DEBUG] Excepción no controlada durante la publicación: $e');
      debugPrint('[DEBUG] StackTrace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Error inesperado al publicar el libro: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final isProcessing = _isSubmitting || catalog.isLoading;

    // Asegurar que si las sedes se cargaron de forma asíncrona, se preseleccione la primera
    final currentSede = _selectedSedeId ?? (catalog.sedes.isNotEmpty ? catalog.sedes.first.id : null);
    final currentFacultad = _selectedFacultadId ?? (catalog.facultades.isNotEmpty ? catalog.facultades.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar Libro en Unibooks'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Ejemplar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título del libro *',
                  hintText: 'Ej. Cálculo: Trascendentes Tempranas',
                  prefixIcon: Icon(Icons.book_rounded),
                ),
                validator: (val) => (val == null || val.trim().length < 2)
                    ? 'Ingresa el título del libro (mínimo 2 caracteres)'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _autorController,
                decoration: const InputDecoration(
                  labelText: 'Autor(es) *',
                  hintText: 'Ej. James Stewart, Robert Adams',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (val) => (val == null || val.trim().length < 2)
                    ? 'Ingresa el autor (mínimo 2 caracteres)'
                    : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _editorialController,
                      decoration: const InputDecoration(
                        labelText: 'Editorial',
                        hintText: 'Ej. Pearson, Cengage',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _edicionController,
                      decoration: const InputDecoration(
                        labelText: 'Edición',
                        hintText: 'Ej. 7ma Edición',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _materiaController,
                      decoration: const InputDecoration(
                        labelText: 'Asignatura / Materia',
                        hintText: 'Ej. Cálculo Diferencial',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSemestre,
                      decoration: const InputDecoration(labelText: 'Semestre sugerido'),
                      items: List.generate(10, (index) => index + 1)
                          .map((sem) => DropdownMenuItem(value: sem, child: Text('Semestre $sem')))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSemestre = val ?? 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Ubicación y Dependencia Institucional',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Selector de Sede Física UDEC
              DropdownButtonFormField<String>(
                initialValue: currentSede,
                decoration: const InputDecoration(
                  labelText: 'Sede donde se encuentra el libro *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: catalog.sedes.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.nombre),
                )).toList(),
                validator: (val) => (val == null || val.isEmpty) ? 'Selecciona una sede física de la UDEC' : null,
                onChanged: (val) => setState(() => _selectedSedeId = val),
              ),
              const SizedBox(height: 12),

              // Selector opcional de Facultad
              if (catalog.facultades.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: currentFacultad,
                  decoration: const InputDecoration(
                    labelText: 'Facultad Académica vinculada',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: catalog.facultades.map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text('${f.nombre} (${f.sigla ?? ""})'),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedFacultadId = val),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 14),
              Text(
                'Modalidad y Estado Físico',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedModalidad,
                decoration: const InputDecoration(
                  labelText: 'Modalidad de oferta *',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'VENTA_O_INTERCAMBIO', child: Text('Venta o Trueque (Recomendado)')),
                  DropdownMenuItem(value: 'VENTA', child: Text('Solo Venta')),
                  DropdownMenuItem(value: 'INTERCAMBIO', child: Text('Solo Trueque / Intercambio')),
                  DropdownMenuItem(value: 'DONACION', child: Text('Donación (Gratis para la comunidad)')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedModalidad = val ?? 'VENTA_O_INTERCAMBIO';
                    if (_selectedModalidad == 'DONACION' || _selectedModalidad == 'INTERCAMBIO') {
                      _precioController.text = '0';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              if (_selectedModalidad == 'VENTA' || _selectedModalidad == 'VENTA_O_INTERCAMBIO') ...[
                TextFormField(
                  controller: _precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio sugerido en Pesos Colombianos (COP) *',
                    hintText: 'Ej. 45000',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (val) {
                    final num = double.tryParse(val?.trim() ?? '');
                    if (num == null || num < 0) return 'Ingresa un precio válido mayor o igual a 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<String>(
                initialValue: _selectedCondicion,
                decoration: const InputDecoration(
                  labelText: 'Condición física del libro *',
                  prefixIcon: Icon(Icons.check_box_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'NUEVO', child: Text('Nuevo (Sin uso)')),
                  DropdownMenuItem(value: 'COMO_NUEVO', child: Text('Como Nuevo (Poco uso, sin marcas)')),
                  DropdownMenuItem(value: 'BUEN_ESTADO', child: Text('Buen Estado (Subrayados menores)')),
                  DropdownMenuItem(value: 'ACEPTABLE', child: Text('Aceptable (Hojas desgastadas o marcas)')),
                  DropdownMenuItem(value: 'DESGASTADO', child: Text('Desgastado / Para restaurar')),
                ],
                onChanged: (val) => setState(() => _selectedCondicion = val ?? 'BUEN_ESTADO'),
              ),
              const SizedBox(height: 16),

              // Selector y Galería de Fotografías del Ejemplar (1 a 4 fotos)
              BookImagePickerWidget(
                key: _imagePickerKey,
                initialPhotos: _selectedPhotos,
                onPhotosChanged: (photos) => setState(() => _selectedPhotos = photos),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción del libro * (Mínimo 10 caracteres)',
                  hintText: 'Detalles sobre anotaciones, estado de hojas, motivos de venta, etc.',
                  alignLabelWithHint: true,
                ),
                validator: (val) => (val == null || val.trim().length < 10)
                    ? 'Describe el libro con al menos 10 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),

              if (_selectedModalidad != 'VENTA') ...[
                TextFormField(
                  controller: _interesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '¿Qué libros o materias te interesan a cambio?',
                    hintText: 'Ej. Libros de Física Universitaria, Cálculo Vectorial, Algoritmos...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 24),

              // BOTÓN PRINCIPAL DE PUBLICACIÓN CON FEEDBACK VISUAL
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    isProcessing
                        ? 'Publicando ejemplar en la UDEC...'
                        : 'Publicar Ejemplar en la UDEC',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: isProcessing ? null : _submitForm,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

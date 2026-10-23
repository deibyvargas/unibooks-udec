import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Pantalla previa estilo WhatsApp para previsualizar la foto antes de enviarla
/// Permite añadir un pie de foto (caption) y confirmar o descartar el envío con alto contraste
class ChatPhotoPreviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;
  final String? initialCaption;
  final bool isDarkTheme;

  const ChatPhotoPreviewScreen({
    super.key,
    required this.imageBytes,
    required this.fileName,
    this.initialCaption,
    this.isDarkTheme = true,
  });

  @override
  State<ChatPhotoPreviewScreen> createState() => _ChatPhotoPreviewScreenState();
}

class _ChatPhotoPreviewScreenState extends State<ChatPhotoPreviewScreen> {
  late final TextEditingController _captionController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption ?? '');
  }

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirmSend() {
    Navigator.of(context).pop({
      'confirmed': true,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colores explícitos según el tema para garantizar 100% de contraste y legibilidad
    final bool isDark = widget.isDarkTheme;
    final Color screenBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD);
    final Color barBg = isDark ? Colors.black87 : Colors.white;
    final Color inputContainerBg = isDark ? Colors.black87 : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color hintColor = isDark ? Colors.white70 : (Colors.grey[600] ?? Colors.grey);
    final Color cursorColor = isDark ? Colors.green : const Color(0xFF00A884);
    final Color iconColor = isDark ? Colors.white70 : (Colors.grey[600] ?? Colors.grey);
    final Color borderColor = isDark ? Colors.white24 : (Colors.grey[300] ?? Colors.grey);

    return Scaffold(
      backgroundColor: screenBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black87 : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 28),
          tooltip: 'Descartar',
          onPressed: () => Navigator.of(context).pop({'confirmed': false}),
        ),
        title: Text(
          widget.fileName,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate_rounded),
            tooltip: 'Ajustar',
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Área central de la foto con zoom interactivo adaptativo y SingleChildScrollView
            // Evita el error 'BOTTOM OVERFLOWED' al desplegarse el teclado en pantallas pequeñas
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 0,
                          minWidth: constraints.maxWidth,
                        ),
                        child: Center(
                          child: InteractiveViewer(
                            clipBehavior: Clip.hardEdge,
                            minScale: 0.8,
                            maxScale: 3.5,
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Barra inferior de pie de foto estilo WhatsApp con protección contra desbordamiento
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: barBg,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Campo de texto con colores explícitos para alto contraste
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: inputContainerBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.0),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          // Previene contaminación del tema global (evita fondo blanco con texto blanco)
                          inputDecorationTheme: const InputDecorationTheme(
                            filled: false,
                            border: InputBorder.none,
                          ),
                        ),
                        child: TextField(
                          controller: _captionController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                          cursorColor: cursorColor,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputContainerBg,
                            hintText: 'Añade un comentario...',
                            hintStyle: TextStyle(
                              color: hintColor,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            icon: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: iconColor,
                              size: 22,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _confirmSend(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botón flotante verde de envío estilo WhatsApp
                  GestureDetector(
                    onTap: _confirmSend,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A884), // WhatsApp Send Green
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


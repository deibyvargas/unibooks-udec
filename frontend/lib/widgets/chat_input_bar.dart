import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final bool isUploading;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onCameraTap,
    required this.onGalleryTap,
    this.isUploading = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasTextNow = _controller.text.trim().isNotEmpty;
      if (hasTextNow != _hasText) {
        setState(() => _hasText = hasTextNow);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        child: Row(
          children: [
            // Contenedor principal estilo píldora de WhatsApp
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),

                    // Botón Clip / Adjuntar evidencia
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF54656F), size: 22),
                      tooltip: 'Adjuntar Imagen de Galería',
                      onPressed: widget.isUploading ? null : widget.onGalleryTap,
                      splashRadius: 20,
                    ),

                    // Campo de Texto de Mensajería
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        cursorColor: const Color(0xFF00A884),
                        decoration: InputDecoration(
                          hintText: 'Mensaje institucional...',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),

                    // Botón Cámara Instantánea
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF54656F), size: 22),
                      tooltip: 'Tomar Foto Instantánea',
                      onPressed: widget.isUploading ? null : widget.onCameraTap,
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Botón Circular de Envío estilo WhatsApp
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF00A884), // WhatsApp Green
              child: widget.isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _submit,
                      tooltip: 'Enviar',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

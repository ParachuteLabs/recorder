import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? borderColor;
  final Color? textColor;
  final Color? fillColor;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.borderColor,
    this.textColor,
    this.fillColor,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColor ?? Colors.white.withOpacity(0.6);
    final textColor = widget.textColor ?? Colors.white;
    final fillColor = widget.fillColor ?? Colors.white.withOpacity(0.2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          color: _isPressed ? fillColor : Colors.transparent,
          border: Border.all(
            color: _isPressed ? Colors.white : borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _isPressed ? Colors.white : textColor,
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}

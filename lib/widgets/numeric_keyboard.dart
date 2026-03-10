import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onBackspacePressed;
  final bool showBackspace;

  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onBackspacePressed,
    this.showBackspace = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ряды цифр
        for (int row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Первые три ряда
                if (row < 3)
                  ...List.generate(3, (col) {
                    final number = (row * 3 + col + 1).toString();
                    return _KeypadButton(
                      text: number,
                      onPressed: () => onKeyPressed(number),
                    );
                  })
                // Последний ряд
                else ...[
                  const SizedBox(width: 64),
                  _KeypadButton(
                    text: '0',
                    onPressed: () => onKeyPressed('0'),
                  ),
                  if (showBackspace)
                    _KeypadButton(
                      icon: Icons.backspace_outlined,
                      onPressed: onBackspacePressed,
                    )
                  else
                    const SizedBox(width: 64),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onPressed;

  const _KeypadButton({
    this.text,
    this.icon,
    required this.onPressed,
  }) : assert(text != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: text != null
                  ? Text(
                text!,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
                  : Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
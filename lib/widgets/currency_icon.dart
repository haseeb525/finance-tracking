import 'package:flutter/material.dart';

/// Custom widget to display "Rs" as a currency icon
/// Matches the Material Icon style and inherits theme colors
class CurrencyIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const CurrencyIcon({Key? key, this.size, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.primary;
    final iconSize = size ?? IconTheme.of(context).size ?? 24.0;

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Center(
        child: Text(
          'Rs',
          style: TextStyle(
            fontSize: iconSize * 0.65, // Proportional to icon size
            fontWeight: FontWeight.w900,
            color: iconColor,
            letterSpacing: -1.0, // Tighter spacing for "Rs"
          ),
        ),
      ),
    );
  }
}

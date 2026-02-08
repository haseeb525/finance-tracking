import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/theme_provider.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      AppTheme.neonBlue.withOpacity(0.2),
                      AppTheme.neonPurple.withOpacity(0.2),
                    ],
                  )
                : null,
            color: !isDark ? Colors.grey.shade200 : null,
          ),
          child: IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? AppTheme.neonYellow : Colors.orange,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        );
      },
    );
  }
}

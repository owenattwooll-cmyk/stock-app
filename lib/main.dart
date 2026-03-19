import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFF08111F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7F1D1D)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Something went wrong while rendering this screen.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY. Use --dart-define.');
  }
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    final isNativeDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7C86FF),
      onPrimary: Colors.white,
      secondary: const Color(0xFF22C55E),
      onSecondary: const Color(0xFF04130A),
      surface: const Color(0xFF111827),
      onSurface: const Color(0xFFF8FAFC),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1F2937),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );
    return MaterialApp.router(
      title: 'Stock Plunge',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF253246)),
        visualDensity: isNativeDesktop ? VisualDensity.compact : VisualDensity.standard,
        materialTapTargetSize: isNativeDesktop ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
        dataTableTheme: DataTableThemeData(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFF192436)),
          dataRowColor: const WidgetStatePropertyAll(Color(0xFF111827)),
          dividerThickness: 0.5,
          headingRowHeight: isNativeDesktop ? 40 : 44,
          dataRowMinHeight: isNativeDesktop ? 42 : 48,
          dataRowMaxHeight: isNativeDesktop ? 56 : 64,
          horizontalMargin: isNativeDesktop ? 16 : 20,
          columnSpacing: isNativeDesktop ? 16 : 20,
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFCBD5E1),
            letterSpacing: 0.3,
          ),
          dataTextStyle: TextStyle(
            fontSize: isNativeDesktop ? 12.5 : 13,
            color: const Color(0xFFE5E7EB),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          centerTitle: false,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF101A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF8FAFC),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF94A3B8),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF8FAFC),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF8FAFC),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF94A3B8),
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
          labelLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFFCBD5E1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C86FF)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isNativeDesktop ? 18 : 20,
              vertical: isNativeDesktop ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isNativeDesktop ? 16 : 18,
              vertical: isNativeDesktop ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFF334155)),
            foregroundColor: const Color(0xFFE2E8F0),
            backgroundColor: const Color(0xFF121C2D),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9FB0FF),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF172131),
          disabledColor: const Color(0xFF172131),
          selectedColor: const Color(0xFF2A3560),
          secondarySelectedColor: const Color(0xFF2A3560),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
          secondaryLabelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
          brightness: Brightness.dark,
          side: const BorderSide(color: Color(0xFF334155)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF101A2A),
          contentTextStyle: TextStyle(color: Color(0xFFF8FAFC)),
        ),
      ),
      routerConfig: router,
    );
  }
}

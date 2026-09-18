import 'package:flutter/material.dart';

/// Uygulama renk paleti.
///
/// SADECE karanlik mod desteklenir. Acik mod tanimi yoktur ve
/// [ThemeMode.dark] disinda bir mod kullanilmamalidir.
///
/// Zemin ve kartlar: #0A0A0A, #141414, #1E1E1E
/// Metin ve vurgular (kemik beyazi): #F5F5F0, #EAE6DF
/// Cizgi ve kenarlik: #262626
/// Ikincil metin (notr gri): #8E8E93
abstract final class AppColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF141414);
  static const Color dialog = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF1E1E1E);

  static const Color boneWhite = Color(0xFFF5F5F0);
  static const Color boneWhiteDim = Color(0xFFEAE6DF);

  static const Color border = Color(0xFF262626);

  static const Color secondaryText = Color(0xFF8E8E93);

  /// Olumlu durum vurgusu (stokta var vb.). Paleti bozmayacak sekilde
  /// dusuk doygunluklu notr-yesil ton.
  static const Color success = Color(0xFF9DB89A);

  /// Uyarici durum vurgusu (kritik stok vb.). Dusuk doygunluklu notr kehribar.
  static const Color warning = Color(0xFFC9B48A);

  /// Yikici islem vurgusu (silme onayi vb.). Dusuk doygunluklu notr kirmizi.
  static const Color danger = Color(0xFFC08A8A);

  static const Color disabled = Color(0xFF52525B);
}

/// Rakamlar icin tek aralikh (tabular) hizalama saglayan yadimci.
///
/// Ornek kullanim:
/// ```dart
/// Text('Adet: 128', style: tabularTextStyle(Theme.of(context).textTheme.bodyMedium)),
/// ```
TextStyle? tabularTextStyle(TextStyle? base) {
  return (base ?? const TextStyle()).copyWith(
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// Rakam iceren metinler icin dogrudan kullanilabilecek hazir stil.
const TextStyle tabularNumbers = TextStyle(
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

/// Uygulama temasi. SADECE karanlik mod.
///
/// Kullanim:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.darkTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ThemeMode.dark,
///   ...
/// );
/// ```
abstract final class AppTheme {
  static ThemeData get darkTheme {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.boneWhite,
      onPrimary: AppColors.background,
      secondary: AppColors.boneWhiteDim,
      onSecondary: AppColors.background,
      surface: AppColors.card,
      onSurface: AppColors.boneWhite,
      surfaceContainerHighest: AppColors.surfaceVariant,
      error: AppColors.danger,
      onError: AppColors.background,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    const TextTheme baseText = TextTheme(
      displayLarge: TextStyle(color: AppColors.boneWhite),
      displayMedium: TextStyle(color: AppColors.boneWhite),
      displaySmall: TextStyle(color: AppColors.boneWhite),
      headlineLarge: TextStyle(color: AppColors.boneWhite),
      headlineMedium: TextStyle(color: AppColors.boneWhite),
      headlineSmall: TextStyle(color: AppColors.boneWhite),
      titleLarge: TextStyle(color: AppColors.boneWhite),
      titleMedium: TextStyle(color: AppColors.boneWhite),
      titleSmall: TextStyle(color: AppColors.boneWhite),
      bodyLarge: TextStyle(color: AppColors.boneWhite),
      bodyMedium: TextStyle(color: AppColors.boneWhite),
      bodySmall: TextStyle(color: AppColors.secondaryText),
      labelLarge: TextStyle(color: AppColors.boneWhite),
      labelMedium: TextStyle(color: AppColors.boneWhiteDim),
      labelSmall: TextStyle(color: AppColors.secondaryText),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      disabledColor: AppColors.disabled,
      hintColor: AppColors.secondaryText,
      primaryColor: AppColors.boneWhite,
      textTheme: baseText,
      iconTheme: const IconThemeData(
        color: AppColors.boneWhiteDim,
        size: 20,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.boneWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.boneWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.boneWhiteDim,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.dialog,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.boneWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.boneWhiteDim,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.dialog,
        modalBackgroundColor: AppColors.dialog,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.card,
        textColor: AppColors.boneWhite,
        iconColor: AppColors.boneWhiteDim,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        hintStyle: const TextStyle(color: AppColors.secondaryText),
        labelStyle: const TextStyle(color: AppColors.boneWhiteDim),
        prefixIconColor: AppColors.secondaryText,
        suffixIconColor: AppColors.secondaryText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.boneWhiteDim,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.boneWhite,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.secondaryText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.boneWhite,
          disabledForegroundColor: AppColors.disabled,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.boneWhiteDim,
          disabledForegroundColor: AppColors.disabled,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.boneWhite,
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: const TextStyle(color: AppColors.boneWhite),
        actionTextColor: AppColors.boneWhiteDim,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.boneWhite,
        unselectedLabelColor: AppColors.secondaryText,
        indicatorColor: AppColors.boneWhite,
        dividerColor: AppColors.border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.boneWhite,
        disabledColor: AppColors.disabled,
        labelStyle: const TextStyle(color: AppColors.boneWhite),
        secondaryLabelStyle: const TextStyle(color: AppColors.secondaryText),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.boneWhite;
            }
            return Colors.transparent;
          },
        ),
        checkColor: const WidgetStatePropertyAll<Color>(
          AppColors.background,
        ),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.boneWhite;
            }
            return AppColors.secondaryText;
          },
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.boneWhite;
            }
            return AppColors.secondaryText;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.boneWhiteDim.withValues(alpha: 0.35);
            }
            return AppColors.border;
          },
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.boneWhite,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: const TextStyle(color: AppColors.boneWhite, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.dialog,
        elevation: 0,
        textStyle: const TextStyle(color: AppColors.boneWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/nouveau_colis_screen.dart';
import 'screens/scanner_transit_screen.dart';
import 'screens/tracking_client_screen.dart';
import 'screens/rentabilite_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TransColisApp());
}

class TransColisApp extends StatefulWidget {
  const TransColisApp({super.key});

  @override
  State<TransColisApp> createState() => TransColisAppState();

  static TransColisAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<TransColisAppState>();
}

class TransColisAppState extends State<TransColisApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColisTrack Cameroun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _codeSuiviEnCours;

  void _naviguerVersSuivi(String code) {
    setState(() {
      _codeSuiviEnCours = code;
      _currentIndex = 3; // Onglet Suivi Client
    });
  }

  void _naviguerVersNouveauColis() {
    setState(() {
      _currentIndex = 1; // Onglet Nouveau Colis
    });
  }

  void _apresEnregistrement() {
    setState(() {
      _currentIndex = 0; // Retour au Dashboard
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNouveauColis: _naviguerVersNouveauColis,
        onSuivreColis: _naviguerVersSuivi,
      ),
      NouveauColisScreen(
        onColisEnregistre: _apresEnregistrement,
      ),
      ScannerTransitScreen(
        onOuvrirSuivi: _naviguerVersSuivi,
      ),
      TrackingClientScreen(
        initialCode: _codeSuiviEnCours,
      ),
      const RentabiliteScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Tableau de bord',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box, color: AppColors.primary),
            label: 'Nouveau Colis',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.primary),
            label: 'Transit / Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes, color: AppColors.primary),
            label: 'Suivi Client',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up, color: AppColors.primary),
            label: 'Rentabilité',
          ),
        ],
      ),
    );
  }
}

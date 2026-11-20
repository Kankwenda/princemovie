import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/theme.dart';
import 'player/video_player_service.dart';
import 'screens/downloads_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'services/download_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Branche les vrais services d'Edith (TMDB / Archive.org, favoris).
  // En cas d'échec, les implémentations de démonstration restent en place.
  try {
    await AppServices.initRealServices();
  } catch (_) {
    // Mode démonstration : données factices.
  }
  // Branche les vrais lecteur / téléchargements (Tadashi) : sans cela
  // Lecture et Téléchargement resteraient des mocks (NO-GO Ultron).
  AppServices.configure(
    player: VideoPlayerService(),
    downloads: DownloadManager(),
  );
  runApp(const PrinceMovieApp());
}

class PrinceMovieApp extends StatelessWidget {
  const PrinceMovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrinceMovie',
      debugShowCheckedModeBanner: false,
      navigatorKey: VideoPlayerService.navigatorKey,
      theme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}

/// Coque principale : navigation par onglets en bas.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    HomeScreen(onSearchTap: () => _goTo(1)),
    const SearchScreen(),
    const DownloadsScreen(),
    const FavoritesScreen(),
  ];

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goTo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.search), label: 'Recherche'),
          BottomNavigationBarItem(
              icon: Icon(Icons.download), label: 'Téléchargements'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite), label: 'Favoris'),
        ],
      ),
    );
  }
}

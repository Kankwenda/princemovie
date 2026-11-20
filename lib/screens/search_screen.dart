import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/media_card.dart';
import 'detail_screen.dart';

/// Recherche : champ + résultats en grille.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<MediaItem> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await AppServices.catalog.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _hasSearched = true;
    });
  }

  void _openDetail(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher un film/une série/un audio',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      ),
              ),
              onChanged: _runSearch,
              onSubmitted: _runSearch,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'Rechercher un film, une série…',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Aucun résultat.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return MediaCard(
          item: item,
          width: double.infinity,
          posterHeight: 150,
          onTap: () => _openDetail(item),
        );
      },
    );
  }
}

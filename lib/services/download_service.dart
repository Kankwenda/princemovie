import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_services.dart';
import '../core/format.dart';
import '../core/legal_sources.dart';
import '../models/models.dart';

/// Téléchargements avec pause / reprise (contrat [DownloadService]).
///
/// Moteur : `package:http` (pas de dio dans le projet) avec requêtes
/// HTTP `Range` — pause = annulation du flux, reprise = nouvelle requête
/// `Range: bytes=<déjà reçus>-`. Les fichiers vivent dans le dossier
/// privé de l'application (`getApplicationDocumentsDirectory()/downloads`,
/// aucune permission Android nécessaire) et la liste survit au redémarrage
/// (SharedPreferences, JSON).
///
/// SOURCES LÉGALES UNIQUEMENT : chaque URL est validée par
/// [requireLegalSource] (Archive.org, serveur personnel). Toute URL
/// MovieBox / 4KHDHub / Dramachi est rejetée avec [ArgumentError].
class DownloadManager implements DownloadService {
  DownloadManager({http.Client? client}) : _client = client ?? http.Client();

  /// Clé de persistance de la liste (JSON).
  static const String _prefsKey = 'princemovie_downloads_v1';

  /// Sous-dossier des fichiers dans le dossier de l'application.
  static const String _folderName = 'downloads';

  final http.Client _client;
  final List<_Record> _records = [];
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};
  final Set<String> _pauseRequested = {};
  final Set<String> _cancelRequested = {};
  final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast();
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialized = false;

  /// Charge la liste persistée (téléchargements interrompus -> en pause).
  /// Appelée automatiquement au premier usage.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _records.addAll(decoded
            .whereType<Map<String, dynamic>>()
            .map(_Record.fromJson));
        for (var i = 0; i < _records.length; i++) {
          final status = _records[i].status;
          if (status == DownloadStatus.downloading ||
              status == DownloadStatus.queued) {
            _records[i] =
                _records[i].copyWith(status: DownloadStatus.paused);
          }
        }
      } catch (_) {
        _records.clear();
      }
    }
    _initialized = true;
    _emit(force: true);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Libère le client HTTP et le flux. À appeler à la fermeture de l'appli.
  Future<void> dispose() async {
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _controller.close();
    _client.close();
  }

  // ---------------------------------------------------------------------------
  // Contrat DownloadService
  // ---------------------------------------------------------------------------

  @override
  Future<List<DownloadItem>> downloads() async {
    await _ensureInitialized();
    return _records.map((r) => r.toDownloadItem()).toList();
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    await _ensureInitialized();
    yield _records.map((r) => r.toDownloadItem()).toList();
    yield* _controller.stream;
  }

  @override
  Future<void> start(StreamSource source,
      {MediaItem? item, Episode? episode}) async {
    await _ensureInitialized();
    // Garde-fou légal : rejette les sources pirates.
    requireLegalSource(source.url);

    final mediaId = item?.id ?? 'url-${source.url.hashCode.abs()}';
    final title = item?.title ?? _fileNameFromUrl(source.url);
    final quality = source.qualityLabel;
    final id = _downloadId(mediaId, quality, episode);

    final existing = _find(id);
    if (existing != null) {
      if (existing.status == DownloadStatus.completed ||
          existing.status == DownloadStatus.downloading ||
          existing.status == DownloadStatus.queued) {
        return; // déjà là (ou en cours) : rien à faire.
      }
      if (existing.status == DownloadStatus.paused) {
        await resume(id);
        return;
      }
      await _retry(id); // échoué : on recommence à zéro.
      return;
    }

    final dir = await _downloadsDir();
    final fileName = _buildFileName(mediaId, title, quality, episode, source);
    final record = _Record(
      id: id,
      mediaId: mediaId,
      title: title,
      episodeLabel: episode == null
          ? null
          : 'S${episode.seasonNumber ?? 1} E${episode.number}',
      quality: quality,
      url: source.url,
      fileName: fileName,
      filePath: '${dir.path}/$fileName',
      totalBytes: source.sizeBytes ?? 0,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
    );
    _records.insert(0, record);
    await _persist();
    _emit(force: true);
    unawaited(_runDownload(id));
  }

  @override
  Future<void> pause(String id) async {
    await _ensureInitialized();
    final record = _find(id);
    if (record == null || record.status != DownloadStatus.downloading) return;
    _pauseRequested.add(id);
    await _subscriptions[id]?.cancel();
    _update(id, status: DownloadStatus.paused);
  }

  @override
  Future<void> resume(String id) async {
    await _ensureInitialized();
    final record = _find(id);
    if (record == null) return;
    if (record.status == DownloadStatus.failed) {
      await _retry(id);
      return;
    }
    if (record.status != DownloadStatus.paused) return;
    unawaited(_runDownload(id));
  }

  @override
  Future<void> cancel(String id) async {
    await _ensureInitialized();
    final record = _find(id);
    if (record == null) return;
    _cancelRequested.add(id);
    await _subscriptions[id]?.cancel();
    final file = File(record.filePath);
    if (await file.exists()) await file.delete();
    _records.removeWhere((r) => r.id == id);
    await _persist();
    _emit(force: true);
  }

  // ---------------------------------------------------------------------------
  // Méthodes utiles hors contrat (lecteur, lecture hors-ligne)
  // ---------------------------------------------------------------------------

  /// Chemin du fichier téléchargé pour un média (null si absent ou
  /// incomplet). Sert la lecture hors-ligne du lecteur.
  Future<String?> localPathFor(String mediaId,
      {String? quality, Episode? episode}) async {
    await _ensureInitialized();
    for (final record in _records) {
      if (record.mediaId != mediaId) continue;
      if (record.status != DownloadStatus.completed) continue;
      if (quality != null && record.quality != quality) continue;
      if (episode != null &&
          record.episodeLabel !=
              'S${episode.seasonNumber ?? 1} E${episode.number}') {
        continue;
      }
      if (await File(record.filePath).exists()) return record.filePath;
    }
    return null;
  }

  /// Vrai si une version terminée existe pour ce média.
  Future<bool> isDownloaded(String mediaId,
          {String? quality, Episode? episode}) async =>
      await localPathFor(mediaId, quality: quality, episode: episode) != null;

  // ---------------------------------------------------------------------------
  // Moteur de téléchargement (HTTP Range)
  // ---------------------------------------------------------------------------

  Future<void> _runDownload(String id) async {
    var record = _find(id);
    if (record == null) return;
    _update(id, status: DownloadStatus.downloading);

    final startByte = record.downloadedBytes;
    final request = http.Request('GET', Uri.parse(record.url));
    if (startByte > 0) {
      request.headers['Range'] = 'bytes=$startByte-';
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      _setFailed(id, 'Réseau indisponible ($e)');
      return;
    }

    // Le serveur ignore Range (200 au lieu de 206) ou refuse la plage
    // (416) : on recommence à zéro.
    var effectiveStart = startByte;
    if (startByte > 0 &&
        (response.statusCode == 200 || response.statusCode == 416)) {
      effectiveStart = 0;
      final partial = File(record.filePath);
      if (await partial.exists()) await partial.writeAsBytes(const []);
      _update(id, downloadedBytes: 0);
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      _setFailed(id, 'Serveur : HTTP ${response.statusCode}');
      return;
    }

    // Taille totale : Content-Range (« bytes 0-999/5000 ») ou Content-Length.
    var total = record.totalBytes;
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      total = int.tryParse(contentRange.split('/').last) ?? total;
    } else {
      final length = response.headers['content-length'];
      if (length != null) {
        total = (int.tryParse(length) ?? 0) + effectiveStart;
      }
    }

    final file = File(record.filePath);
    final sink = file.openWrite(
      mode: effectiveStart > 0 ? FileMode.append : FileMode.write,
    );
    var downloaded = effectiveStart;
    var sinkClosed = false;
    Future<void> closeSink() async {
      if (!sinkClosed) {
        sinkClosed = true;
        await sink.close();
      }
    }

    StreamSubscription<List<int>>? subscription;
    try {
      subscription = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloaded += chunk.length;
          _updateProgress(id, downloaded, total);
        },
        onError: (Object e) async {
          await closeSink();
          if (!_pauseRequested.contains(id) &&
              !_cancelRequested.contains(id)) {
            _setFailed(id, 'Téléchargement interrompu ($e)');
          }
        },
        onDone: () async {
          await sink.flush();
          await closeSink();
          if (total > 0 && downloaded < total) {
            _setFailed(id, 'Téléchargement incomplet');
          } else {
            _update(id,
                status: DownloadStatus.completed,
                downloadedBytes: downloaded,
                totalBytes: total);
          }
        },
        cancelOnError: true,
      );
      _subscriptions[id] = subscription;
      await subscription.asFuture<void>();
    } catch (_) {
      // Annulation (pause / suppression) : les flags décident du statut.
    } finally {
      await closeSink();
      _subscriptions.remove(id);
    }
  }

  Future<void> _retry(String id) async {
    final record = _find(id);
    if (record == null || record.status != DownloadStatus.failed) return;
    final file = File(record.filePath);
    if (await file.exists()) await file.delete();
    _update(id,
        status: DownloadStatus.downloading,
        downloadedBytes: 0,
        totalBytes: 0,
        clearError: true);
    unawaited(_runDownload(id));
  }

  // ---------------------------------------------------------------------------
  // État interne, persistance, émission
  // ---------------------------------------------------------------------------

  _Record? _find(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  String _downloadId(String mediaId, String quality, Episode? episode) =>
      'dl-$mediaId-${episode == null ? 'film' : 's${episode.seasonNumber ?? 1}e${episode.number}'}-$quality';

  Future<Directory> _downloadsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileNameFromUrl(String url) {
    final name = url.split('/').last.split('?').first;
    final decoded = name.isEmpty ? 'video' : Uri.decodeComponent(name);
    return decoded.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  String _buildFileName(String mediaId, String title, String quality,
      Episode? episode, StreamSource source) {
    final clean = title
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ _.\-]'), '_')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final base = clean.isEmpty ? 'video' : clean;
    final short = base.length > 50 ? base.substring(0, 50) : base;
    final safeId = mediaId.replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '_');
    final episodePart =
        episode == null ? '' : '_s${episode.seasonNumber ?? 1}e${episode.number}';
    final ext = source.format.isNotEmpty ? source.format : 'mp4';
    return '${safeId}_${quality}$episodePart\_$short.$ext';
  }

  void _update(String id,
      {DownloadStatus? status,
      int? downloadedBytes,
      int? totalBytes,
      bool clearError = false}) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _records[index] = _records[index].copyWith(
      status: status,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      errorMessage: clearError ? null : _records[index].errorMessage,
    );
    _emit(force: status != null);
  }

  void _updateProgress(String id, int downloaded, int total) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _records[index] = _records[index].copyWith(
      downloadedBytes: downloaded,
      totalBytes: total,
    );
    _emit();
  }

  void _setFailed(String id, String message) {
    _update(id, status: DownloadStatus.failed);
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      _records[index] =
          _records[index].copyWith(errorMessage: message);
      _emit(force: true);
    }
  }

  void _emit({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastEmit).inMilliseconds < 300) return;
    _lastEmit = now;
    if (!_controller.isClosed) {
      _controller.add(_records.map((r) => r.toDownloadItem()).toList());
    }
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }
}

/// Enregistrement interne d'un téléchargement (persisté en JSON).
class _Record {
  const _Record({
    required this.id,
    required this.mediaId,
    required this.title,
    this.episodeLabel,
    required this.quality,
    required this.url,
    required this.fileName,
    required this.filePath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String mediaId;
  final String title;
  final String? episodeLabel;
  final String quality;
  final String url;
  final String fileName;
  final String filePath;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  DownloadItem toDownloadItem() {
    return DownloadItem(
      id: id,
      title: title,
      episodeLabel: episodeLabel,
      qualityLabel: quality,
      progress: progress,
      status: status,
      sizeLabel: totalBytes > 0
          ? formatBytes(totalBytes)
          : (downloadedBytes > 0 ? formatBytes(downloadedBytes) : '—'),
    );
  }

  _Record copyWith({
    DownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return _Record(
      id: id,
      mediaId: mediaId,
      title: title,
      episodeLabel: episodeLabel,
      quality: quality,
      url: url,
      fileName: fileName,
      filePath: filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'episodeLabel': episodeLabel,
        'quality': quality,
        'url': url,
        'fileName': fileName,
        'filePath': filePath,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'status': status.name,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _Record.fromJson(Map<String, dynamic> json) {
    DownloadStatus statusFrom(String? value) {
      switch (value) {
        case 'downloading':
          return DownloadStatus.downloading;
        case 'paused':
          return DownloadStatus.paused;
        case 'completed':
          return DownloadStatus.completed;
        case 'failed':
          return DownloadStatus.failed;
        case 'queued':
        default:
          return DownloadStatus.queued;
      }
    }

    return _Record(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      title: json['title'] as String? ?? 'Vidéo',
      episodeLabel: json['episodeLabel'] as String?,
      quality: json['quality'] as String? ?? 'Source',
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'video.mp4',
      filePath: json['filePath'] as String? ?? '',
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: statusFrom(json['status'] as String?),
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

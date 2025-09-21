// lib/data/datasources/remote/google_drive_service.dart
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

/// Modello per rappresentare un file di Google Drive
class DriveFile {
  final String id;
  final String name;
  final String? mimeType;
  final DateTime? modifiedTime;
  final String? size;
  final String? webViewLink;
  final String? webContentLink;
  final String? iconLink;
  final bool isFolder;
  final List<String>? parents;
  final String? description;
  
  DriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.modifiedTime,
    this.size,
    this.webViewLink,
    this.webContentLink,
    this.iconLink,
    this.isFolder = false,
    this.parents,
    this.description,
  });
  
  /// Crea da Google Drive File
  factory DriveFile.fromGoogleFile(drive.File file) {
    return DriveFile(
      id: file.id ?? '',
      name: file.name ?? 'Senza nome',
      mimeType: file.mimeType,
      modifiedTime: file.modifiedTime,
      size: _formatFileSize(file.size),
      webViewLink: file.webViewLink,
      webContentLink: file.webContentLink,
      iconLink: file.iconLink,
      isFolder: file.mimeType == 'application/vnd.google-apps.folder',
      parents: file.parents,
      description: file.description,
    );
  }
  
  /// Ottieni un'icona appropriata per il tipo di file
  String get fileTypeIcon {
    if (isFolder) return '📁';
    
    switch (mimeType) {
      // Google Workspace
      case 'application/vnd.google-apps.document':
        return '📝';
      case 'application/vnd.google-apps.spreadsheet':
        return '📊';
      case 'application/vnd.google-apps.presentation':
        return '📰';
      case 'application/vnd.google-apps.form':
        return '📋';
      
      // Microsoft Office
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      case 'application/msword':
        return '📄';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      case 'application/vnd.ms-excel':
        return '📊';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      case 'application/vnd.ms-powerpoint':
        return '📊';
      
      // Immagini
      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
      case 'image/webp':
        return '🖼️';
      
      // PDF
      case 'application/pdf':
        return '📕';
        
      // Video
      case 'video/mp4':
      case 'video/quicktime':
      case 'video/x-msvideo':
        return '🎬';
        
      // Audio
      case 'audio/mpeg':
      case 'audio/wav':
      case 'audio/ogg':
        return '🎵';
        
      // Archivi
      case 'application/zip':
      case 'application/x-rar-compressed':
      case 'application/x-7z-compressed':
        return '🗜️';
        
      default:
        return '📎';
    }
  }
  
  /// Ottieni una descrizione leggibile del tipo di file
  String get fileTypeDescription {
    if (isFolder) return 'Cartella';
    
    switch (mimeType) {
      case 'application/vnd.google-apps.document':
        return 'Google Docs';
      case 'application/vnd.google-apps.spreadsheet':
        return 'Google Sheets';
      case 'application/vnd.google-apps.presentation':
        return 'Google Slides';
      case 'application/vnd.google-apps.form':
        return 'Google Forms';
      case 'application/pdf':
        return 'PDF';
      default:
        return mimeType?.split('/').last.toUpperCase() ?? 'File';
    }
  }
  
  static String _formatFileSize(String? sizeStr) {
    if (sizeStr == null) return '';
    
    try {
      final bytes = int.parse(sizeStr);
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } catch (e) {
      return '';
    }
  }
}

/// Servizio per interagire con Google Drive
class GoogleDriveService {
  // Singleton pattern
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();
  
  // Drive API instance
  drive.DriveApi? _driveApi;
  final GoogleAuthService _authService = GoogleAuthService();
  
  /// Inizializza il servizio Drive
  Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Inizializzazione Google Drive Service...');
      }
      
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Client non autenticato');
      }
      
      _driveApi = drive.DriveApi(client);
      
      if (kDebugMode) {
        print('✅ Google Drive Service inizializzato');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore inizializzazione Drive Service: $e');
      }
      rethrow;
    }
  }
  
  /// Cerca file in Google Drive
  Future<List<DriveFile>> searchFiles({
    String? query,
    String? folderId,
    int maxResults = 50,
    String? mimeType,
    bool onlyFolders = false,
  }) async {
    try {
      await _ensureInitialized();
      
      if (kDebugMode) {
        print('🔍 Ricerca in Google Drive: "$query"');
      }
      
      // Costruisci la query per l'API
      final queryParts = <String>[];
      
      // Escludi file nel cestino
      queryParts.add('trashed = false');
      
      // Ricerca per nome
      if (query != null && query.isNotEmpty) {
        queryParts.add("name contains '${query.replaceAll("'", "\\'")}'");
      }
      
      // Filtra per cartella parent
      if (folderId != null && folderId.isNotEmpty) {
        queryParts.add("'$folderId' in parents");
      }
      
      // Filtra per tipo MIME
      if (mimeType != null) {
        queryParts.add("mimeType = '$mimeType'");
      }
      
      // Solo cartelle
      if (onlyFolders) {
        queryParts.add("mimeType = 'application/vnd.google-apps.folder'");
      }
      
      final searchQuery = queryParts.join(' and ');
      
      if (kDebugMode) {
        print('📝 Query Drive API: $searchQuery');
      }
      
      // Esegui la ricerca
      final fileList = await _driveApi!.files.list(
        q: searchQuery,
        pageSize: maxResults,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description)',
      );
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        if (kDebugMode) {
          print('📭 Nessun file trovato');
        }
        return [];
      }
      
      final results = fileList.files!
          .map((f) => DriveFile.fromGoogleFile(f))
          .toList();
      
      if (kDebugMode) {
        print('✅ Trovati ${results.length} file');
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ricerca Drive: $e');
      }
      rethrow;
    }
  }
  
  /// Lista i file in una cartella specifica (o root)
  Future<List<DriveFile>> listFiles({
    String? folderId,
    int maxResults = 50,
  }) async {
    return searchFiles(
      folderId: folderId ?? 'root',
      maxResults: maxResults,
    );
  }
  
  /// Ottieni i file recenti
  Future<List<DriveFile>> getRecentFiles({int maxResults = 20}) async {
    try {
      await _ensureInitialized();
      
      if (kDebugMode) {
        print('📅 Recupero file recenti...');
      }
      
      final fileList = await _driveApi!.files.list(
        q: 'trashed = false',
        pageSize: maxResults,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description)',
      );
      
      if (fileList.files == null) return [];
      
      return fileList.files!
          .map((f) => DriveFile.fromGoogleFile(f))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore recupero file recenti: $e');
      }
      rethrow;
    }
  }
  
  /// Ottieni i dettagli di un file specifico
  Future<DriveFile?> getFile(String fileId) async {
    try {
      await _ensureInitialized();
      
      if (kDebugMode) {
        print('📄 Recupero dettagli file: $fileId');
      }
      
      final file = await _driveApi!.files.get(
        fileId,
        $fields: 'id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description',
      ) as drive.File;
      
      return DriveFile.fromGoogleFile(file);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore recupero file: $e');
      }
      return null;
    }
  }
  
  /// Scarica il contenuto di un file (solo per file non Google Workspace)
  Future<List<int>?> downloadFile(String fileId) async {
    try {
      await _ensureInitialized();
      
      if (kDebugMode) {
        print('⬇️ Download file: $fileId');
      }
      
      // Prima ottieni info sul file per verificare il tipo
      final fileInfo = await getFile(fileId);
      if (fileInfo == null) {
        throw Exception('File non trovato');
      }
      
      // I file Google Workspace devono essere esportati
      if (fileInfo.mimeType?.startsWith('application/vnd.google-apps') ?? false) {
        return await exportGoogleFile(fileId, fileInfo.mimeType!);
      }
      
      // Download normale per altri file
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
      
      if (kDebugMode) {
        print('✅ File scaricato: ${bytes.length} bytes');
      }
      
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore download file: $e');
      }
      return null;
    }
  }
  
  /// Esporta un file Google Workspace in un formato compatibile
  Future<List<int>?> exportGoogleFile(String fileId, String mimeType) async {
    try {
      await _ensureInitialized();
      
      // Determina il formato di export appropriato
      String exportMimeType;
      switch (mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'application/pdf';
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'application/pdf';
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'application/pdf';
          break;
        default:
          throw Exception('Tipo di file non esportabile: $mimeType');
      }
      
      if (kDebugMode) {
        print('📤 Export file Google: $fileId come $exportMimeType');
      }
      
      final response = await _driveApi!.files.export(
        fileId,
        exportMimeType,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
      
      if (kDebugMode) {
        print('✅ File esportato: ${bytes.length} bytes');
      }
      
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore export file: $e');
      }
      return null;
    }
  }
  
  /// Verifica che il servizio sia inizializzato
  Future<void> _ensureInitialized() async {
    if (_driveApi == null) {
      await initialize();
      if (_driveApi == null) {
        throw Exception('Google Drive Service non inizializzato');
      }
    }
  }
  
  /// Ottieni informazioni sullo spazio di archiviazione
  Future<Map<String, dynamic>?> getStorageInfo() async {
    try {
      await _ensureInitialized();
      
      final about = await _driveApi!.about.get(
        $fields: 'storageQuota',
      );
      
      if (about.storageQuota == null) return null;
      
      final quota = about.storageQuota!;
      return {
        'limit': quota.limit,
        'usage': quota.usage,
        'usageInDrive': quota.usageInDrive,
        'usageInTrash': quota.usageInDriveTrash,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore recupero info storage: $e');
      }
      return null;
    }
  }
}
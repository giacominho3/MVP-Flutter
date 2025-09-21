// lib/data/datasources/remote/google_drive_content_extractor.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'google_drive_service.dart';

/// Classe per estrarre il contenuto testuale dai file di Google Drive
class GoogleDriveContentExtractor {
  final GoogleDriveService _driveService = GoogleDriveService();
  
  /// Limiti per evitare di scaricare file troppo grandi
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxTextLength = 50000; // Max caratteri di testo
  
  /// Estrae il contenuto testuale da un file Drive
  Future<String> extractContent(DriveFile file) async {
    try {
      if (kDebugMode) {
        print('📄 Estrazione contenuto da: ${file.name}');
      }
      
      // Per file Google Workspace, usa l'export
      if (file.mimeType?.startsWith('application/vnd.google-apps') ?? false) {
        return await _extractGoogleWorkspaceContent(file);
      }
      
      // Per altri file, verifica il tipo
      switch (file.mimeType) {
        case 'text/plain':
        case 'text/csv':
        case 'text/html':
        case 'text/xml':
        case 'application/json':
          return await _extractTextContent(file);
          
        case 'application/pdf':
          // Per PDF, potresti usare una libreria di estrazione testo
          // Per ora ritorniamo solo il riferimento
          return '[Contenuto PDF: ${file.name} - Richiede elaborazione speciale]';
          
        case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        case 'application/msword':
          return '[Documento Word: ${file.name} - Richiede elaborazione speciale]';
          
        case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        case 'application/vnd.ms-excel':
          return '[Foglio Excel: ${file.name} - Richiede elaborazione speciale]';
          
        default:
          return '[File binario: ${file.name} - Tipo: ${file.mimeType}]';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore estrazione contenuto: $e');
      }
      return '[Errore nel caricamento del file: ${file.name}]';
    }
  }
  
  /// Estrae contenuto da file Google Workspace
  Future<String> _extractGoogleWorkspaceContent(DriveFile file) async {
    try {
      String exportMimeType;
      
      switch (file.mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'text/plain'; // Esporta come testo semplice
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'text/csv'; // Esporta come CSV
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'text/plain'; // Esporta come testo
          break;
        default:
          return '[Tipo Google Workspace non supportato: ${file.mimeType}]';
      }
      
      // Per ora ritorniamo solo il riferimento
      // In produzione, potresti implementare l'export effettivo
      return """
📄 ${file.name}
Tipo: ${file.fileTypeDescription}
Ultima modifica: ${file.modifiedTime}
ID: ${file.id}

[Contenuto del file Google Workspace - per accedere al contenuto completo, implementare l'export]
""";
    } catch (e) {
      return '[Errore export Google Workspace: ${e.toString()}]';
    }
  }
  
  /// Estrae contenuto da file di testo
  Future<String> _extractTextContent(DriveFile file) async {
    try {
      final bytes = await _driveService.downloadFile(file.id);
      if (bytes == null) {
        return '[File non trovato o non accessibile]';
      }
      
      // Controlla la dimensione
      if (bytes.length > maxFileSizeBytes) {
        return '[File troppo grande: ${file.size}. Solo i primi ${maxTextLength} caratteri inclusi]';
      }
      
      // Converti in testo
      String content = utf8.decode(bytes, allowMalformed: true);
      
      // Tronca se troppo lungo
      if (content.length > maxTextLength) {
        content = content.substring(0, maxTextLength) + '\n\n[... contenuto troncato ...]';
      }
      
      return """
📄 Contenuto di: ${file.name}
---
$content
---
Fine del file: ${file.name}
""";
    } catch (e) {
      return '[Errore lettura file: ${e.toString()}]';
    }
  }
  
  /// Estrae contenuto da multipli file
  Future<String> extractMultipleFiles(List<DriveFile> files) async {
    if (files.isEmpty) return '';
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('=== CONTESTO DAI FILE GOOGLE DRIVE ===\n');
    
    for (final file in files) {
      buffer.writeln('\n--- File ${files.indexOf(file) + 1}/${files.length} ---');
      
      // Per file grandi, includi solo il riferimento
      if (file.size != null && file.size!.contains('MB')) {
        final sizeInMB = double.tryParse(file.size!.replaceAll(' MB', '')) ?? 0;
        if (sizeInMB > 5) {
          buffer.writeln("""
📎 ${file.name}
Tipo: ${file.fileTypeDescription}
Dimensione: ${file.size}
[File troppo grande per essere incluso completamente nel contesto]
""");
          continue;
        }
      }
      
      // Estrai contenuto
      final content = await extractContent(file);
      buffer.writeln(content);
    }
    
    buffer.writeln('\n=== FINE CONTESTO ===');
    return buffer.toString();
  }
}
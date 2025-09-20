// lib/data/datasources/remote/claude_api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/message.dart';

class ClaudeApiService {
  static const String baseUrl = 'https://api.anthropic.com/v1';
  static const String apiVersion = '2023-06-01';
  static const String model = 'claude-3-haiku-20240307'; // Modello economico per MVP
  
  final Dio _dio;
  String? _apiKey;
  
  ClaudeApiService() : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers = {
      'anthropic-version': apiVersion,
      'content-type': 'application/json',
    };
    
    // Interceptor per debug
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint(object.toString()),
      ));
    }
  }
  
  /// Configura l'API key per le chiamate
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    _dio.options.headers['x-api-key'] = apiKey;
  }
  
  /// Invia un messaggio a Claude e riceve una risposta in streaming
  Stream<String> sendMessage({
    required String message,
    required List<Message> history,
    int maxTokens = 1024,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw ClaudeApiException('API key non configurata');
    }
    
    try {
      final messages = _buildMessagesHistory(history, message);
      
      final response = await _dio.post(
        '/messages',
        data: {
          'model': model,
          'max_tokens': maxTokens,
          'stream': true,
          'messages': messages,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );
      
      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
      
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // Mantieni l'ultima linea incompleta
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              return;
            }
            
            try {
              final json = jsonDecode(data);
              if (json['type'] == 'content_block_delta' && 
                  json['delta']?['type'] == 'text_delta') {
                yield json['delta']['text'] as String;
              }
            } catch (e) {
              // Ignora errori di parsing per chunk incompleti
              continue;
            }
          }
        }
      }
    } on DioException catch (e) {
      throw ClaudeApiException(_handleDioError(e));
    } catch (e) {
      throw ClaudeApiException('Errore imprevisto: $e');
    }
  }
  
  /// Invia un messaggio singolo senza streaming (per casi semplici)
  Future<String> sendSingleMessage({
    required String message,
    required List<Message> history,
    int maxTokens = 1024,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw ClaudeApiException('API key non configurata');
    }
    
    try {
      final messages = _buildMessagesHistory(history, message);
      
      final response = await _dio.post(
        '/messages',
        data: {
          'model': model,
          'max_tokens': maxTokens,
          'messages': messages,
        },
      );
      
      final content = response.data['content'] as List;
      return content.first['text'] as String;
    } on DioException catch (e) {
      throw ClaudeApiException(_handleDioError(e));
    } catch (e) {
      throw ClaudeApiException('Errore imprevisto: $e');
    }
  }
  
  /// Costruisce l'array di messaggi per l'API Claude
  List<Map<String, dynamic>> _buildMessagesHistory(List<Message> history, String newMessage) {
    final messages = <Map<String, dynamic>>[];
    
    // Aggiungi storico messaggi
    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    
    // Aggiungi nuovo messaggio utente
    messages.add({
      'role': 'user',
      'content': newMessage,
    });
    
    return messages;
  }
  
  /// Gestisce gli errori Dio e restituisce messaggi user-friendly
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Timeout della connessione. Riprova.';
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 401:
            return 'API key non valida. Controlla le impostazioni.';
          case 429:
            return 'Troppi tentativi. Riprova tra qualche minuto.';
          case 500:
          case 502:
          case 503:
            return 'Servizio temporaneamente non disponibile.';
          default:
            return 'Errore del server (${statusCode ?? 'sconosciuto'})';
        }
      
      case DioExceptionType.cancel:
        return 'Richiesta annullata';
      
      case DioExceptionType.connectionError:
        return 'Errore di connessione. Controlla la rete.';
      
      default:
        return 'Errore di rete: ${error.message}';
    }
  }
  
  /// Testa la connessione API con un messaggio semplice
  Future<bool> testConnection() async {
    try {
      await sendSingleMessage(
        message: 'Ciao!',
        history: [],
        maxTokens: 50,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Eccezione personalizzata per errori API Claude
class ClaudeApiException implements Exception {
  final String message;
  
  const ClaudeApiException(this.message);
  
  @override
  String toString() => 'ClaudeApiException: $message';
}
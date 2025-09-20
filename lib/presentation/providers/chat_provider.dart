// lib/presentation/providers/chat_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/storage_keys.dart';
import '../../data/datasources/remote/claude_api_service.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';

// Provider per il service API Claude
final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService();
});

// Provider per la sessione chat corrente
final currentChatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

// Provider per lo stato di invio messaggio
final messageStateProvider = StateNotifierProvider<MessageStateNotifier, MessageState>((ref) {
  return MessageStateNotifier();
});

// Provider per le impostazioni API
final apiSettingsProvider = StateNotifierProvider<ApiSettingsNotifier, ApiSettings>((ref) {
  return ApiSettingsNotifier();
});

class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;
  StreamSubscription<String>? _streamSubscription;
  
  ChatSessionNotifier(this._ref) : super(null);
  
  /// Crea una nuova sessione chat
  void createNewSession({String? title}) {
    final session = ChatSession.create(title: title);
    state = session;
  }
  
  /// Carica una sessione esistente
  void loadSession(ChatSession session) {
    state = session;
  }
  
  /// Invia un messaggio e gestisce la risposta streaming
  Future<void> sendMessage(String content) async {
    if (state == null) {
      createNewSession();
    }
    
    final messageNotifier = _ref.read(messageStateProvider.notifier);
    final apiService = _ref.read(claudeApiServiceProvider);
    final apiSettings = _ref.read(apiSettingsProvider);
    
    // Controlla se l'API key è configurata
    if (apiSettings.apiKey == null || apiSettings.apiKey!.isEmpty) {
      messageNotifier.setError('API key non configurata. Vai nelle impostazioni.');
      return;
    }
    
    try {
      // Imposta API key nel service
      apiService.setApiKey(apiSettings.apiKey!);
      
      // Crea messaggio utente
      final userMessage = Message.user(
        content: content,
        sessionId: state!.id,
      );
      
      // Aggiungi messaggio utente alla sessione
      state = state!.addMessage(userMessage);
      
      // Aggiorna titolo se è il primo messaggio
      if (state!.userMessageCount == 1) {
        state = state!.updateTitleFromMessages();
      }
      
      messageNotifier.setSending();
      
      // Crea messaggio vuoto per l'assistente
      final assistantMessage = Message.assistant(
        content: '',
        sessionId: state!.id,
      );
      state = state!.addMessage(assistantMessage);
      
      // Inizia streaming della risposta
      String fullResponse = '';
      final stream = apiService.sendMessage(
        message: content,
        history: state!.conversationMessages.where((m) => m.id != assistantMessage.id).toList(),
      );
      
      _streamSubscription?.cancel();
      _streamSubscription = stream.listen(
        (chunk) {
          fullResponse += chunk;
          state = state!.updateLastMessage(fullResponse);
        },
        onDone: () {
          messageNotifier.setIdle();
        },
        onError: (error) {
          state = state!.markLastMessageError();
          messageNotifier.setError(error.toString());
        },
      );
      
    } catch (e) {
      state = state!.markLastMessageError();
      messageNotifier.setError(e.toString());
    }
  }
  
  /// Cancella l'invio del messaggio corrente
  void cancelMessage() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _ref.read(messageStateProvider.notifier).setIdle();
  }
  
  /// Rimuove la sessione corrente
  void clearSession() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    state = null;
  }
  
  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

class MessageStateNotifier extends StateNotifier<MessageState> {
  MessageStateNotifier() : super(const MessageState.idle());
  
  void setSending() => state = const MessageState.sending();
  void setIdle() => state = const MessageState.idle();
  void setError(String message) => state = MessageState.error(message);
}

class ApiSettingsNotifier extends StateNotifier<ApiSettings> {
  static const _storage = FlutterSecureStorage();
  
  ApiSettingsNotifier() : super(const ApiSettings()) {
    _loadApiKey();
  }
  
  Future<void> _loadApiKey() async {
    try {
      final apiKey = await _storage.read(key: StorageKeys.claudeApiKey);
      if (apiKey != null && apiKey.isNotEmpty) {
        state = state.copyWith(apiKey: apiKey);
      }
    } catch (e) {
      // Ignora errori di caricamento
    }
  }
  
  Future<void> setApiKey(String apiKey) async {
    try {
      await _storage.write(key: StorageKeys.claudeApiKey, value: apiKey);
      state = state.copyWith(apiKey: apiKey);
    } catch (e) {
      // Gestisci errore
      throw Exception('Impossibile salvare l\'API key: $e');
    }
  }
  
  Future<void> clearApiKey() async {
    try {
      await _storage.delete(key: StorageKeys.claudeApiKey);
      state = state.copyWith(apiKey: null);
    } catch (e) {
      // Gestisci errore
      throw Exception('Impossibile rimuovere l\'API key: $e');
    }
  }
  
  Future<bool> testConnection() async {
    if (state.apiKey == null || state.apiKey!.isEmpty) {
      return false;
    }
    
    try {
      final apiService = ClaudeApiService();
      apiService.setApiKey(state.apiKey!);
      return await apiService.testConnection();
    } catch (e) {
      return false;
    }
  }
}

// Modelli per lo stato
sealed class MessageState {
  const MessageState();
  
  const factory MessageState.idle() = MessageStateIdle;
  const factory MessageState.sending() = MessageStateSending;
  const factory MessageState.error(String message) = MessageStateError;
}

class MessageStateIdle extends MessageState {
  const MessageStateIdle();
}

class MessageStateSending extends MessageState {
  const MessageStateSending();
}

class MessageStateError extends MessageState {
  final String message;
  const MessageStateError(this.message);
}

class ApiSettings {
  final String? apiKey;
  
  const ApiSettings({this.apiKey});
  
  ApiSettings copyWith({String? apiKey}) {
    return ApiSettings(apiKey: apiKey ?? this.apiKey);
  }
}
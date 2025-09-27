// lib/presentation/providers/chat_provider.dart
import 'dart:async';

import 'package:ai_assistant_mvp/data/datasources/remote/google_drive_content_extractor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';
import '../../data/datasources/remote/supabase_service.dart';
import 'google_drive_provider.dart';
import 'google_auth_provider.dart';
import '../../data/datasources/remote/claude_api_service.dart';

// Provider per lo stato di autenticazione principale - ora usa Google Auth
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AppAuthState>((ref) {
  return AuthStateNotifier(ref);
});

// Provider per la sessione chat corrente
final currentChatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

// Provider per lo stato di invio messaggio
final messageStateProvider = StateNotifierProvider<MessageStateNotifier, AppMessageState>((ref) {
  return MessageStateNotifier();
});

// Provider per le sessioni chat dell'utente (ora usando storage locale o Google Drive)
final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AppAuthStateAuthenticated) {
    return [];
  }
  
  try {
    // Carica le sessioni da Supabase
    return await SupabaseService.getChatSessions();
  } catch (e) {
    print('❌ Errore nel caricamento delle sessioni: $e');
    return [];
  }
});

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService();
});

class AuthStateNotifier extends StateNotifier<AppAuthState> {
  final Ref _ref;
  
  AuthStateNotifier(this._ref) : super(const AppAuthState.loading()) {
    _init();
  }
  
  void _init() {
    // Ascolta i cambiamenti dello stato di Google Auth
    _ref.listen(googleAuthStateProvider, (previous, next) {
      _updateAuthState(next);
    });
    
    // Imposta stato iniziale
    final googleAuthState = _ref.read(googleAuthStateProvider);
    _updateAuthState(googleAuthState);
  }
  
  void _updateAuthState(GoogleAuthState googleAuthState) {
    print('🔄 Updating auth state from GoogleAuthState: ${googleAuthState.runtimeType}');

    switch (googleAuthState) {
      case GoogleAuthInitial():
        print('📍 Setting AppAuthState to loading (GoogleAuthInitial)');
        state = const AppAuthState.loading();
        break;
      case GoogleAuthLoading():
        print('📍 Setting AppAuthState to loading (GoogleAuthLoading)');
        state = const AppAuthState.loading();
        break;
      case GoogleAuthAuthenticated(:final account, :final userInfo):
        print('✅ Setting AppAuthState to authenticated for user: ${account.email}');

        // Imposta il mock user ID per Supabase usando l'email Google
        try {
          SupabaseService.setMockUserId(account.email);
          print('✅ Supabase mock user ID set for: ${account.email}');
        } catch (e) {
          print('⚠️ Warning: Failed to set Supabase mock user ID: $e');
        }

        state = AppAuthState.authenticated(account, userInfo);
        break;
      case GoogleAuthUnauthenticated():
        print('❌ Setting AppAuthState to unauthenticated');
        state = const AppAuthState.unauthenticated();
        break;
      case GoogleAuthError(:final message):
        print('💥 Setting AppAuthState to error: $message');
        state = AppAuthState.error(message);
        break;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _ref.read(googleAuthStateProvider.notifier).signOut();
      state = const AppAuthState.unauthenticated();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }
}

class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;
  
  ChatSessionNotifier(this._ref) : super(null);
  
  Future<void> createNewSession({String? title}) async {
    final authState = _ref.read(authStateProvider);
    final googleAuthState = _ref.read(googleAuthStateProvider);

    print('🔍 Debug auth - AppAuthState: ${authState.runtimeType}');
    print('🔍 Debug auth - GoogleAuthState: ${googleAuthState.runtimeType}');

    if (authState is! AppAuthStateAuthenticated) {
      print('❌ User not authenticated - AppAuthState: $authState');
      print('❌ Google auth state: $googleAuthState');
      throw Exception('User not authenticated - AppAuthState: ${authState.runtimeType}, GoogleAuthState: ${googleAuthState.runtimeType}');
    }
    
    try {
      // Crea sessione su Supabase
      final session = await SupabaseService.createChatSession(title ?? 'Nuova Chat');
      state = session;

      print('✅ Sessione Supabase creata: ${session.id}');

      // Invalida la lista delle sessioni per aggiornare la UI
      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      print('❌ Errore nella creazione della chat: $e');
      _ref.read(messageStateProvider.notifier).setError('Errore nella creazione della chat: $e');
    }
  }

  Future<void> loadSession(ChatSession session) async {
    try {
      // Carica i messaggi da Supabase
      final messages = await SupabaseService.getMessages(session.id);

      // Crea una nuova sessione con i messaggi caricati
      final sessionWithMessages = session.copyWith(messages: messages);
      state = sessionWithMessages;

      print('✅ Sessione caricata con ${messages.length} messaggi');
    } catch (e) {
      print('❌ Errore nel caricamento dei messaggi: $e');
      _ref.read(messageStateProvider.notifier).setError('Errore nel caricamento dei messaggi: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final messageNotifier = _ref.read(messageStateProvider.notifier);
    
    try {
      messageNotifier.setSending();
      
      // Crea sessione se non esiste
      if (state == null) {
        await createNewSession(title: content.substring(0, content.length > 50 ? 50 : content.length));
      }
      
      // === Prepara il contesto dai file Google Drive ===
      final selectedDriveFiles = _ref.read(selectedDriveFilesProvider);
      String fileContext = '';
      
      if (selectedDriveFiles.isNotEmpty) {
        print('📎 Preparazione contesto da ${selectedDriveFiles.length} file...');
        
        final extractor = GoogleDriveContentExtractor();
        
        try {
          fileContext = await extractor.extractMultipleFiles(selectedDriveFiles);
        } catch (e) {
          // Fallback: usa solo i riferimenti se l'estrazione fallisce
          fileContext = '\n\n--- FILE DI RIFERIMENTO ---\n';
          for (final file in selectedDriveFiles) {
            fileContext += '📎 ${file.name} (${file.fileTypeDescription})\n';
          }
          fileContext += '--- FINE RIFERIMENTI ---\n\n';
        }
      }
      
      // Prepara il messaggio completo con contesto
      String fullMessage = content;
      if (fileContext.isNotEmpty) {
        fullMessage = """
$fileContext

DOMANDA UTENTE: $content

Istruzioni: Usa i file forniti come contesto per rispondere alla domanda. Se i file contengono informazioni rilevanti, citale nella risposta.
""";
        
        print('📝 Messaggio con contesto preparato (${fullMessage.length} caratteri)');
      }
      
      // Aggiungi il messaggio utente alla sessione
      final userMessage = Message.user(
        content: content, // Salva solo il messaggio originale nella UI
        sessionId: state!.id,
      );
      
      state = state!.addMessage(userMessage);
      
      // Crea messaggio assistente temporaneo con status "sending"
      final tempAssistantMessage = Message(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        sessionId: state!.id,
      );
      
      // Aggiungi messaggio assistente temporaneo
      state = state!.addMessage(tempAssistantMessage);
      
  // === CHIAMATA API CLAUDE REALE ===
      try {
        print('🤖 Invio messaggio a Claude...');
        
        // Prepara la history per Claude (escludi il messaggio temporaneo)
        final history = state!.messages
            .where((m) => m.id != tempAssistantMessage.id && m.status != MessageStatus.sending)
            .toList();
        
        // Ottieni il servizio Claude
        final claudeService = _ref.read(claudeApiServiceProvider);
        
        Map<String, dynamic> response;
        
        // Prima prova con Claude API diretta
        if (claudeService.hasApiKey) {
          print('✅ Uso Claude API diretta');
          response = await claudeService.sendMessage(
            message: fullMessage,
            history: history,
          );
        } else {
          // Fallback su Supabase Edge Function
          print('⚠️ Claude API key non trovata, uso Supabase Edge Function');
          response = await SupabaseService.sendToClaude(
            message: fullMessage,
            history: history,
            sessionId: state!.id,
          );
        }
        
        print('✅ Risposta ricevuta da Claude');
        
        // Rimuovi il messaggio temporaneo
        final messagesWithoutTemp = state!.messages
            .where((m) => m.id != tempAssistantMessage.id)
            .toList();
        
        // Crea il messaggio assistente finale con la risposta di Claude
        final assistantMessage = Message.assistant(
          content: response['content'] ?? 'Mi dispiace, non ho ricevuto una risposta valida.',
          sessionId: state!.id,
        );
        
        // Aggiorna lo stato con la risposta reale
        state = state!.copyWith(
          messages: [...messagesWithoutTemp, assistantMessage],
        );
        
        messageNotifier.setIdle();
        
        print('✅ Messaggio inviato e risposta Claude ricevuta');
        if (selectedDriveFiles.isNotEmpty) {
          print('📎 File nel contesto: ${selectedDriveFiles.map((f) => f.name).join(', ')}');
        }
        
        // Log dei token utilizzati se disponibili
        if (response['tokens_used'] != null) {
          print('🎯 Token utilizzati: ${response['tokens_used']}');
        }
        
      } catch (claudeError) {
        // Se Claude fallisce, rimuovi il messaggio temporaneo e mostra errore
        print('❌ Errore Claude API: $claudeError');
        
        final messagesWithoutTemp = state!.messages
            .where((m) => m.id != tempAssistantMessage.id)
            .toList();
        
        // Aggiungi un messaggio di errore
        final errorMessage = Message.system(
          content: 'Mi dispiace, si è verificato un errore nel contattare Claude. Errore: ${claudeError.toString()}',
          sessionId: state!.id,
        );
        
        state = state!.copyWith(
          messages: [...messagesWithoutTemp, errorMessage],
        );
        
        messageNotifier.setError('Errore Claude: ${claudeError.toString()}');
      }
    } catch (e) {
      messageNotifier.setError('Errore nell\'invio del messaggio: $e');
      print('❌ Errore generale: $e');
    }
  }

  Future<void> deleteCurrentSession() async {
    if (state == null) return;

    try {
      // Elimina la sessione da Supabase
      await SupabaseService.deleteChatSession(state!.id);
      state = null;

      print('✅ Sessione eliminata da Supabase');

      // Aggiorna la lista delle sessioni
      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      print('❌ Errore nell\'eliminazione della chat: $e');
      _ref.read(messageStateProvider.notifier).setError('Errore nell\'eliminazione della chat: $e');
    }
  }
  
  void clearSession() {
    state = null;
  }
}

class MessageStateNotifier extends StateNotifier<AppMessageState> {
  MessageStateNotifier() : super(const AppMessageState.idle());
  
  void setSending() => state = const AppMessageState.sending();
  void setIdle() => state = const AppMessageState.idle();
  void setError(String message) => state = AppMessageState.error(message);
}

// Stati per l'autenticazione - ora basati su Google Auth
sealed class AppAuthState {
  const AppAuthState();
  
  const factory AppAuthState.loading() = AppAuthStateLoading;
  const factory AppAuthState.authenticated(GoogleSignInAccount account, Map<String, String?> userInfo) = AppAuthStateAuthenticated;
  const factory AppAuthState.unauthenticated() = AppAuthStateUnauthenticated;
  const factory AppAuthState.error(String message) = AppAuthStateError;
}

class AppAuthStateLoading extends AppAuthState {
  const AppAuthStateLoading();
}

class AppAuthStateAuthenticated extends AppAuthState {
  final GoogleSignInAccount account;
  final Map<String, String?> userInfo;
  const AppAuthStateAuthenticated(this.account, this.userInfo);
}

class AppAuthStateUnauthenticated extends AppAuthState {
  const AppAuthStateUnauthenticated();
}

class AppAuthStateError extends AppAuthState {
  final String message;
  const AppAuthStateError(this.message);
}

// Stati per i messaggi (rimangono invariati)
sealed class AppMessageState {
  const AppMessageState();
  
  const factory AppMessageState.idle() = AppMessageStateIdle;
  const factory AppMessageState.sending() = AppMessageStateSending;
  const factory AppMessageState.error(String message) = AppMessageStateError;
}

class AppMessageStateIdle extends AppMessageState {
  const AppMessageStateIdle();
}

class AppMessageStateSending extends AppMessageState {
  const AppMessageStateSending();
}

class AppMessageStateError extends AppMessageState {
  final String message;
  const AppMessageStateError(this.message);
}
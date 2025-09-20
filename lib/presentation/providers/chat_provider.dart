// lib/presentation/providers/chat_provider.dart - VERSIONE CORRETTA
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/remote/supabase_service.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';

// Provider per lo stato di autenticazione
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AppAuthState>((ref) {
  return AuthStateNotifier();
});

// Provider per la sessione chat corrente
final currentChatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

// Provider per lo stato di invio messaggio
final messageStateProvider = StateNotifierProvider<MessageStateNotifier, AppMessageState>((ref) {
  return MessageStateNotifier();
});

// Provider per le sessioni chat dell'utente
final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AppAuthStateAuthenticated) {
    return [];
  }
  
  try {
    return await SupabaseService.getChatSessions();
  } catch (e) {
    throw Exception('Errore nel caricamento delle chat: $e');
  }
});

// Provider per l'usage dell'utente
final userUsageProvider = FutureProvider<Map<String, int>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AppAuthStateAuthenticated) {
    return {'messages': 0, 'tokens': 0, 'cost_cents': 0};
  }
  
  try {
    return await SupabaseService.getUserUsage();
  } catch (e) {
    return {'messages': 0, 'tokens': 0, 'cost_cents': 0};
  }
});

class AuthStateNotifier extends StateNotifier<AppAuthState> {
  AuthStateNotifier() : super(const AppAuthState.loading()) {
    _init();
  }
  
  void _init() {
    // Controlla se l'utente è già loggato
    final user = SupabaseService.currentUser;
    if (user != null) {
      state = AppAuthState.authenticated(user);
    } else {
      state = const AppAuthState.unauthenticated();
    }
    
    // Ascolta i cambiamenti di auth
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        state = AppAuthState.authenticated(user);
      } else {
        state = const AppAuthState.unauthenticated();
      }
    });
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      final response = await SupabaseService.signInWithEmail(email, password);
      if (response.user != null) {
        state = AppAuthState.authenticated(response.user!);
      } else {
        state = const AppAuthState.error('Login failed');
      }
    } catch (e) {
      String errorMessage = _parseError(e);
      state = AppAuthState.error(errorMessage);
    }
  }
  
  Future<void> signUp(String email, String password) async {
    state = const AppAuthState.loading();
    try {
      final response = await SupabaseService.signUp(email, password);
      if (response.user != null) {
        state = AppAuthState.authenticated(response.user!);
      } else {
        state = const AppAuthState.error('Registration failed');
      }
    } catch (e) {
      String errorMessage = _parseError(e);
      state = AppAuthState.error(errorMessage);
    }
  }

  // NUOVO: Metodo per modalità test
  void setTestMode() {
    final fakeUser = User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {'email': 'test@example.com'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'test@example.com',
    );
    
    state = AppAuthState.authenticated(fakeUser);
  }
  
  String _parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('connection failed') || errorStr.contains('network')) {
      return 'Problema di connessione. Controlla la tua connessione internet.';
    }
    if (errorStr.contains('certificate') || errorStr.contains('ssl') || errorStr.contains('tls')) {
      return 'Problema di sicurezza della connessione. Riprova.';
    }
    if (errorStr.contains('timeout')) {
      return 'Timeout della connessione. Riprova.';
    }
    if (errorStr.contains('invalid_credentials')) {
      return 'Email o password non corretti.';
    }
    if (errorStr.contains('email_not_confirmed')) {
      return 'Conferma la tua email prima di accedere.';
    }
    if (errorStr.contains('too_many_requests')) {
      return 'Troppi tentativi. Riprova tra qualche minuto.';
    }
    
    return 'Errore di connessione. Verifica la tua connessione internet e riprova.';
  }
 
  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
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
    if (authState is! AppAuthStateAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    try {
      final session = await SupabaseService.createChatSession(
        title ?? 'Nuova Chat ${_formatDate(DateTime.now())}',
      );
      
      // IMPORTANTE: Assicurati che state sia settato
      state = session;
      
      print('✅ Sessione creata: ${session.id}');
      
      // Aggiorna la lista delle sessioni
      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      print('❌ Errore nella creazione della chat: $e');
      _ref.read(messageStateProvider.notifier).setError('Errore nella creazione della chat: $e');
    }
  }

  /// Carica una sessione esistente con i suoi messaggi
  Future<void> loadSession(ChatSession session) async {
    try {
      final messages = await SupabaseService.getMessages(session.id);
      state = session.copyWith(messages: messages);
    } catch (e) {
      _ref.read(messageStateProvider.notifier).setError('Errore nel caricamento dei messaggi: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final messageNotifier = _ref.read(messageStateProvider.notifier);
    
    try {
      messageNotifier.setSending();
      
      // Crea sessione locale semplice se non esiste
      if (state == null) {
        state = ChatSession.create(title: 'Chat Locale');
        print('✅ Sessione locale creata: ${state!.id}');
      }
      
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
      
      // SIMULAZIONE: Crea risposta fake invece di chiamare Supabase
      await Future.delayed(const Duration(seconds: 1));
      
      final assistantMessage = Message.assistant(
        content: 'Questa è una risposta di test! Il sistema funziona correttamente. Hai scritto: "$content"',
        sessionId: state!.id,
      );
      
      // Aggiungi risposta alla sessione
      state = state!.addMessage(assistantMessage);
      
      messageNotifier.setIdle();
      
      print('✅ Messaggio inviato e risposta ricevuta');
      
    } catch (e) {
      print('❌ Errore nell\'invio: $e');
      if (state != null && state!.messages.isNotEmpty) {
        state = state!.markLastMessageError();
      }
      messageNotifier.setError('Errore nell\'invio: $e');
    }
  }

  /// Elimina la sessione corrente
  Future<void> deleteCurrentSession() async {
    if (state == null) return;
    
    try {
      await SupabaseService.deleteChatSession(state!.id);
      state = null;
      
      // Aggiorna la lista delle sessioni
      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      _ref.read(messageStateProvider.notifier).setError('Errore nell\'eliminazione della chat: $e');
    }
  }
  
  /// Rimuove la sessione corrente (solo locale)
  void clearSession() {
    state = null;
  }
  
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class MessageStateNotifier extends StateNotifier<AppMessageState> {
  MessageStateNotifier() : super(const AppMessageState.idle());
  
  void setSending() => state = const AppMessageState.sending();
  void setIdle() => state = const AppMessageState.idle();
  void setError(String message) => state = AppMessageState.error(message);
}

// Modelli per lo stato di autenticazione (rinominati per evitare conflitti)
sealed class AppAuthState {
  const AppAuthState();
  
  const factory AppAuthState.loading() = AppAuthStateLoading;
  const factory AppAuthState.authenticated(User user) = AppAuthStateAuthenticated;
  const factory AppAuthState.unauthenticated() = AppAuthStateUnauthenticated;
  const factory AppAuthState.error(String message) = AppAuthStateError;
}

class AppAuthStateLoading extends AppAuthState {
  const AppAuthStateLoading();
}

class AppAuthStateAuthenticated extends AppAuthState {
  final User user;
  const AppAuthStateAuthenticated(this.user);
}

class AppAuthStateUnauthenticated extends AppAuthState {
  const AppAuthStateUnauthenticated();
}

class AppAuthStateError extends AppAuthState {
  final String message;
  const AppAuthStateError(this.message);
}

// Modelli per lo stato dei messaggi (rinominati per coerenza)
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
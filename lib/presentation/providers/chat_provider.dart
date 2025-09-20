// lib/presentation/providers/chat_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/remote/supabase_service.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';

// Provider per lo stato di autenticazione
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});

// Provider per la sessione chat corrente
final currentChatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

// Provider per lo stato di invio messaggio
final messageStateProvider = StateNotifierProvider<MessageStateNotifier, MessageState>((ref) {
  return MessageStateNotifier();
});

// Provider per le sessioni chat dell'utente
final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthStateAuthenticated) {
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
  if (authState is! AuthStateAuthenticated) {
    return {'messages': 0, 'tokens': 0, 'cost_cents': 0};
  }
  
  try {
    return await SupabaseService.getUserUsage();
  } catch (e) {
    return {'messages': 0, 'tokens': 0, 'cost_cents': 0};
  }
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState.loading()) {
    _init();
  }
  
  void _init() {
    // Controlla se l'utente è già loggato
    final user = SupabaseService.currentUser;
    if (user != null) {
      state = AuthState.authenticated(user);
    } else {
      state = const AuthState.unauthenticated();
    }
    
    // Ascolta i cambiamenti di auth
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    });
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AuthState.loading();
    try {
      final response = await SupabaseService.signInWithEmail(email, password);
      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
      } else {
        state = const AuthState.error('Login failed');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
  
  Future<void> signUp(String email, String password) async {
    state = const AuthState.loading();
    try {
      final response = await SupabaseService.signUp(email, password);
      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
      } else {
        state = const AuthState.error('Registration failed');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
  
  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      state = const AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}

class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;
  
  ChatSessionNotifier(this._ref) : super(null);
  
  /// Crea una nuova sessione chat
  Future<void> createNewSession({String? title}) async {
    final authState = _ref.read(authStateProvider);
    if (authState is! AuthStateAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    try {
      final session = await SupabaseService.createChatSession(
        title ?? 'Nuova Chat ${_formatDate(DateTime.now())}',
      );
      state = session;
      
      // Aggiorna la lista delle sessioni
      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
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
  
  /// Invia un messaggio tramite Supabase Edge Function
  Future<void> sendMessage(String content) async {
    if (state == null) {
      await createNewSession();
    }
    
    final messageNotifier = _ref.read(messageStateProvider.notifier);
    
    try {
      // Controlla rate limiting
      final canSend = await SupabaseService.canSendMessage();
      if (!canSend) {
        messageNotifier.setError('Rate limit raggiunto. Massimo 100 messaggi all\'ora.');
        return;
      }
      
      messageNotifier.setSending();
      
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
      
      // Invia a Claude tramite Edge Function
      final response = await SupabaseService.sendToClaude(
        message: content,
        history: state!.conversationMessages.where((m) => m.id != userMessage.id).toList(),
        sessionId: state!.id,
      );
      
      // Crea messaggio assistente con la risposta
      final assistantMessage = Message.assistant(
        content: response['content'] as String,
        sessionId: state!.id,
      );
      
      // Aggiungi risposta alla sessione
      state = state!.addMessage(assistantMessage);
      
      messageNotifier.setIdle();
      
      // Aggiorna la lista delle sessioni
      _ref.invalidate(chatSessionsProvider);
      _ref.invalidate(userUsageProvider);
      
    } catch (e) {
      if (state!.messages.isNotEmpty) {
        state = state!.markLastMessageError();
      }
      messageNotifier.setError(e.toString());
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

class MessageStateNotifier extends StateNotifier<MessageState> {
  MessageStateNotifier() : super(const MessageState.idle());
  
  void setSending() => state = const MessageState.sending();
  void setIdle() => state = const MessageState.idle();
  void setError(String message) => state = MessageState.error(message);
}

// Modelli per lo stato di autenticazione
sealed class AuthState {
  const AuthState();
  
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.authenticated(User user) = AuthStateAuthenticated;
  const factory AuthState.unauthenticated() = AuthStateUnauthenticated;
  const factory AuthState.error(String message) = AuthStateError;
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateAuthenticated extends AuthState {
  final User user;
  const AuthStateAuthenticated(this.user);
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}

// Modelli per lo stato dei messaggi
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
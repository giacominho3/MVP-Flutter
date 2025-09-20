// lib/data/datasources/remote/supabase_service.dart - VERSIONE DEBUG
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chat_session.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Test di connessione semplice
  static Future<bool> testConnection() async {
    try {
      print('🔍 Testing Supabase connection...');
      
      // Test semplice - prova a fare una query base
      final response = await client
          .from('profiles') // Tabella che dovrebbe esistere
          .select('count')
          .limit(1);
      
      print('✅ Supabase connection test successful');
      return true;
    } catch (e) {
      print('❌ Supabase connection test failed: $e');
      return false;
    }
  }
  
  // Authentication
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      print('🔐 Attempting sign in for: $email');
      
      final response = await client.auth.signInWithPassword(
        email: email, 
        password: password,
      );
      
      print('✅ Sign in successful');
      return response;
    } catch (e) {
      print('❌ Sign in error: $e');
      rethrow;
    }
  }
  
  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      print('📝 Attempting sign up for: $email');
      
      final response = await client.auth.signUp(
        email: email, 
        password: password,
      );
      
      print('✅ Sign up successful');
      return response;
    } catch (e) {
      print('❌ Sign up error: $e');
      rethrow;
    }
  }
  
  static Future<void> signOut() {
    return client.auth.signOut();
  }
  
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  
  // Chat Sessions - versione semplificata per test
  static Future<List<ChatSession>> getChatSessions() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      // Per ora ritorna una lista vuota - implementeremo le tabelle dopo
      print('📋 Getting chat sessions (mockup for now)');
      return [];
    } catch (e) {
      print('❌ Error getting chat sessions: $e');
      return [];
    }
  }
  
  static Future<ChatSession> createChatSession(String title) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      // Per ora crea una sessione locale - implementeremo il salvataggio dopo
      print('➕ Creating chat session: $title');
      return ChatSession.create(title: title);
    } catch (e) {
      print('❌ Error creating chat session: $e');
      rethrow;
    }
  }
  
  static Future<void> deleteChatSession(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      print('🗑️ Deleting chat session: $sessionId');
      // Implementeremo dopo
    } catch (e) {
      print('❌ Error deleting chat session: $e');
      rethrow;
    }
  }
  
  // Messages - versione semplificata
  static Future<List<Message>> getMessages(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      print('💬 Getting messages for session: $sessionId');
      // Per ora ritorna lista vuota
      return [];
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }
  
  // Proxy per Claude API - versione di test
  static Future<Map<String, dynamic>> sendToClaude({
    required String message,
    required List<Message> history,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      print('🤖 Sending message to Claude (via Supabase)...');
      
      // Per ora simula una risposta - implementeremo la Edge Function dopo
      await Future.delayed(const Duration(seconds: 1));
      
      return {
        'content': 'Ciao! Questa è una risposta di test. Il sistema funziona correttamente!',
        'usage': {'tokens': 50},
      };
    } catch (e) {
      print('❌ Error sending to Claude: $e');
      rethrow;
    }
  }
  
  // Usage tracking - versione mockup
  static Future<Map<String, int>> getUserUsage() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      return {
        'messages': 5,
        'tokens': 250,
        'cost_cents': 10,
      };
    } catch (e) {
      print('❌ Error getting user usage: $e');
      return {
        'messages': 0,
        'tokens': 0,
        'cost_cents': 0,
      };
    }
  }
  
  static Future<bool> canSendMessage() async {
    try {
      final usage = await getUserUsage();
      return (usage['messages'] ?? 0) < 100;
    } catch (e) {
      return true;
    }
  }
  
  // Helper methods per convertire JSON -> Entities
  static ChatSession _chatSessionFromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: true,
    );
  }
  
  static Message _messageFromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      isUser: json['is_user'],
      timestamp: DateTime.parse(json['created_at']),
      status: MessageStatus.sent,
      sessionId: json['session_id'],
    );
  }
}

// Eccezione personalizzata per Supabase
class SupabaseException implements Exception {
  final String message;
  
  const SupabaseException(this.message);
  
  @override
  String toString() => 'SupabaseException: $message';
}
// lib/data/datasources/remote/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chat_session.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  
  // ============= AUTENTICAZIONE =============
  
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔐 Attempting sign in for: $email');
      }
      
      final response = await client.auth.signInWithPassword(
        email: email, 
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ Sign in successful');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign in error: $e');
      }
      rethrow;
    }
  }
  
  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      if (kDebugMode) {
        print('📝 Attempting sign up for: $email');
      }
      
      final response = await client.auth.signUp(
        email: email, 
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ Sign up successful');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign up error: $e');
      }
      rethrow;
    }
  }
  
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // ============= CHAT SESSIONS =============
  
  static Future<List<ChatSession>> getChatSessions() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      final response = await client
          .from('chat_sessions')
          .select()
          .eq('user_id', currentUser!.id)
          .order('updated_at', ascending: false);
      
      return (response as List).map((json) => ChatSession(
        id: json['id'],
        title: json['title'] ?? 'Chat senza titolo',
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting chat sessions: $e');
      }
      return [];
    }
  }
  
  static Future<ChatSession> createChatSession(String title) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      final response = await client
          .from('chat_sessions')
          .insert({
            'user_id': currentUser!.id,
            'title': title,
          })
          .select()
          .single();
      
      return ChatSession(
        id: response['id'],
        title: response['title'],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating chat session: $e');
      }
      rethrow;
    }
  }
  
  static Future<void> deleteChatSession(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      // Prima elimina i messaggi (cascata automatica se hai ON DELETE CASCADE)
      await client.from('messages').delete().eq('session_id', sessionId);
      
      // Poi elimina la sessione
      await client.from('chat_sessions').delete().eq('id', sessionId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting chat session: $e');
      }
      rethrow;
    }
  }
  
  // ============= MESSAGES =============
  
  static Future<List<Message>> getMessages(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at');
      
      return (response as List).map((json) => Message(
        id: json['id'],
        content: json['content'],
        isUser: json['is_user'] == true, // NOTA: il tuo DB usa is_user non role
        timestamp: DateTime.parse(json['created_at']),
        sessionId: sessionId,
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting messages: $e');
      }
      return [];
    }
  }
  
  // ============= CLAUDE CHAT - USA LA TUA EDGE FUNCTION! =============
  
  static Future<Map<String, dynamic>> sendToClaude({
    required String message,
    required List<Message> history,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      if (kDebugMode) {
        print('🤖 Sending message to Claude via edge function...');
        print('📝 Message: $message');
        print('🆔 Session: $sessionId');
      }
      
      // Prepara la history nel formato corretto per la tua edge function
      final formattedHistory = history.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList();
      
      // Chiama la TUA edge function claude-proxy
      final response = await client.functions.invoke(
        'claude-proxy', // Il nome della TUA edge function
        body: {
          'message': message,
          'session_id': sessionId, // NOTA: underscore come nella tua edge function
          'history': formattedHistory,
        },
      );
      
      if (kDebugMode) {
        print('📥 Edge function response: ${response.data}');
      }
      
      // Gestisci errori
      if (response.error != null) {
        throw Exception(response.error!);
      }
      
      // La tua edge function ritorna: {content, tokens_used, cost_cents}
      return {
        'content': response.data['content'] ?? '',
        'tokens_used': response.data['tokens_used'] ?? 0,
        'cost_cents': response.data['cost_cents'] ?? 0,
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending to Claude: $e');
      }
      rethrow;
    }
  }
  
  // ============= USAGE TRACKING =============
  
  static Future<Map<String, int>> getUserUsage() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      // Calcola uso nelle ultime 24 ore come fa la tua edge function
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      
      final response = await client
          .from('usage_logs')
          .select('tokens_used, cost_cents')
          .eq('user_id', currentUser!.id)
          .gte('created_at', oneDayAgo);
      
      int totalTokens = 0;
      int totalCost = 0;
      
      for (final log in response as List) {
        totalTokens += (log['tokens_used'] as int? ?? 0);
        totalCost += (log['cost_cents'] as int? ?? 0);
      }
      
      return {
        'messages': (response as List).length,
        'tokens': totalTokens,
        'cost_cents': totalCost,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user usage: $e');
      }
      return {
        'messages': 0,
        'tokens': 0,
        'cost_cents': 0,
      };
    }
  }
  
  // ============= TEST CONNECTION =============
  
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔍 Testing Supabase connection...');
      }
      
      // Prova a fare una query semplice
      await client.from('chat_sessions').select().limit(1);
      
      if (kDebugMode) {
        print('✅ Supabase connection OK');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Supabase connection failed: $e');
      }
      return false;
    }
  }
}
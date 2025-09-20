// lib/data/datasources/remote/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chat_session.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Authentication
  static Future<AuthResponse> signInWithEmail(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }
  
  static Future<AuthResponse> signUp(String email, String password) {
    return client.auth.signUp(email: email, password: password);
  }
  
  static Future<void> signOut() {
    return client.auth.signOut();
  }
  
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  
  // Chat Sessions
  static Future<List<ChatSession>> getChatSessions() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    final response = await client
        .from('chat_sessions')
        .select()
        .eq('user_id', currentUser!.id)
        .order('updated_at', ascending: false);
    
    return response.map<ChatSession>((json) => ChatSession.fromSupabase(json)).toList();
  }
  
  static Future<ChatSession> createChatSession(String title) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    final response = await client
        .from('chat_sessions')
        .insert({
          'user_id': currentUser!.id,
          'title': title,
        })
        .select()
        .single();
    
    return ChatSession.fromSupabase(response);
  }
  
  static Future<void> deleteChatSession(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await client
        .from('chat_sessions')
        .delete()
        .eq('id', sessionId)
        .eq('user_id', currentUser!.id);
  }
  
  // Messages
  static Future<List<Message>> getMessages(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    final response = await client
        .from('messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);
    
    return response.map<Message>((json) => Message.fromSupabase(json)).toList();
  }
  
  // Claude API Proxy via Edge Function
  static Future<Map<String, dynamic>> sendToClaude({
    required String message,
    required List<Message> history,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    final response = await client.functions.invoke('claude-proxy', body: {
      'message': message,
      'history': history.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList(),
      'session_id': sessionId,
    });
    
    if (response.status != 200) {
      final errorMessage = response.data is String 
          ? response.data 
          : response.data?.toString() ?? 'Unknown error';
      throw SupabaseException('API Error: $errorMessage');
    }
    
    return response.data;
  }
  
  // Usage tracking
  static Future<Map<String, int>> getUserUsage() async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      final response = await client
          .rpc('get_user_monthly_usage')
          .single();
      
      return {
        'messages': response['total_messages'] ?? 0,
        'tokens': response['total_tokens'] ?? 0,
        'cost_cents': response['total_cost_cents'] ?? 0,
      };
    } catch (e) {
      // Se la funzione non esiste o c'è un errore, ritorna valori di default
      return {
        'messages': 0,
        'tokens': 0,
        'cost_cents': 0,
      };
    }
  }
  
  // Utility per verificare rate limits
  static Future<bool> canSendMessage() async {
    try {
      final usage = await getUserUsage();
      return (usage['messages'] ?? 0) < 100; // 100 messaggi/ora
    } catch (e) {
      return true; // In caso di errore, permetti l'invio
    }
  }
}

// Estensioni per convertire da/verso Supabase
extension ChatSessionFromSupabase on ChatSession {
  static ChatSession fromSupabase(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: true,
    );
  }
}

extension MessageFromSupabase on Message {
  static Message fromSupabase(Map<String, dynamic> json) {
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
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
          .order('created_at', ascending: true); // IMPORTANTE: ascending true per ordine cronologico
      
      if (kDebugMode) {
        print('📚 Loaded ${(response as List).length} messages from database');
        for (var msg in response) {
          print('  - ${msg['is_user'] ? 'User' : 'Assistant'}: ${msg['content'].toString().substring(0, msg['content'].toString().length > 50 ? 50 : msg['content'].toString().length)}...');
        }
      }
      
      return (response as List).map((json) => Message(
        id: json['id'],
        content: json['content'],
        isUser: json['is_user'] == true,
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
  
  // ============= SALVA MESSAGGIO NEL DATABASE =============
  
  static Future<Message> saveMessage({
    required String content,
    required bool isUser,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      if (kDebugMode) {
        print('💾 Saving message to database...');
      }
      
      final response = await client
          .from('messages')
          .insert({
            'session_id': sessionId,
            'content': content,
            'is_user': isUser,
            // RIMOSSO user_id perché non esiste nella tabella messages
          })
          .select()
          .single();
      
      if (kDebugMode) {
        print('✅ Message saved: ${response['id']}');
      }
      
      // Aggiorna anche updated_at della sessione
      await client
          .from('chat_sessions')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', sessionId);
      
      return Message(
        id: response['id'],
        content: response['content'],
        isUser: response['is_user'] == true,
        timestamp: DateTime.parse(response['created_at']),
        sessionId: sessionId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving message: $e');
      }
      rethrow;
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
        print('📜 History length: ${history.length}');
      }
      
      // Prima salva il messaggio dell'utente nel database
      await saveMessage(
        content: message,
        isUser: true,
        sessionId: sessionId,
      );
      
      // Prepara la history nel formato corretto per la tua edge function
      final formattedHistory = history.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList();
      
      // Aggiungi il nuovo messaggio alla history
      formattedHistory.add({
        'role': 'user',
        'content': message,
      });
      
      if (kDebugMode) {
        print('📤 Calling edge function with history: $formattedHistory');
      }
      
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
        print('📥 Edge function raw response: ${response}');
        print('📥 Response status: ${response.status}');
        print('📥 Response data type: ${response.data.runtimeType}');
        print('📥 Response data: ${response.data}');
      }
      
      // CORREZIONE: Gestione errori migliorata
      if (response.data == null) {
        throw Exception('Nessuna risposta dalla edge function');
      }
      
      // Se la risposta contiene un errore
      if (response.data is Map && response.data['error'] != null) {
        if (kDebugMode) {
          print('❌ Edge function error: ${response.data['error']}');
        }
        throw Exception(response.data['error']);
      }
      
      // Se la risposta è una stringa di errore
      if (response.data is String) {
        // Potrebbe essere una risposta valida o un errore
        if (response.data.toString().toLowerCase().contains('error')) {
          throw Exception(response.data);
        }
        // Se è solo una stringa, assumiamo sia il contenuto della risposta
        final assistantContent = response.data.toString();
        
        // Salva la risposta dell'assistente nel database
        await saveMessage(
          content: assistantContent,
          isUser: false,
          sessionId: sessionId,
        );
        
        return {
          'content': assistantContent,
          'tokens_used': 0,
          'cost_cents': 0,
        };
      }
      
      // Se la risposta è un oggetto JSON completo
      if (response.data is Map) {
        final responseData = response.data as Map<String, dynamic>;
        
        if (kDebugMode) {
          print('📊 Parsed response data: $responseData');
        }
        
        final assistantContent = responseData['content'] ?? responseData['response'] ?? '';
        
        // Salva la risposta dell'assistente nel database
        if (assistantContent.isNotEmpty) {
          await saveMessage(
            content: assistantContent,
            isUser: false,
            sessionId: sessionId,
          );
        }
        
        // La tua edge function ritorna: {content, tokens_used, cost_cents}
        return {
          'content': assistantContent,
          'tokens_used': responseData['tokens_used'] ?? 0,
          'cost_cents': responseData['cost_cents'] ?? 0,
        };
      }
      
      // Fallback per altri casi
      throw Exception('Formato di risposta non riconosciuto: ${response.data.runtimeType}');
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error sending to Claude: $e');
        print('📚 Stack trace: $stackTrace');
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
  
  // ============= TEST EDGE FUNCTION =============
  
  static Future<void> testEdgeFunction() async {
    try {
      if (kDebugMode) {
        print('🧪 Testing edge function directly...');
      }
      
      final response = await client.functions.invoke(
        'claude-proxy',
        body: {
          'message': 'Test message',
          'session_id': 'test-session',
          'history': [],
        },
      );
      
      if (kDebugMode) {
        print('✅ Edge function test response: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Edge function test failed: $e');
      }
    }
  }
}
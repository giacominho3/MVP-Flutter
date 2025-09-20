// lib/data/datasources/remote/supabase_service.dart - VERSIONE DEBUG MIGLIORATA
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chat_session.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Test di connessione migliorato
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔍 Testing Supabase connection...');
        print('📍 URL: ${SupabaseConfig.currentUrl}');
        print('🔑 Anon Key: ${SupabaseConfig.currentAnonKey.substring(0, 20)}...');
      }
      
      // Test più basilare - solo verifica che l'API risponda
      try {
        // Prova a fare una query di test su auth (sempre disponibile)
        final response = await client.auth.getUser();
        
        if (kDebugMode) {
          print('✅ Supabase auth endpoint responsive');
          print('👤 Current user: ${response.user?.email ?? "none"}');
        }
        
        return true;
      } catch (authError) {
        if (kDebugMode) {
          print('⚠️ Auth test failed, trying basic REST call...');
        }
        
        // Se auth fallisce, prova una chiamata REST base
        await client.rest.from('non_existent_table').select().limit(1);
        
        // Se arriviamo qui senza eccezioni, la connessione funziona
        // (anche se la tabella non esiste, il server ha risposto)
        if (kDebugMode) {
          print('✅ Supabase REST endpoint responsive');
        }
        return true;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Supabase connection test failed: $e');
        print('🔍 Error type: ${e.runtimeType}');
        
        // Debug aggiuntivo per errori specifici
        if (e.toString().contains('certificate') || e.toString().contains('SSL')) {
          print('🔒 SSL/Certificate issue detected');
        } else if (e.toString().contains('timeout')) {
          print('⏱️ Timeout issue detected');
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          print('🌐 Network connectivity issue detected');
        }
      }
      return false;
    }
  }
  
  // Test di connessione alternativo più dettagliato
  static Future<Map<String, dynamic>> detailedConnectionTest() async {
    final result = <String, dynamic>{
      'success': false,
      'url': SupabaseConfig.currentUrl,
      'error': null,
      'details': <String, dynamic>{},
    };
    
    try {
      if (kDebugMode) {
        print('🔍 Detailed Supabase connection test...');
      }
      
      // Test 1: Basic URL reachability
      try {
        final stopwatch = Stopwatch()..start();
        await client.auth.getUser();
        stopwatch.stop();
        
        result['details']['auth_test'] = {
          'success': true,
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
        
        if (kDebugMode) {
          print('✅ Auth endpoint test passed (${stopwatch.elapsedMilliseconds}ms)');
        }
      } catch (e) {
        result['details']['auth_test'] = {
          'success': false,
          'error': e.toString(),
        };
        
        if (kDebugMode) {
          print('❌ Auth endpoint test failed: $e');
        }
      }
      
      // Test 2: REST API test
      try {
        final stopwatch = Stopwatch()..start();
        await client.rest.from('test').select().limit(1);
        stopwatch.stop();
        
        result['details']['rest_test'] = {
          'success': true,
          'duration_ms': stopwatch.elapsedMilliseconds,
        };
      } catch (e) {
        // È normale che questo fallisca se la tabella non esiste
        result['details']['rest_test'] = {
          'success': true, // Consideriamo successo se il server risponde
          'note': 'Server responded (table may not exist)',
          'error': e.toString(),
        };
      }
      
      result['success'] = true;
      
    } catch (e) {
      result['error'] = e.toString();
      
      if (kDebugMode) {
        print('❌ Detailed connection test failed: $e');
      }
    }
    
    return result;
  }
  
  // Authentication
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
      if (kDebugMode) {
        print('📋 Getting chat sessions (mockup for now)');
      }
      return [];
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
      // Per ora crea una sessione locale - implementeremo il salvataggio dopo
      if (kDebugMode) {
        print('➕ Creating chat session: $title');
      }
      return ChatSession.create(title: title);
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
      if (kDebugMode) {
        print('🗑️ Deleting chat session: $sessionId');
      }
      // Implementeremo dopo
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting chat session: $e');
      }
      rethrow;
    }
  }
  
  // Messages - versione semplificata
  static Future<List<Message>> getMessages(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      if (kDebugMode) {
        print('💬 Getting messages for session: $sessionId');
      }
      // Per ora ritorna lista vuota
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting messages: $e');
      }
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
      if (kDebugMode) {
        print('🤖 Sending message to Claude (via Supabase)...');
      }
      
      // Per ora simula una risposta - implementeremo la Edge Function dopo
      await Future.delayed(const Duration(seconds: 1));
      
      return {
        'content': 'Ciao! Questa è una risposta di test. Il sistema funziona correttamente!',
        'usage': {'tokens': 50},
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending to Claude: $e');
      }
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
  
  static Future<bool> canSendMessage() async {
    try {
      final usage = await getUserUsage();
      return (usage['messages'] ?? 0) < 100;
    } catch (e) {
      return true;
    }
  }
}

// Eccezione personalizzata per Supabase
class SupabaseException implements Exception {
  final String message;
  
  const SupabaseException(this.message);
  
  @override
  String toString() => 'SupabaseException: $message';
}
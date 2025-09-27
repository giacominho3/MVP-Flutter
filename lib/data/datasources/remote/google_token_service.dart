// lib/data/datasources/remote/google_token_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class GoogleTokenService {
  static final _dio = Dio();
  
  /// Ottieni il token Google dall'utente autenticato
  static Future<String?> getGoogleToken() async {
    try {
      if (kDebugMode) {
        print('🔑 Recupero Google token da Supabase...');
      }
      
      // Prima prova con la funzione SQL
      final response = await Supabase.instance.client
          .rpc('get_google_token');
      
      if (response != null && response['provider_token'] != null) {
        if (kDebugMode) {
          print('✅ Token recuperato dalla funzione SQL');
        }
        return response['provider_token'];
      }
      
      // Se non funziona, prova con la Edge Function
      if (kDebugMode) {
        print('🔄 Tentativo con Edge Function...');
      }
      
      // Chiama la tua Edge Function
      final edgeResponse = await Supabase.instance.client.functions.invoke(
        'google-drive-auth',  // Nome della funzione (senza URL completo)
        body: {},
      );
      
      if (kDebugMode) {
        print('📥 Risposta Edge Function: ${edgeResponse.data}');
      }
      
      if (edgeResponse.data != null) {
        // Controlla se c'è un errore
        if (edgeResponse.data['error'] != null) {
          if (kDebugMode) {
            print('⚠️ Errore dalla Edge Function: ${edgeResponse.data['error']}');
          }
          
          // Se richiede ri-autenticazione
          if (edgeResponse.data['requiresReauth'] == true) {
            if (kDebugMode) {
              print('🔄 Ri-autenticazione richiesta');
            }
            return null;
          }
        }
        
        // Se abbiamo il token
        if (edgeResponse.data['access_token'] != null) {
          if (kDebugMode) {
            print('✅ Token recuperato dalla Edge Function');
          }
          return edgeResponse.data['access_token'];
        }
      }
      
      // Se ancora non abbiamo il token, dobbiamo ri-autenticare
      if (kDebugMode) {
        print('⚠️ Nessun token trovato, ri-autenticazione necessaria');
      }
      
      // Trigger re-autenticazione con gli scope corretti
      await _triggerReauthWithDriveScopes();
      
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore recupero token: $e');
      }
      return null;
    }
  }
  
  /// Trigger ri-autenticazione con gli scope di Google Drive
  static Future<void> _triggerReauthWithDriveScopes() async {
    try {
      if (kDebugMode) {
        print('🔄 Triggering re-authentication with Drive scopes...');
      }
      
      // Logout corrente
      await Supabase.instance.client.auth.signOut();
      
      // Re-login con gli scope corretti
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        scopes: 'email profile https://www.googleapis.com/auth/drive.readonly',
        queryParams: {
          'access_type': 'offline',
          'prompt': 'consent', // Forza il consenso per ottenere il refresh token
        },
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ri-autenticazione: $e');
      }
    }
  }
}
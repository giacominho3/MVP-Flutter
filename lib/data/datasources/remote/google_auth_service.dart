// lib/data/datasources/remote/google_auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/google_config.dart';

class GoogleAuthService {
  // Singleton pattern
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();
  
  // Google Sign In instance
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentAccount;
  
  // Getters
  GoogleSignInAccount? get currentAccount => _currentAccount;
  bool get isSignedIn => _currentAccount != null;
  String? get userEmail => _currentAccount?.email;
  String? get userName => _currentAccount?.displayName;
  String? get userPhotoUrl => _currentAccount?.photoUrl;
  
  /// Inizializza il servizio Google Sign In
  Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Inizializzazione Google Sign In...');
      }
      
      // Configurazione diversa per Desktop vs Web
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.webClientId,
          scopes: GoogleConfig.scopes,
        );
      } else {
        // Per Desktop
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.desktopClientId,
          scopes: GoogleConfig.scopes,
          // Per desktop, Google gestisce automaticamente il flusso OAuth
        );
      }
      
      // Controlla se l'utente è già loggato
      await _checkExistingSignIn();
      
      if (kDebugMode) {
        print('✅ Google Sign In inizializzato');
        if (_currentAccount != null) {
          print('👤 Utente già connesso: ${_currentAccount!.email}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore inizializzazione Google Sign In: $e');
      }
      rethrow;
    }
  }
  
  /// Controlla se c'è già un login attivo
  Future<void> _checkExistingSignIn() async {
    try {
      // signInSilently tenta di riautenticare senza mostrare UI
      _currentAccount = await _googleSignIn?.signInSilently();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Nessun login esistente o token scaduto');
      }
    }
  }
  
  /// Effettua il login con Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (_googleSignIn == null) {
        throw Exception('Google Sign In non inizializzato. Chiama initialize() prima.');
      }
      
      if (kDebugMode) {
        print('🔐 Avvio processo di login Google...');
      }
      
      // Mostra la UI di Google per il login
      _currentAccount = await _googleSignIn!.signIn();
      
      if (_currentAccount != null) {
        if (kDebugMode) {
          print('✅ Login riuscito!');
          print('👤 Email: ${_currentAccount!.email}');
          print('👤 Nome: ${_currentAccount!.displayName}');
          print('🔑 ID: ${_currentAccount!.id}');
        }
        
        // Verifica che abbiamo tutti i permessi richiesti
        final granted = await _checkPermissions();
        if (!granted) {
          if (kDebugMode) {
            print('⚠️ Non tutti i permessi sono stati concessi');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ Login annullato dall\'utente');
        }
      }
      
      return _currentAccount;
    } catch (error) {
      if (kDebugMode) {
        print('❌ Errore durante il login: $error');
      }
      // Non rilanciare l'errore se l'utente ha solo annullato
      if (error.toString().contains('sign_in_canceled')) {
        return null;
      }
      rethrow;
    }
  }
  
  /// Effettua il logout
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🚪 Logout da Google...');
      }
      
      await _googleSignIn?.signOut();
      _currentAccount = null;
      
      if (kDebugMode) {
        print('✅ Logout completato');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore durante il logout: $e');
      }
      rethrow;
    }
  }
  
  /// Disconnetti completamente l'account (revoca i permessi)
  Future<void> disconnect() async {
    try {
      if (kDebugMode) {
        print('🔌 Disconnessione completa da Google...');
      }
      
      await _googleSignIn?.disconnect();
      _currentAccount = null;
      
      if (kDebugMode) {
        print('✅ Disconnessione completata');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore durante la disconnessione: $e');
      }
      rethrow;
    }
  }
  
  /// Ottieni gli header di autenticazione per le API Google
  Future<Map<String, String>?> getAuthHeaders() async {
    try {
      if (_currentAccount == null) {
        if (kDebugMode) {
          print('⚠️ Nessun account connesso');
        }
        return null;
      }
      
      final auth = await _currentAccount!.authentication;
      
      if (auth.accessToken == null) {
        if (kDebugMode) {
          print('⚠️ Access token non disponibile');
        }
        return null;
      }
      
      return {
        'Authorization': 'Bearer ${auth.accessToken}',
        'X-Goog-AuthUser': '0',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ottenendo auth headers: $e');
      }
      return null;
    }
  }
  
  /// Ottieni un client HTTP autenticato per le API Google
  Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      if (_googleSignIn == null || _currentAccount == null) {
        if (kDebugMode) {
          print('⚠️ Non autenticato con Google');
        }
        return null;
      }
      
      // Su Web, crea un client custom con token
      if (kIsWeb) {
        if (kDebugMode) {
          print('🌐 Creazione client autenticato per Web...');
        }
        
        // Ottieni il token di accesso
        final auth = await _currentAccount!.authentication;
        final accessToken = auth.accessToken;
        
        if (accessToken == null) {
          if (kDebugMode) {
            print('❌ Access token non disponibile');
          }
          return null;
        }
        
        if (kDebugMode) {
          print('🔑 Access token ottenuto: ${accessToken.substring(0, 20)}...');
        }
        
        // Crea un client HTTP con il token
        final client = _GoogleAuthClient(
          accessToken: accessToken,
          idToken: auth.idToken,
        );
        
        if (kDebugMode) {
          print('✅ Client Web creato con successo');
        }
        
        return client;
      } else {
        // Su Desktop usa l'estensione
        if (kDebugMode) {
          print('🖥️ Uso estensione per Desktop...');
        }
        
        final client = await _googleSignIn!.authenticatedClient();
        
        if (client == null) {
          if (kDebugMode) {
            print('⚠️ Impossibile ottenere client autenticato');
          }
          return null;
        }
        
        return client;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ottenendo client autenticato: $e');
      }
      return null;
    }
  }

  /// Verifica che tutti i permessi richiesti siano stati concessi
  Future<bool> _checkPermissions() async {
    try {
      if (_currentAccount == null) return false;
      
      // Google Sign In su desktop concede automaticamente gli scope richiesti
      // Su web potrebbe essere necessario verificarli
      
      final grantedScopes = await _googleSignIn?.requestScopes(GoogleConfig.scopes);
      
      if (kDebugMode) {
        print('📝 Permessi concessi: $grantedScopes');
      }
      
      return grantedScopes ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore verifica permessi: $e');
      }
      return false;
    }
  }
  
  /// Refresh del token se scaduto
  Future<bool> refreshToken() async {
    try {
      if (_googleSignIn == null) return false;
      
      if (kDebugMode) {
        print('🔄 Refresh del token...');
      }
      
      // signInSilently forza un refresh del token
      _currentAccount = await _googleSignIn!.signInSilently();
      
      if (_currentAccount != null) {
        if (kDebugMode) {
          print('✅ Token refreshato');
        }
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore refresh token: $e');
      }
      return false;
    }
  }
  
  /// Ottieni informazioni dettagliate sull'utente
  Map<String, String?> getUserInfo() {
    if (_currentAccount == null) {
      return {
        'email': null,
        'name': null,
        'id': null,
        'photoUrl': null,
      };
    }
    
    return {
      'email': _currentAccount!.email,
      'name': _currentAccount!.displayName,
      'id': _currentAccount!.id,
      'photoUrl': _currentAccount!.photoUrl,
    };
  }
}

class _GoogleAuthClient extends http.BaseClient implements auth.AuthClient {
  final String accessToken;
  final String? idToken;
  final http.Client _client = http.Client();
  
  _GoogleAuthClient({
    required this.accessToken,
    this.idToken,
  });
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Aggiungi l'header Authorization a ogni richiesta
    request.headers['Authorization'] = 'Bearer $accessToken';
    
    if (kDebugMode) {
      print('📤 Request: ${request.method} ${request.url}');
    }
    
    return _client.send(request);
  }
  
  @override
  void close() {
    _client.close();
  }
  
  @override
  Future<void> refreshCredentials() async {
    // Su Web, il refresh viene gestito automaticamente da Google Sign-In
    if (kDebugMode) {
      print('🔄 Refresh credentials richiesto');
    }
  }
  
  @override
  get credentials => auth.AccessCredentials(
    auth.AccessToken(
      'Bearer',
      accessToken,
      // Scadenza token - impostiamo 1 ora da ora (verrà refreshato automaticamente)
      DateTime.now().add(const Duration(hours: 1)).toUtc(),
    ),
    null, // refreshToken non disponibile su Web
    GoogleConfig.scopes,
  );
}
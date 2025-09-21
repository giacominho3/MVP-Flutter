// lib/presentation/providers/google_auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/remote/google_auth_service.dart';

// Provider per il servizio Google Auth (singleton)
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

// Provider per lo stato dell'autenticazione Google
final googleAuthStateProvider = StateNotifierProvider<GoogleAuthNotifier, GoogleAuthState>((ref) {
  final service = ref.watch(googleAuthServiceProvider);
  return GoogleAuthNotifier(service);
});

// Stati possibili dell'autenticazione Google
sealed class GoogleAuthState {
  const GoogleAuthState();
}

class GoogleAuthInitial extends GoogleAuthState {
  const GoogleAuthInitial();
}

class GoogleAuthLoading extends GoogleAuthState {
  const GoogleAuthLoading();
}

class GoogleAuthAuthenticated extends GoogleAuthState {
  final GoogleSignInAccount account;
  final Map<String, String?> userInfo;
  
  const GoogleAuthAuthenticated({
    required this.account,
    required this.userInfo,
  });
}

class GoogleAuthError extends GoogleAuthState {
  final String message;
  const GoogleAuthError(this.message);
}

class GoogleAuthUnauthenticated extends GoogleAuthState {
  const GoogleAuthUnauthenticated();
}

// Notifier per gestire lo stato
class GoogleAuthNotifier extends StateNotifier<GoogleAuthState> {
  final GoogleAuthService _service;
  
  GoogleAuthNotifier(this._service) : super(const GoogleAuthInitial()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      state = const GoogleAuthLoading();
      
      await _service.initialize();
      
      // Controlla se c'è già un utente loggato
      if (_service.isSignedIn && _service.currentAccount != null) {
        state = GoogleAuthAuthenticated(
          account: _service.currentAccount!,
          userInfo: _service.getUserInfo(),
        );
      } else {
        state = const GoogleAuthUnauthenticated();
      }
    } catch (e) {
      state = GoogleAuthError('Errore inizializzazione: $e');
    }
  }
  
  Future<void> signIn() async {
    try {
      state = const GoogleAuthLoading();
      
      final account = await _service.signIn();
      
      if (account != null) {
        state = GoogleAuthAuthenticated(
          account: account,
          userInfo: _service.getUserInfo(),
        );
      } else {
        // L'utente ha annullato
        state = const GoogleAuthUnauthenticated();
      }
    } catch (e) {
      state = GoogleAuthError(_parseError(e));
    }
  }
  
  Future<void> signOut() async {
    try {
      state = const GoogleAuthLoading();
      await _service.signOut();
      state = const GoogleAuthUnauthenticated();
    } catch (e) {
      state = GoogleAuthError('Errore durante il logout: $e');
    }
  }
  
  Future<void> disconnect() async {
    try {
      state = const GoogleAuthLoading();
      await _service.disconnect();
      state = const GoogleAuthUnauthenticated();
    } catch (e) {
      state = GoogleAuthError('Errore durante la disconnessione: $e');
    }
  }
  
  String _parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('sign_in_canceled')) {
      return 'Accesso annullato';
    }
    if (errorStr.contains('network_error')) {
      return 'Errore di rete. Controlla la connessione';
    }
    if (errorStr.contains('invalid_grant')) {
      return 'Token scaduto. Riprova';
    }
    
    return 'Errore: ${error.toString()}';
  }
}
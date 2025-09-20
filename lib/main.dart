import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/storage_keys.dart';
import 'core/constants/supabase_config.dart';

// Classe per bypassare verifiche SSL su desktop (solo per sviluppo)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // IN SVILUPPO: Accetta TUTTI i certificati
        if (kDebugMode) {
          print('🔓 Accepting ALL certificates in debug mode for host: $host');
          return true; // ACCETTA TUTTO IN DEBUG
        }
        return false;
      }
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // IMPORTANTE: Override SSL solo per desktop in debug mode
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    if (kDebugMode) {
      HttpOverrides.global = MyHttpOverrides();
      print('⚠️  SSL certificate verification relaxed for debug mode');
    }
  }
  
  try {
    print('🚀 Inizializzazione Supabase...');
      
  // Inizializza Supabase con configurazione base
  await Supabase.initialize(
    url: SupabaseConfig.currentUrl,
    anonKey: SupabaseConfig.currentAnonKey,
    debug: kDebugMode,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit, // CAMBIA da pkce a implicit
      autoRefreshToken: true,
    ),
  );
    
    print('✅ Supabase inizializzato con successo: ${SupabaseConfig.currentUrl}');

    final testAuth = await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@test.com',
      password: 'test123',
    ).catchError((e) {
      print('🔴 Test Auth fallito: $e');
      return AuthResponse(session: null, user: null);
    });
    print('🟢 Test Auth: ${testAuth.user != null ? 'OK' : 'FAILED'}');
    // FINE TEST DEBUG
        
    } catch (e) {
    print('❌ Errore nell\'inizializzazione di Supabase: $e');
    print('📝 Continuando in modalità offline...');
    // Continua comunque l'app in modalità offline
  }
  
  // Inizializza sqflite per desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('✅ SQLite inizializzato per desktop');
  }
  
  // Inizializza Hive per caching locale
  await _initializeHive();
  
  runApp(
    const ProviderScope(
      child: AIAssistantApp(),
    ),
  );
}

Future<void> _initializeHive() async {
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
    
    // Apri i box necessari
    await Hive.openBox(StorageKeys.cacheBox);
    await Hive.openBox(StorageKeys.settingsBox);
    
    print('✅ Hive inizializzato con successo');
  } catch (e) {
    print('❌ Errore nell\'inizializzazione di Hive: $e');
  }
}
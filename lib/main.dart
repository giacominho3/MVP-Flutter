import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Import condizionali per gestire le differenze tra web e desktop
import 'app.dart';
import 'core/constants/storage_keys.dart';

// Stub per le funzionalità desktop non disponibili su web
void _initializeDesktopFeatures() {
  // Questa funzione verrà sovrascritta su desktop
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NON usare Platform o dart:io direttamente!
  // Usa kIsWeb per verificare se siamo su web
  if (!kIsWeb) {
    // Solo per desktop, non per web
    _initializeDesktopFeatures();
  }
  
  // Inizializza Hive per caching locale
  await _initializeHive();
  
  print('✅ App inizializzata con successo');
  
  runApp(
    const ProviderScope(
      child: AIAssistantApp(),
    ),
  );
}

Future<void> _initializeHive() async {
  try {
    if (kIsWeb) {
      // Su web, Hive usa IndexedDB
      await Hive.initFlutter();
    } else {
      // Su desktop, usa path_provider
      await Hive.initFlutter();
    }
    
    // Apri i box necessari
    await Hive.openBox(StorageKeys.cacheBox);
    await Hive.openBox(StorageKeys.settingsBox);
    
    print('✅ Hive inizializzato con successo');
  } catch (e) {
    print('❌ Errore nell\'inizializzazione di Hive: $e');
  }
}
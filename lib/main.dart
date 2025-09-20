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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza Supabase PRIMA di tutto
  await Supabase.initialize(
    url: SupabaseConfig.currentUrl,
    anonKey: SupabaseConfig.currentAnonKey,
    debug: kDebugMode,
  );
  
  if (kDebugMode) {
    print('✅ Supabase inizializzato: ${SupabaseConfig.currentUrl}');
  }
  
  // Inizializza sqflite per desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
    
    if (kDebugMode) {
      print('✅ Hive inizializzato con successo');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Hive: $e');
    }
  }
}
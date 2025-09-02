import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/storage_keys.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  LocalDatabase._init();
  
  Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }
  
  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, StorageKeys.dbName);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
  
  Future<void> _createDB(Database db, int version) async {
    // Chat Sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT FALSE,
        context_summary TEXT
      )
    ''');
    
    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        token_count INTEGER,
        FOREIGN KEY (session_id) REFERENCES chat_sessions (id)
      )
    ''');
    
    // Files Index table
    await db.execute('''
      CREATE TABLE files_index (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_size INTEGER,
        category TEXT,
        last_modified DATETIME,
        last_scanned DATETIME DEFAULT CURRENT_TIMESTAMP,
        content_hash TEXT,
        metadata JSON
      )
    ''');
    
    // Pins table
    await db.execute('''
      CREATE TABLE pins (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK (type IN ('file', 'query', 'action', 'workspace')),
        label TEXT NOT NULL,
        data JSON NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_used DATETIME,
        usage_count INTEGER DEFAULT 0
      )
    ''');
    
    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // File Relationships table
    await db.execute('''
      CREATE TABLE file_relationships (
        id TEXT PRIMARY KEY,
        parent_file_id TEXT,
        child_file_id TEXT,
        relationship_type TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (parent_file_id) REFERENCES files_index (id),
        FOREIGN KEY (child_file_id) REFERENCES files_index (id)
      )
    ''');
    
    // Create indexes for performance
    await db.execute('CREATE INDEX idx_messages_session_id ON messages(session_id)');
    await db.execute('CREATE INDEX idx_messages_created_at ON messages(created_at)');
    await db.execute('CREATE INDEX idx_files_path ON files_index(file_path)');
    await db.execute('CREATE INDEX idx_files_type ON files_index(file_type)');
    await db.execute('CREATE INDEX idx_files_category ON files_index(category)');
    await db.execute('CREATE INDEX idx_pins_type ON pins(type)');
    await db.execute('CREATE INDEX idx_pins_active ON pins(is_active)');
  }
  
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations in future versions
    if (oldVersion < newVersion) {
      // Add migration logic here
    }
  }
  
  Future<void> init() async {
    await database;
  }
  
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
  
  // CRUD operations helpers
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }
  
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }
  
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
}
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';

/// Database helper managing SQLite connection, schema creation, and migrations.
class DatabaseHelper {
  final DatabaseFactory? databaseFactory;
  final String dbName;
  Database? _db;

  DatabaseHelper({
    this.databaseFactory,
    this.dbName = AppConstants.databaseName,
  });

  /// Returns the singleton opened database instance.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final customFactory = databaseFactory;
    final String path;

    if (customFactory != null) {
      if (dbName == inMemoryDatabasePath) {
        path = inMemoryDatabasePath;
      } else {
        final databasesPath = await customFactory.getDatabasesPath();
        path = p.join(databasesPath, dbName);
      }
      return customFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } else {
      if (dbName == inMemoryDatabasePath) {
        path = inMemoryDatabasePath;
      } else {
        final databasesPath = await getDatabasesPath();
        path = p.join(databasesPath, dbName);
      }
      return openDatabase(
        path,
        version: AppConstants.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Pending events queue table
    // eventId is UNIQUE UUID; sequence is sequential integer for FIFO ordering.
    batch.execute('''
      CREATE TABLE ${AppConstants.tablePendingEvents} (
        eventId TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sequence INTEGER NOT NULL,
        status TEXT NOT NULL,
        rejectionReason TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 2. Cached attendance records table
    batch.execute('''
      CREATE TABLE ${AppConstants.tableCachedAttendance} (
        date TEXT PRIMARY KEY,
        checkInJson TEXT,
        checkOutJson TEXT,
        status TEXT NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');

    // 3. Cached employee profile table
    batch.execute('''
      CREATE TABLE ${AppConstants.tableCachedEmployee} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        designation TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radiusMeters REAL NOT NULL,
        timezone TEXT NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');

    // 4. Cached leave balance table (single row)
    batch.execute('''
      CREATE TABLE ${AppConstants.tableCachedLeaveBalance} (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total INTEGER NOT NULL,
        used INTEGER NOT NULL,
        available INTEGER NOT NULL,
        casualTotal INTEGER NOT NULL,
        casualUsed INTEGER NOT NULL,
        casualAvailable INTEGER NOT NULL,
        sickTotal INTEGER NOT NULL,
        sickUsed INTEGER NOT NULL,
        sickAvailable INTEGER NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');

    // 5. Cached leave requests table
    batch.execute('''
      CREATE TABLE ${AppConstants.tableCachedLeaveRequests} (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        days INTEGER NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        cachedAt TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Schema versioning & future migration hook
  }

  /// Clears all cached and pending local data to reset the client state.
  Future<void> clearAllData() async {
    final db = await database;
    final batch = db.batch();
    batch.delete(AppConstants.tablePendingEvents);
    batch.delete(AppConstants.tableCachedAttendance);
    batch.delete(AppConstants.tableCachedEmployee);
    batch.delete(AppConstants.tableCachedLeaveBalance);
    batch.delete(AppConstants.tableCachedLeaveRequests);
    await batch.commit(noResult: true);
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

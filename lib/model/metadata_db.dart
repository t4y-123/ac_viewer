import 'dart:io';

import 'package:aves/model/image_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final MetadataDb metadataDb = MetadataDb._private();

class MetadataDb {
  Future<Database> _database;

  Future<String> get path async => join(await getDatabasesPath(), 'metadata.db');

  static const dateTakenTable = 'dateTaken';
  static const metadataTable = 'metadata';
  static const addressTable = 'address';
  static const favouriteTable = 'favourites';

  MetadataDb._private();

  Future<void> init() async {
    debugPrint('$runtimeType init');
    _database = openDatabase(
      await path,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE $dateTakenTable('
            'contentId INTEGER PRIMARY KEY'
            ', dateMillis INTEGER'
            ')');
        await db.execute('CREATE TABLE $metadataTable('
            'contentId INTEGER PRIMARY KEY'
            ', dateMillis INTEGER'
            ', isAnimated INTEGER'
            ', videoRotation INTEGER'
            ', xmpSubjects TEXT'
            ', xmpTitleDescription TEXT'
            ', latitude REAL'
            ', longitude REAL'
            ')');
        await db.execute('CREATE TABLE $addressTable('
            'contentId INTEGER PRIMARY KEY'
            ', addressLine TEXT'
            ', countryCode TEXT'
            ', countryName TEXT'
            ', adminArea TEXT'
            ', locality TEXT'
            ')');
        await db.execute('CREATE TABLE $favouriteTable('
            'contentId INTEGER PRIMARY KEY'
            ', path TEXT'
            ')');
      },
      version: 1,
    );
  }

  Future<int> dbFileSize() async {
    final file = File((await path));
    return await file.exists() ? file.length() : 0;
  }

  Future<void> reset() async {
    debugPrint('$runtimeType reset');
    await (await _database).close();
    await deleteDatabase(await path);
    await init();
  }

  // date taken

  Future<void> clearDates() async {
    final db = await _database;
    final count = await db.delete(dateTakenTable, where: '1');
    debugPrint('$runtimeType clearDates deleted $count entries');
  }

  Future<List<DateMetadata>> loadDates() async {
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final maps = await db.query(dateTakenTable);
    final metadataEntries = maps.map((map) => DateMetadata.fromMap(map)).toList();
//    debugPrint('$runtimeType loadDates complete in ${stopwatch.elapsed.inMilliseconds}ms for ${metadataEntries.length} entries');
    return metadataEntries;
  }

  // catalog metadata

  Future<void> clearMetadataEntries() async {
    final db = await _database;
    final count = await db.delete(metadataTable, where: '1');
    debugPrint('$runtimeType clearMetadataEntries deleted $count entries');
  }

  Future<List<CatalogMetadata>> loadMetadataEntries() async {
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final maps = await db.query(metadataTable);
    final metadataEntries = maps.map((map) => CatalogMetadata.fromMap(map, boolAsInteger: true)).toList();
//    debugPrint('$runtimeType loadMetadataEntries complete in ${stopwatch.elapsed.inMilliseconds}ms for ${metadataEntries.length} entries');
    return metadataEntries;
  }

  Future<void> saveMetadata(Iterable<CatalogMetadata> metadataEntries) async {
    if (metadataEntries == null || metadataEntries.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final batch = db.batch();
    metadataEntries.where((metadata) => metadata != null).forEach((metadata) => _batchInsertMetadata(batch, metadata));
    await batch.commit(noResult: true);
    debugPrint('$runtimeType saveMetadata complete in ${stopwatch.elapsed.inMilliseconds}ms for ${metadataEntries.length} entries');
  }

  Future<void> updateMetadataId(int oldId, CatalogMetadata metadata) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete(dateTakenTable, where: 'contentId = ?', whereArgs: [oldId]);
    batch.delete(metadataTable, where: 'contentId = ?', whereArgs: [oldId]);
    _batchInsertMetadata(batch, metadata);
    await batch.commit(noResult: true);
  }

  void _batchInsertMetadata(Batch batch, CatalogMetadata metadata) {
    if (metadata == null) return;
    if (metadata.dateMillis != 0) {
      batch.insert(
        dateTakenTable,
        DateMetadata(contentId: metadata.contentId, dateMillis: metadata.dateMillis).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.insert(
      metadataTable,
      metadata.toMap(boolAsInteger: true),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // address

  Future<void> clearAddresses() async {
    final db = await _database;
    final count = await db.delete(addressTable, where: '1');
    debugPrint('$runtimeType clearAddresses deleted $count entries');
  }

  Future<List<AddressDetails>> loadAddresses() async {
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final maps = await db.query(addressTable);
    final addresses = maps.map((map) => AddressDetails.fromMap(map)).toList();
//    debugPrint('$runtimeType loadAddresses complete in ${stopwatch.elapsed.inMilliseconds}ms for ${addresses.length} entries');
    return addresses;
  }

  Future<void> saveAddresses(Iterable<AddressDetails> addresses) async {
    if (addresses == null || addresses.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final batch = db.batch();
    addresses.where((address) => address != null).forEach((address) => _batchInsertAddress(batch, address));
    await batch.commit(noResult: true);
    debugPrint('$runtimeType saveAddresses complete in ${stopwatch.elapsed.inMilliseconds}ms for ${addresses.length} entries');
  }

  Future<void> updateAddressId(int oldId, AddressDetails address) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete(addressTable, where: 'contentId = ?', whereArgs: [oldId]);
    _batchInsertAddress(batch, address);
    await batch.commit(noResult: true);
  }

  void _batchInsertAddress(Batch batch, AddressDetails address) {
    if (address == null) return;
    batch.insert(
      addressTable,
      address.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // favourites

  Future<void> clearFavourites() async {
    final db = await _database;
    final count = await db.delete(favouriteTable, where: '1');
    debugPrint('$runtimeType clearFavourites deleted $count entries');
  }

  Future<List<FavouriteRow>> loadFavourites() async {
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final maps = await db.query(favouriteTable);
    final favouriteRows = maps.map((map) => FavouriteRow.fromMap(map)).toList();
//    debugPrint('$runtimeType loadFavourites complete in ${stopwatch.elapsed.inMilliseconds}ms for ${favouriteRows.length} entries');
    return favouriteRows;
  }

  Future<void> addFavourites(Iterable<FavouriteRow> favouriteRows) async {
    if (favouriteRows == null || favouriteRows.isEmpty) return;
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final batch = db.batch();
    favouriteRows.where((row) => row != null).forEach((row) => _batchInsertFavourite(batch, row));
    await batch.commit(noResult: true);
//    debugPrint('$runtimeType addFavourites complete in ${stopwatch.elapsed.inMilliseconds}ms for ${favouriteRows.length} entries');
  }

  Future<void> updateFavouriteId(int oldId, FavouriteRow row) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete(favouriteTable, where: 'contentId = ?', whereArgs: [oldId]);
    _batchInsertFavourite(batch, row);
    await batch.commit(noResult: true);
  }

  void _batchInsertFavourite(Batch batch, FavouriteRow row) {
    if (row == null) return;
    batch.insert(
      favouriteTable,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavourites(Iterable<FavouriteRow> favouriteRows) async {
    if (favouriteRows == null || favouriteRows.isEmpty) return;
    final ids = favouriteRows.where((row) => row != null).map((row) => row.contentId);
    if (ids.isEmpty) return;

    // using array in `whereArgs` and using it with `where contentId IN ?` is a pain, so we prefer `batch` instead
//    final stopwatch = Stopwatch()..start();
    final db = await _database;
    final batch = db.batch();
    ids.forEach((id) => batch.delete(favouriteTable, where: 'contentId = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
//    debugPrint('$runtimeType removeFavourites complete in ${stopwatch.elapsed.inMilliseconds}ms for ${favouriteRows.length} entries');
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../firebase_options.dart';

class SyncError {
  final String collection;
  final String operation;
  final dynamic error;

  SyncError({
    required this.collection,
    required this.operation,
    required this.error,
  });

  @override
  String toString() {
    if (error is FirebaseException) {
      final fe = error as FirebaseException;
      return "[$collection - $operation] ${fe.message} (${fe.code})";
    }
    return "[$collection - $operation] ${error.toString()}";
  }
}

class FirebaseService {
  static final StreamController<SyncError> _errorController = StreamController<SyncError>.broadcast();
  static Stream<SyncError> get errorStream => _errorController.stream;

  static void reportError(String collection, String operation, dynamic error) {
    final syncError = SyncError(collection: collection, operation: operation, error: error);
    debugPrint("Firestore Sync Error: $syncError");
    _errorController.add(syncError);
  }

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      // Enable offline persistence (disabled on web where it might throw)
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: !kIsWeb,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint("Failed to set Firestore settings: $e");
      try {
        FirebaseFirestore.instance.settings = const Settings(
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (_) {}
    }
  }

  static Future<bool> isOnline() async {
    if (kIsWeb) return true; // Browser handles network natively, bypass connectivity_plus check
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  static Future<T> executeWithRetryAndTimeout<T>(
    Future<T> Function() operation, {
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation().timeout(timeout);
      } on TimeoutException {
        if (attempt >= maxRetries) {
          throw Exception("Request timed out. Please check your connection.");
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } catch (error) {
        if (error.toString().contains("SocketException") || error.toString().contains("Unavailable")) {
          if (attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
            continue;
          }
        }
        rethrow;
      }
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTable(
    String collectionPath, {
    Map<String, dynamic>? filters,
  }) async {
    return executeWithRetryAndTimeout(() async {
      Query query = FirebaseFirestore.instance.collection(collectionPath);
      if (filters != null) {
        filters.forEach((key, value) {
          if (value is List) {
            query = query.where(key, whereIn: value);
          } else {
            query = query.where(key, isEqualTo: value);
          }
        });
      }
      
      try {
        final snapshot = await query.get(const GetOptions(source: Source.server));
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          return data;
        }).toList();
      } catch (serverError) {
        debugPrint("Server fetch failed for $collectionPath, falling back to cache: $serverError");
        final cacheSnapshot = await query.get(const GetOptions(source: Source.cache));
        return cacheSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          return data;
        }).toList();
      }
    }, timeout: const Duration(seconds: 4), maxRetries: 1);
  }

  static Future<Map<String, dynamic>?> insertRow(String collectionPath, Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? FirebaseFirestore.instance.collection(collectionPath).doc().id;
    final data = Map<String, dynamic>.from(row);
    data['id'] = id;

    unawaited(
      FirebaseFirestore.instance.collection(collectionPath).doc(id).set(data).catchError((error) {
        reportError(collectionPath, "insert", error);
      }),
    );
    return data;
  }

  static Future<void> upsertRow(String collectionPath, Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? FirebaseFirestore.instance.collection(collectionPath).doc().id;
    final data = Map<String, dynamic>.from(row);
    data['id'] = id;

    unawaited(
      FirebaseFirestore.instance.collection(collectionPath).doc(id).set(data, SetOptions(merge: true)).catchError((error) {
        reportError(collectionPath, "upsert", error);
      }),
    );
  }

  static Future<void> updateRow(
    String collectionPath,
    Map<String, dynamic> updates, {
    required Map<String, dynamic> filters,
  }) async {
    final docId = filters['id']?.toString();
    if (docId != null) {
      unawaited(
        FirebaseFirestore.instance.collection(collectionPath).doc(docId).update(updates).catchError((error) {
          reportError(collectionPath, "update ($docId)", error);
        }),
      );
    } else {
      unawaited(() async {
        try {
          Query query = FirebaseFirestore.instance.collection(collectionPath);
          filters.forEach((key, value) {
            query = query.where(key, isEqualTo: value);
          });
          final snapshot = await query.get();
          for (var doc in snapshot.docs) {
            doc.reference.update(updates).catchError((error) {
              reportError(collectionPath, "batch update (${doc.id})", error);
            });
          }
        } catch (e) {
          reportError(collectionPath, "batch update query", e);
        }
      }());
    }
  }

  static Future<void> deleteRow(String collectionPath, String keyField, dynamic key) async {
    if (keyField == 'id') {
      unawaited(
        FirebaseFirestore.instance.collection(collectionPath).doc(key.toString()).delete().catchError((error) {
          reportError(collectionPath, "delete ($key)", error);
        }),
      );
    } else {
      unawaited(() async {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collectionPath)
              .where(keyField, isEqualTo: key)
              .get();
          for (var doc in snapshot.docs) {
            doc.reference.delete().catchError((error) {
              reportError(collectionPath, "batch delete (${doc.id})", error);
            });
          }
        } catch (e) {
          reportError(collectionPath, "batch delete query", e);
        }
      }());
    }
  }
}


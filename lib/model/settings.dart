import 'package:aves/model/collection_lens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Settings settings = Settings._private();

typedef SettingsCallback = void Function(String key, dynamic oldValue, dynamic newValue);

class Settings {
  static SharedPreferences _prefs;

  final ObserverList<SettingsCallback> _listeners = ObserverList<SettingsCallback>();

  Settings._private();

  // preferences
  static const collectionGroupFactorKey = 'collection_group_factor';
  static const collectionSortFactorKey = 'collection_sort_factor';
  static const collectionTileExtentKey = 'collection_tile_extent';
  static const infoMapZoomKey = 'info_map_zoom';
  static const catalogTimeZoneKey = 'catalog_time_zone';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> reset() {
    return _prefs.clear();
  }

  void addListener(SettingsCallback listener) => _listeners.add(listener);

  void removeListener(SettingsCallback listener) => _listeners.remove(listener);

  void notifyListeners(String key, dynamic oldValue, dynamic newValue) {
    debugPrint('$runtimeType notifyListeners key=$key, old=$oldValue, new=$newValue');
    if (_listeners != null) {
      final localListeners = _listeners.toList();
      for (final listener in localListeners) {
        try {
          if (_listeners.contains(listener)) {
            listener(key, oldValue, newValue);
          }
        } catch (exception, stack) {
          debugPrint('$runtimeType failed to notify listeners with exception=$exception\n$stack');
        }
      }
    }
  }

  double get infoMapZoom => _prefs.getDouble(infoMapZoomKey) ?? 12;

  set infoMapZoom(double newValue) => setAndNotify(infoMapZoomKey, newValue);

  String get catalogTimeZone => _prefs.getString(catalogTimeZoneKey) ?? '';

  set catalogTimeZone(String newValue) => setAndNotify(catalogTimeZoneKey, newValue);

  GroupFactor get collectionGroupFactor => getEnumOrDefault(collectionGroupFactorKey, GroupFactor.month, GroupFactor.values);

  set collectionGroupFactor(GroupFactor newValue) => setAndNotify(collectionGroupFactorKey, newValue.toString());

  SortFactor get collectionSortFactor => getEnumOrDefault(collectionSortFactorKey, SortFactor.date, SortFactor.values);

  set collectionSortFactor(SortFactor newValue) => setAndNotify(collectionSortFactorKey, newValue.toString());

  double get collectionTileExtent => _prefs.getDouble(collectionTileExtentKey) ?? 0;

  set collectionTileExtent(double newValue) => setAndNotify(collectionTileExtentKey, newValue);

  // convenience methods

  bool getBoolOrDefault(String key, bool defaultValue) => _prefs.getKeys().contains(key) ? _prefs.getBool(key) : defaultValue;

  T getEnumOrDefault<T>(String key, T defaultValue, Iterable<T> values) {
    final valueString = _prefs.getString(key);
    for (final element in values) {
      if (element.toString() == valueString) {
        return element;
      }
    }
    return defaultValue;
  }

  List<T> getEnumListOrDefault<T>(String key, List<T> defaultValue, Iterable<T> values) {
    return _prefs.getStringList(key)?.map((s) => values.firstWhere((el) => el.toString() == s, orElse: () => null))?.where((el) => el != null)?.toList() ?? defaultValue;
  }

  void setAndNotify(String key, dynamic newValue) {
    var oldValue = _prefs.get(key);
    if (newValue == null) {
      _prefs.remove(key);
    } else if (newValue is String) {
      oldValue = _prefs.getString(key);
      _prefs.setString(key, newValue);
    } else if (newValue is List<String>) {
      oldValue = _prefs.getStringList(key);
      _prefs.setStringList(key, newValue);
    } else if (newValue is int) {
      oldValue = _prefs.getInt(key);
      _prefs.setInt(key, newValue);
    } else if (newValue is double) {
      oldValue = _prefs.getDouble(key);
      _prefs.setDouble(key, newValue);
    } else if (newValue is bool) {
      oldValue = _prefs.getBool(key);
      _prefs.setBool(key, newValue);
    }
    if (oldValue != newValue) {
      notifyListeners(key, oldValue, newValue);
    }
  }
}

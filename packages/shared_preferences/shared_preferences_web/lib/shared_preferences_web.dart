// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:web/web.dart' as html;

import 'src/keys_extension.dart';

/// The web implementation of [SharedPreferencesStorePlatform].
///
/// This class implements the `package:shared_preferences` functionality for the web.
class SharedPreferencesPlugin extends SharedPreferencesStorePlatform {
  /// Registers this class as the default instance of [SharedPreferencesStorePlatform].
  static void registerWith(Registrar? registrar) {
    SharedPreferencesStorePlatform.instance = SharedPreferencesPlugin();
  }

  static const String _defaultPrefix = 'flutter.';

  @override
  Future<bool> clear() async {
    return clearWithParameters(
      ClearParameters(
        filter: PreferencesFilter(prefix: _defaultPrefix),
      ),
    );
  }

  @override
  Future<bool> clearWithPrefix(String prefix) async {
    return clearWithParameters(
        ClearParameters(filter: PreferencesFilter(prefix: prefix)));
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final PreferencesFilter filter = parameters.filter;
    // IMPORTANT: Do not use html.window.localStorage.clear() as that will
    //            remove _all_ local data, not just the keys prefixed with
    //            _prefix
    _getFilteredKeys(filter.prefix, allowList: filter.allowList)
        .forEach(remove);
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    return getAllWithParameters(
      GetAllParameters(
        filter: PreferencesFilter(prefix: _defaultPrefix),
      ),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) async {
    return getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)));
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
      GetAllParameters parameters) async {
    final PreferencesFilter filter = parameters.filter;
    final Map<String, Object> allData = <String, Object>{};
    for (final String key
        in _getFilteredKeys(filter.prefix, allowList: filter.allowList)) {
      allData[key] = _decodeValue(html.window.localStorage.getItem(key)!);
    }
    return allData;
  }

  @override
  Future<bool> remove(String key) async {
    html.window.localStorage.removeItem(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object? value) async {
    html.window.localStorage.setItem(key, _encodeValue(value));
    return true;
  }

  Iterable<String> _getFilteredKeys(
    String prefix, {
    Set<String>? allowList,
  }) {
    return html.window.localStorage.keys.where((String key) =>
        key.startsWith(prefix) && (allowList?.contains(key) ?? true));
  }

  String _encodeValue(Object? value) {
    return json.encode(value);
  }


  Object _decodeValue(String encodedValue) {
    try {
      // Attempt to decode the string as JSON
      final Object? decodedValue = json.decode(encodedValue);
  
      if (decodedValue is List) {
        // JSON does not preserve generics. The encode/decode roundtrip results in
        // `List<String>` => JSON => `List<dynamic>`. Explicit restoration of RTTI is required.
        return decodedValue.cast<String>();
      }
  
      return decodedValue!;
    } on FormatException {
      // If there is a FormatException, try adding double quotes and parsing again
      try {
        return json.decode('\"$encodedValue\"');
      } catch (e) {
        // If parsing still fails, return the original string
        // This indicates the string may not be a valid JSON format
        return encodedValue;
      }
    } catch (e) {
      // Print the exception and return an empty string
      print(e.toString());
      return '';
    }
  }

}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled Natural Earth map contains a complete world dataset', () async {
    final source = await File(
      'assets/maps/ne_110m_admin_0_countries.geojson',
    ).readAsString();
    final collection = jsonDecode(source) as Map<String, dynamic>;
    final features = collection['features'] as List<dynamic>;

    expect(collection['type'], 'FeatureCollection');
    expect(features.length, greaterThanOrEqualTo(170));
    expect(
      features.every(
        (feature) =>
            feature is Map<String, dynamic> &&
            feature['geometry'] is Map<String, dynamic>,
      ),
      isTrue,
    );
  });

  test('radio map does not depend on a runtime raster tile provider', () async {
    final source = await File(
      'lib/features/radio/presentation/pages/radio_map_explorer_page.dart',
    ).readAsString();

    expect(source, isNot(contains('cartocdn.com')));
    expect(source, isNot(contains('TileLayer(')));
    expect(source, contains('ne_110m_admin_0_countries.geojson'));
  });
}

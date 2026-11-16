import '../../../../core/fake/fake_backend.dart';
import '../../../../core/network/api_client.dart';

abstract class PlacesDataSource {
  Future<List<Map<String, dynamic>>> places({String? category, String? query});

  Future<Map<String, dynamic>> details(String placeId);
}

class PlacesApiDataSource implements PlacesDataSource {
  PlacesApiDataSource(this.api);

  final ApiClient api;

  @override
  Future<List<Map<String, dynamic>>> places({String? category, String? query}) async {
    final list = await api.get('/places', query: {
      if (category != null) 'category': category,
      if (query != null && query.isNotEmpty) 'q': query,
    }) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String placeId) async =>
      Map<String, dynamic>.from(await api.get('/places/$placeId') as Map);
}

class PlacesFakeDataSource implements PlacesDataSource {
  PlacesFakeDataSource(this.backend);

  final FakeBackend backend;

  @override
  Future<List<Map<String, dynamic>>> places({String? category, String? query}) =>
      backend.places(category: category, query: query);

  @override
  Future<Map<String, dynamic>> details(String placeId) => backend.placeDetails(int.parse(placeId));
}

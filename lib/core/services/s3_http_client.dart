import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dio instance that bypasses SSL cert validation for megas4.com.
/// Used for downloading S3 files whose CA isn't in the Android system store.
Dio buildS3Dio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 5),
    ),
  );

  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) =>
        host.endsWith('megas4.com');
    return client;
  };

  return dio;
}

/// Returns true if [url] points to the private S3 bucket (megas4.com).
/// These URLs require a signed GET URL — a bare PUT URL returns 400.
bool isS3Url(String url) => url.contains('megas4.com');

/// Calls the `get-download-url` edge function to obtain a time-limited
/// presigned GET URL for a private S3 object.
///
/// Throws if the function call fails or returns an error.
Future<String> getS3SignedUrl(String fileUrl) async {
  final response = await Supabase.instance.client.functions.invoke(
    'get-download-url',
    body: {'fileUrl': fileUrl},
  );
  if (response.status != 200) {
    throw Exception(
      'get-download-url failed (${response.status}): ${response.data}',
    );
  }
  final signedUrl = (response.data as Map<String, dynamic>)['signedUrl'];
  if (signedUrl == null || signedUrl is! String || signedUrl.isEmpty) {
    throw Exception('get-download-url returned no signedUrl');
  }
  return signedUrl;
}

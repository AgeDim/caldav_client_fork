import 'dart:convert';
import 'dart:io';

import 'package:caldav_client/src/cal_response.dart';
import 'package:caldav_client/src/utils.dart';
import 'package:http/http.dart' as http;

class CalDavBase {
  final HttpClient client;
  final String baseUrl;
  final Map<String, dynamic>? headers;

  CalDavBase({
    required this.baseUrl,
    this.headers,
    Duration? connectionTimeout,
  }) : client = HttpClient() {
    client.connectionTimeout = connectionTimeout;
  }

  /// Allows the client to fetch properties from a url.
  Future<CalResponse> propfind(String path, dynamic body,
      {int? depth, Map<String, dynamic>? headers}) async {
    var uri = _fullUri(path);
    var request = await client.openUrl('PROPFIND', Uri.parse(uri));

    // headers
    request.headers.contentType =
        ContentType('application', 'xml', charset: 'utf-8');

    var temp = <String, dynamic>{
      'Prefer': 'return-minimal',
      HttpHeaders.acceptCharsetHeader: 'utf-8',
      if (depth != null) 'Depth': depth,
      ...?headers,
      ...?this.headers
    };

    temp.forEach((key, value) {
      request.headers.add(key, value);
    });

    request.write(body);

    var response = await request.close();

    return CalResponse.fromHttpResponse(response, uri);
  }

  /// REPORT performs a search for all calendar object resources that match a
  /// specified filter. The response of this report will contain all the WebDAV
  /// properties and calendar object resource data specified in the request.
  Future<CalResponse> report(String path, dynamic body,
      {int? depth, Map<String, String>? headers}) async {
    var uri = _fullUri(path);
    if (uri.contains("calendar.mail.ru")) {
      final defaultHeaders = <String, String>{
        'Content-Type': 'application/xml; charset=utf-8',
        'Accept': 'application/xml,text/xml',
        'Accept-Charset': 'utf-8',
        if (depth != null) 'Depth': depth.toString(),
        ...?this.headers?.cast<String, String>(),
        ...?headers,
      };

      final response = await http.Request('GET', Uri.parse(uri))
        ..headers.addAll(defaultHeaders)
        ..body = body;

      final streamed = await response.send();
      final fullResponse = await http.Response.fromStream(streamed);

      return CalResponse.fromHttpResponseHttp(fullResponse, uri.toString());
    } else {
      var request = await client.openUrl('REPORT', Uri.parse(uri));

      // headers
      request.headers.contentType =
          ContentType('application', 'xml', charset: 'utf-8');

      var temp = <String, dynamic>{
        HttpHeaders.acceptHeader: 'application/xml,text/xml',
        HttpHeaders.acceptCharsetHeader: 'utf-8',
        if (depth != null) 'Depth': depth,
        ...?headers,
        ...?this.headers
      };

      temp.forEach((key, value) {
        request.headers.add(key, value);
      });

      request.write(body);

      var response = await request.close();

      return CalResponse.fromHttpResponse(response, uri);
    }
  }

  /// Fetch the contents for the object
  Future<CalResponse> downloadIcs(String path, String savePath,
      {Map<String, dynamic>? headers}) async {
    var uri = _fullUri(path);
    var request = await client.getUrl(Uri.parse(uri));

    var temp = <String, dynamic>{...?headers, ...?this.headers};

    temp.forEach((key, value) {
      request.headers.add(key, value);
    });

    var response = await request.close();
    await response.pipe(File(savePath).openWrite());

    return CalResponse(url: uri, headers: {}, statusCode: response.statusCode);
  }

  /// Update calendar ifMatch the etag
  Future<CalResponse> updateCal(String path, String etag, dynamic calendar,
      {Map<String, dynamic>? headers}) async {
    var uri = _fullUri(path);
    var request = await client.putUrl(Uri.parse(uri));

    request.headers.contentType =
        ContentType('text', 'calendar', charset: 'utf-8');

    var temp = <String, dynamic>{
      'If-Match': '"$etag"',
      ...?headers,
      ...?this.headers
    };

    temp.forEach((key, value) {
      request.headers.add(key, value);
    });

    request.write(calendar);

    var response = await request.close();

    return CalResponse.fromHttpResponse(response, uri);
  }

  /// Create calendar
  Future<CalResponse> createCal(String path, dynamic calendar,
      {Map<String, dynamic>? headers}) async {
    final uri = Uri.parse(_fullUri(path));
    final request = await client.putUrl(uri);

    request.headers.contentType =
        ContentType("text", "calendar", charset: "utf-8");

    final temp = <String, dynamic>{...?headers, ...?this.headers};

    request.headers.set("If-None-Match", "*");
    request.headers.set("User-Agent", "PostmanRuntime/7.39.0");
    request.headers.set("Accept", "*/*");
    request.headers.set("Connection", "keep-alive");
    request.headers.set("Accept-Encoding", "gzip, deflate, br");

    temp.forEach((key, value) {
      request.headers.set(key, value.toString());
    });

    final body = utf8.encode(calendar);
    request.contentLength = body.length;
    request.add(body);
    print(request.headers);
    final response = await request.close();

    return CalResponse.fromHttpResponse(response, uri.toString());
  }

  /// Delete calendar
  Future<CalResponse> deleteCal(String path, String etag,
      {Map<String, dynamic>? headers}) async {
    var uri = _fullUri(path);
    var request = await client.deleteUrl(Uri.parse(uri));

    var temp = <String, dynamic>{
      'If-Match': '"$etag"',
      ...?headers,
      ...?this.headers
    };

    temp.forEach((key, value) {
      request.headers.add(key, value);
    });

    var response = await request.close();

    return CalResponse.fromHttpResponse(response, uri);
  }

  String _fullUri(String path) {
    return join(baseUrl, path);
  }

  /// Get etag
  Future<CalResponse> getEtag(String path,
      {Map<String, dynamic>? headers}) async {
    var uri = _fullUri(path);
    var request = await client.getUrl(Uri.parse(uri));

    var temp = <String, dynamic>{...?headers, ...?this.headers};

    temp.forEach((key, value) {
      request.headers.add(key, value);
    });

    var response = await request.close();

    return CalResponse.fromHttpResponse(response, uri);
  }
}

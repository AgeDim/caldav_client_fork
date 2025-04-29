import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';
import 'package:caldav_client/src/multistatus/multistatus.dart';
import 'package:http/http.dart' as http;

class CalResponse {
  final String url;
  final int statusCode;
  final Map<String, dynamic> headers;
  final XmlDocument? document;
  final MultiStatus? multistatus;

  CalResponse(
      {required this.url,
      required this.statusCode,
      required this.headers,
      this.document})
      : multistatus = document != null ? MultiStatus.fromXml(document) : null;

  static Future<CalResponse> fromHttpResponse(
      HttpClientResponse response, String url) async {
    var headers = <String, dynamic>{};

    // set headers
    response.headers.forEach((name, values) {
      headers[name] = values.length == 1 ? values[0] : values;
    });

    var body = await utf8.decoder.bind(response).join();

    XmlDocument? document;

    try {
      document = XmlDocument.parse(body);
    } catch (e) {
      document = null;
    }

    return CalResponse(
        url: url,
        statusCode: response.statusCode,
        headers: headers,
        document: document);
  }

  static CalResponse fromHttpResponseHttp(http.Response response, String url) {
    var headers = <String, dynamic>{};

    response.headers.forEach((name, value) {
      headers[name] = value;
    });

    final bodyRaw = utf8.decode(response.bodyBytes).trim();

    final prefix = "<?xml version='1.0' encoding='utf-8'?>"
        "<D:multistatus xmlns:D=\"DAV:\"><D:response>"
        "<href xmlns=\"DAV:\">${"https://calendar.mail.ru/principals/mail.ru/lokki0900/calendars/6C169E03-7024-416F-A8FB-018DE3E1CC99/".replaceAll('https://calendar.mail.ru/principals/mail.ru/', '')}</href>"
        "<D:propstat><D:prop><D:getetag>1743684950814</D:getetag>"
        "<C:calendar-data xmlns:C=\"urn:ietf:params:xml:ns:caldav\">";

    final suffix = "</C:calendar-data></D:prop>"
        "<status xmlns=\"DAV:\">HTTP/1.1 ${response.statusCode} OK</status>"
        "</D:propstat></D:response></D:multistatus>";

    final wrappedXml = "$prefix$bodyRaw$suffix";

    XmlDocument? document;
    try {
      document = XmlDocument.parse(wrappedXml);
    } catch (e) {
      print('❌ XML parsing error: $e');
      print('📦 Raw body:\n$wrappedXml');
      document = null;
    }

    return CalResponse(
      url: url,
      statusCode: response.statusCode,
      headers: headers,
      document: document,
    );
  }

  @override
  String toString() {
    var string = '';
    string += 'URL: $url\n';
    string += 'STATUS CODE: $statusCode\n';
    string += 'HEADERS:\n$headers\n';
    string +=
        'BODY:\n${document != null ? document!.toXmlString(pretty: true) : null}';

    return string;
  }
}

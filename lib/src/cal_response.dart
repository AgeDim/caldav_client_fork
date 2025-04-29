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

  static String splitCalendarDataResponses(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final responses = document.findAllElements('response', namespace: 'DAV:');
    final buffer = StringBuffer();

    buffer.writeln("<?xml version='1.0' encoding='utf-8'?>");
    buffer.writeln('<D:multistatus xmlns:D="DAV:">');

    for (var response in responses) {
      final href =
          response.getElement('href', namespace: 'DAV:')?.innerText ?? '';
      final getetag = response
          .findAllElements('getetag', namespace: 'DAV:')
          .first
          .innerText;

      final calendarDataElement = response
          .findAllElements('calendar-data',
              namespace: 'urn:ietf:params:xml:ns:caldav')
          .first;
      final calendarDataRaw = calendarDataElement.innerText.trim();

      final headerMatch = RegExp(r'BEGIN:VCALENDAR.*?VERSION:2.0', dotAll: true)
          .firstMatch(calendarDataRaw);
      final footerMatch =
          RegExp(r'END:VCALENDAR', dotAll: true).firstMatch(calendarDataRaw);
      final timezoneMatch =
          RegExp(r'BEGIN:VTIMEZONE.*?END:VTIMEZONE', dotAll: true)
              .firstMatch(calendarDataRaw);

      final header =
          headerMatch?.group(0)?.trim() ?? 'BEGIN:VCALENDAR\nVERSION:2.0';
      final footer = footerMatch?.group(0)?.trim() ?? 'END:VCALENDAR';
      final timezone = timezoneMatch?.group(0)?.trim() ?? '';

      final vevents = RegExp(r'BEGIN:VEVENT.*?END:VEVENT', dotAll: true)
          .allMatches(calendarDataRaw)
          .map((e) => e.group(0)!.trim())
          .toList();

      for (var vevent in vevents) {
        final uidMatch = RegExp(r'UID:(.+)').firstMatch(vevent);
        final uid = uidMatch?.group(1)?.trim() ??
            DateTime.now().millisecondsSinceEpoch.toString();

        final eventHref =
            href.endsWith('/') ? '$href$uid.ics' : '$href/$uid.ics';

        final newCalendarData = [
          header.trim(),
          vevent.trim(),
          if (timezone.isNotEmpty) timezone.trim(),
          footer.trim()
        ].join('\n');

        buffer.writeln('''<D:response>
  <href xmlns="DAV:">$eventHref</href>
  <D:propstat>
    <D:prop>
      <D:getetag>$getetag</D:getetag>
      <C:calendar-data xmlns:C="urn:ietf:params:xml:ns:caldav">${newCalendarData.trim()}</C:calendar-data>
    </D:prop>
    <status xmlns="DAV:">HTTP/1.1 200 OK</status>
  </D:propstat>
</D:response>''');
      }
    }

    buffer.writeln('</D:multistatus>');
    return buffer.toString();
  }

  static CalResponse fromHttpResponseHttp(http.Response response, String url) {
    var headers = <String, dynamic>{};

    response.headers.forEach((name, value) {
      headers[name] = value;
    });

    final bodyRaw = utf8.decode(response.bodyBytes).trim();

    final prefix = "<?xml version='1.0' encoding='utf-8'?>"
        "<D:multistatus xmlns:D=\"DAV:\"><D:response>"
        "<href xmlns=\"DAV:\">${url.replaceAll('https://calendar.mail.ru/principals/mail.ru/', '')}</href>"
        "<D:propstat><D:prop><D:getetag>1743684950814</D:getetag>"
        "<C:calendar-data xmlns:C=\"urn:ietf:params:xml:ns:caldav\">";

    final suffix = "\n</C:calendar-data></D:prop>"
        "<status xmlns=\"DAV:\">HTTP/1.1 ${response.statusCode} OK</status>"
        "</D:propstat></D:response></D:multistatus>";

    final wrappedXml = "$prefix$bodyRaw$suffix";
    XmlDocument? document;
    try {
      document = XmlDocument.parse(splitCalendarDataResponses(wrappedXml));
    } catch (e) {
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

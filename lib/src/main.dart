import 'package:caldav_client/caldav_client.dart';
import 'package:icalendar_parser/icalendar_parser.dart';

void main() async {
  CalDavClient client = CalDavClient(
    baseUrl: 'https://calendar.mail.ru/principals/mail.ru/lokki0900/calendars/',
    headers: Authorization('lokki0900@mail.ru', 'mUhmFtc7PSPLt4F0fxyj').basic(),
  );
  print('da');
  final data = await client.getObjects(
      '6C169E03-7024-416F-A8FB-018DE3E1CC99/',
      depth: 1);
  if (data.statusCode >= 300) {
    print('pizda');
  }

  final multiStatus = data.multistatus;

  if (multiStatus != null) {
    for (var result in multiStatus.response) {
      final icsValue = result.propstat.prop['calendar-data'];
      if (icsValue != null && icsValue != "") {
        final icsData = ICalendar.fromString(icsValue);
        print(icsData.data);
      }
    }
  }
}

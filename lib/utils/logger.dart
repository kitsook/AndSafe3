import 'dart:developer' as developer;

import 'package:logging/logging.dart';

final log = new Logger('AndSafe');

void setupLogger() {
  // Logger.root.level = kReleaseMode? Level.INFO : Level.ALL;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log('${record.level.name}: ${record.time}: ${record.message}',
        name: 'net.clarenceho.andsafe');
  });
}

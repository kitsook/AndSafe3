import 'package:fluro/fluro.dart';

import './routes_handler.dart';

class AndSafeRouter {
  static FluroRouter router = FluroRouter();

  static void setupRouter() {
    router.define(
      'signatureSetup',
      handler: signatureSetupHandler,
    );
    router.define(
      'home',
      handler: homeHandler,
    );
    router.define(
      'note/:id',
      handler: editNoteHandler,
    );
    router.define(
      'settings/change',
      handler: changeSettingsHandler,
    );
    router.define(
      'password/change',
      handler: changePasswordHandler,
    );
    router.define(
      'import/:password',
      handler: importHandler,
    );
  }
}

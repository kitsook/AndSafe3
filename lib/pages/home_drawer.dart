import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeDrawer extends StatelessWidget {
  final bool isAuthenticated;
  final VoidCallback onOpenSettings;
  final VoidCallback onChangePassword;
  final VoidCallback onImportNotes;
  final VoidCallback onExportNotes;
  final VoidCallback onExitApp;

  const HomeDrawer({
    Key? key,
    required this.isAuthenticated,
    required this.onOpenSettings,
    required this.onChangePassword,
    required this.onImportNotes,
    required this.onExportNotes,
    required this.onExitApp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Container(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(
                        image: AssetImage('assets/images/icons/safe.png'),
                        width: 80,
                        height: 80,
                      ),
                      SizedBox(height: 10),
                      Text('AndSafe', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSettingsTile(context),
                  _buildChangePasswordTile(context),
                  _buildImportTile(context),
                  _buildExportTile(context),
                  _buildExitTile(context),
                ],
              ),
            ),
          ),
          Divider(),
          _buildWebsiteLauncher(context),
          Container(
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: Column(
                children: [
                  BuildVersionText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.settings_rounded),
      title: Text(AppLocalizations.of(context)!.settings),
      onTap: onOpenSettings,
      enabled: isAuthenticated,
    );
  }

  Widget _buildChangePasswordTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.cached_rounded),
      title: Text(AppLocalizations.of(context)!.changePassword),
      onTap: onChangePassword,
      enabled: isAuthenticated,
    );
  }

  Widget _buildImportTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.read_more_rounded),
      title: Text(AppLocalizations.of(context)!.importNotes),
      subtitle: Text(AppLocalizations.of(context)!.importNotesHint),
      onTap: onImportNotes,
      enabled: isAuthenticated,
    );
  }

  Widget _buildExportTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.save_rounded),
      title: Text(AppLocalizations.of(context)!.exportNotes),
      subtitle: Text(AppLocalizations.of(context)!.exportNotesHint),
      onTap: onExportNotes,
      enabled: isAuthenticated,
    );
  }

  Widget _buildExitTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.exit_to_app_rounded),
      title: Text(AppLocalizations.of(context)!.exitApp),
      onTap: () {
        Navigator.of(context).pop();
        onExitApp();
      },
    );
  }

  Widget _buildWebsiteLauncher(BuildContext context) {
    final Uri home = Uri.https('github.com', '/kitsook/AndSafe3');

    return ListTile(
      leading: Icon(Icons.launch_rounded),
      onTap: () {
        launchUrl(home);
      },
      title: Text(AppLocalizations.of(context)!.visitWebSite),
    );
  }
}

class BuildVersionText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();

    return FutureBuilder(
      future: packageInfo,
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        if (snapshot.hasError) {
          log.severe("Problem retrieving version info");
          log.severe(snapshot.error.toString());
          return Container(child: Center(child: Text('AndSafe3')));
        }
        if (snapshot.data == null) {
          return Container(child: Center(child: Text('AndSafe3')));
        } else {
          String appName = snapshot.data!.appName;
          String version = snapshot.data!.version;
          String buildNumber = snapshot.data!.buildNumber;

          return Container(
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.all(5.0),
            child: Text(
              '$appName $version build $buildNumber',
              style:
                  DefaultTextStyle.of(context).style.apply(fontSizeFactor: 0.8),
            ),
          );
        }
      },
    );
  }
}

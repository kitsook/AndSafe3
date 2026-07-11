import 'dart:convert';
import 'dart:typed_data';

import 'package:andsafe/l10n/app_localizations.dart';
import 'package:andsafe/models/signature.dart';
import 'package:andsafe/utils/andsafe_crypto.dart';
import 'package:andsafe/utils/logger.dart';
import 'package:andsafe/utils/notification.dart';
import 'package:andsafe/utils/services/signature_service.dart';
import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:provider/provider.dart';

class SignatureSetupPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SignatureInputState();
  }
}

class _SignatureInputState extends State<SignatureSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _password1Controller = TextEditingController();
  final _password2Controller = TextEditingController();

  bool _isBusy = false;

  @override
  void dispose() {
    _password1Controller.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AndSafe'),
      ),
      body: LoadingOverlay(
        isLoading: this._isBusy,
        child: Container(
          padding: EdgeInsets.all(10.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(AppLocalizations.of(context)!.setupPassword,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildVerticalSpacing(),
                  _buildPassword1Field(),
                  _buildVerticalSpacing(),
                  _buildPassword2Field(),
                  _buildVerticalSpacing(),
                  _buildActionButtons()
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalSpacing() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
    );
  }

  Widget _buildPassword1Field() {
    return TextFormField(
      autofocus: true,
      controller: _password1Controller,
      decoration: new InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.enterPassword),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.passwordCannotBeEmpty;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildPassword2Field() {
    return TextFormField(
      autofocus: true,
      controller: _password2Controller,
      decoration: new InputDecoration(
          contentPadding:
              EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: AppLocalizations.of(context)!.enterSamePasswordAgain),
      // The validator receives the text that the user has entered.
      validator: (value) {
        if (value == null ||
            value.isEmpty ||
            value != _password1Controller.text) {
          return AppLocalizations.of(context)!.twoPasswordsDoNotMatch;
        }
        return null;
      },
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(10.0),
      child: ElevatedButton(
        onPressed: () async {
          // validate form fields
          if (_formKey.currentState!.validate()) {
            displaySnackBarMsg(
                context: context,
                msg: AppLocalizations.of(context)!.generatingEncryptionKey);

            setState(() {
              this._isBusy = true;
            });
            Uint8List? passwordBytes;
            try {
              passwordBytes =
                  Uint8List.fromList(utf8.encode(_password1Controller.text));
              Signature signature = await createSignature(passwordBytes);
              final signatureService = Provider.of<SignatureService>(context, listen: false);
              await signatureService.generateSignature(signature);

              // signature set. proceed to load list
              Navigator.pushReplacementNamed(context, 'home',
                  arguments: {'password': passwordBytes});
            } catch (e) {
              passwordBytes?.fillRange(0, passwordBytes.length, 0);
              log.fine("Failed to save the signature");
              log.fine(e.toString());
              displaySnackBarMsg(
                  context: context,
                  msg: AppLocalizations.of(context)!
                      .failedGeneratingEncryptionKey);
            } finally {
              setState(() {
                this._isBusy = false;
              });
            }
          }
        },
        child: Text(AppLocalizations.of(context)!.saveSetupPassword),
      ),
    );
  }
}

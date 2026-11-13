import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final mainController = ChangeNotifierProvider<MainController>(
  (ref) => MainController(ref: ref),
);

class MainController extends ChangeNotifier {
  Ref ref;

  MainController({required this.ref});

  GlobalKey<ScaffoldMessengerState> scaffoldMessage =
      GlobalKey<ScaffoldMessengerState>();

  void toast(String message, {Key? textKey, required BuildContext context}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, key: textKey),
        duration: Duration(milliseconds: message.length * 25),
      ),
    );
  }

  void sendMesage(String s, {required Key textKey}) {
    scaffoldMessage.currentState?.showSnackBar(
      SnackBar(
        content: Text(s, key: textKey),
        duration: Duration(milliseconds: s.length * 25),
      ),
    );
  }
}

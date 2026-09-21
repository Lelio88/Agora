/// [DeviceTimezone] adossé au plugin flutter_timezone (Android et web).
///
/// Un plugin absent ou en échec retombe sur [fallbackTimezone] : ne pas
/// connaître le fuseau ne doit jamais bloquer une inscription. Le serveur
/// valide de toute façon la valeur reçue.
library;

import 'package:agora/src/device/device_timezone.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final class PlatformDeviceTimezone implements DeviceTimezone {
  const PlatformDeviceTimezone();

  @override
  Future<String> current() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier.isEmpty ? fallbackTimezone : info.identifier;
    } on PlatformException {
      return fallbackTimezone;
    } on MissingPluginException {
      return fallbackTimezone;
    }
  }
}

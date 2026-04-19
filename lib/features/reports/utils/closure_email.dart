import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../cubit/cierre_sitsa_cubit.dart';

Future<void> sendClosureEmail({
  required EmailConfig config,
  required Uint8List pdfBytes,
  required DateTime date,
}) async {
  if (config.recipients.isEmpty) {
    throw StateError('Email config has no recipients.');
  }

  final smtp = SmtpServer(
    config.smtpHost,
    port: config.smtpPort,
    username: config.fromAddress,
    password: config.appPassword,
    ssl: config.smtpSecure,
    ignoreBadCertificate: false,
    allowInsecure: false,
  );

  final dateLabel = DateFormat('yyyy-MM-dd').format(date);
  final filename = 'cierre_$dateLabel.pdf';

  final message = Message()
    ..from = Address(config.fromAddress, config.fromName)
    ..recipients.addAll(config.recipients)
    ..subject = 'Cierre Diario — $dateLabel'
    ..text = 'Adjunto el cierre diario correspondiente al $dateLabel.'
    ..attachments.add(
      StreamAttachment(
        Stream.value(pdfBytes),
        'application/pdf',
        fileName: filename,
      ),
    );

  await send(message, smtp);
}

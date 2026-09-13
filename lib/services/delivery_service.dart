import 'dart:io';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The two halves of a WhatsApp hand-off.
///
/// WhatsApp's click-to-chat URL opens the right conversation and pre-fills the
/// message, but it cannot carry an attachment -- there is no URL parameter for
/// one. So sending a PDF is two steps: open the chat, then push the file
/// through the OS share sheet. Both live here so the UI does not have to know
/// why it is two taps.
class DeliveryService {
  /// Open the recipient's WhatsApp chat with the message text ready to send.
  Future<bool> openChat(String whatsappLink) async {
    final uri = Uri.tryParse(whatsappLink);
    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Hand the PDF to the share sheet, where the operator picks the WhatsApp
  /// chat. [message] rides along as the caption where the target supports it.
  Future<bool> sharePdf(File file, {String? message, Rect? originRect}) async {
    if (!await file.exists()) return false;
    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: message,
      sharePositionOrigin: originRect,
    );
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.dismissed;
  }
}

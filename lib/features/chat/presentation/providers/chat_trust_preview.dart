import 'package:flutter_riverpod/legacy.dart';

import '../../domain/value_objects/chat_connection_status.dart';

/// Debug builds only: a made-up certificate the chat view acts on as if the
/// server had asked for it, to see the confirmation without an untrusted
/// server. Null when not previewing.
final chatTrustPreviewProvider = StateProvider<ChatNeedsTrust?>((ref) => null);

/// What the preview shows: shaped like a real self-signed xxd certificate.
const ChatNeedsTrust kChatTrustPreviewRequest = ChatNeedsTrust(
  host: 'zentao.example.com',
  fingerprint:
      'AE:C6:E8:3B:91:4F:0D:72:5A:E1:C8:96:2B:7F:40:D3:'
      '18:6C:A5:09:F2:BE:57:83:E4:1D:9A:60:C7:35:FB:28',
  subject: '/C=CN/ST=Shandong/O=cnezsoft/CN=zentao.example.com',
  issuer: '/C=CN/ST=Shandong/O=cnezsoft/CN=cnezsoft',
);

import '../utils/json_helpers.dart';

class Message {
  final int? id;
  final String content;
  final int? senderId;
  final String? senderName;
  final String? senderAvatar;
  final int? topicId;
  final int? receiverId;
  final String? receiverName;
  final String? messageType;
  final String? messageSubtype;
  final String? createdAt;
  final String? displayTime;
  final bool isRecalled;
  final String? recallTime;
  final Map<String, dynamic>? quotedMessage;
  final List<Map<String, dynamic>>? forwardedMessages;
  final Map<String, dynamic>? fileInfo;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final String? attachment;
  final bool senderIsBot;
  final List<Map<String, dynamic>>? mentions;

  Message({
    this.id,
    required this.content,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.topicId,
    this.receiverId,
    this.receiverName,
    this.messageType,
    this.messageSubtype,
    this.createdAt,
    this.displayTime,
    this.isRecalled = false,
    this.recallTime,
    this.quotedMessage,
    this.forwardedMessages,
    this.fileInfo,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.attachment,
    this.senderIsBot = false,
    this.mentions,
  });

  /// Resolves the actual file URL from fileInfo.url or fileUrl
  String? get resolvedFileUrl {
    final fInfoUrl = fileInfo?['url'] as String?;
    return fInfoUrl ?? fileUrl;
  }

  /// Resolves the display file name
  String? get resolvedFileName {
    final fInfoName = fileInfo?['name'] as String?;
    return fInfoName ?? fileName;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: JsonHelpers.parseInt(json, 'id'),
      content: JsonHelpers.parseString(json, 'content') ?? '',
      senderId:
          JsonHelpers.parseInt(json, 'senderId', 'sender_id'),
      senderName: JsonHelpers.parseString(
          json, 'senderName', 'sender_username', 'username'),
      senderAvatar: JsonHelpers.parseString(
          json, 'senderAvatar', 'sender_avatar'),
      topicId:
          JsonHelpers.parseInt(json, 'topicId', 'topic_id'),
      receiverId:
          JsonHelpers.parseInt(json, 'receiverId', 'receiver_id'),
      receiverName: JsonHelpers.parseString(
          json, 'receiverName', 'receiver_username'),
      messageType:
          JsonHelpers.parseString(json, 'messageType') ?? 'normal',
      messageSubtype:
          JsonHelpers.parseString(json, 'messageSubtype') ?? 'text',
      createdAt:
          JsonHelpers.parseString(json, 'created_at', 'createdAt'),
      displayTime:
          JsonHelpers.parseString(json, 'messageTime'),
      isRecalled: json['isRecalled'] as bool? ?? false,
      recallTime:
          JsonHelpers.parseString(json, 'recallTime'),
      quotedMessage:
          json['quotedMessage'] as Map<String, dynamic>?,
      forwardedMessages:
          (json['forwardedMessages'] as List?)
              ?.cast<Map<String, dynamic>>(),
      fileInfo: json['fileInfo'] as Map<String, dynamic>?,
      fileUrl: JsonHelpers.parseString(
          json, 'file_url', 'fileUrl'),
      fileName: JsonHelpers.parseString(
          json, 'file_name', 'fileName'),
      fileSize:
          JsonHelpers.parseInt(json, 'file_size', 'fileSize'),
      fileType:
          JsonHelpers.parseString(json, 'file_type', 'fileType'),
      attachment:
          JsonHelpers.parseString(json, 'attachment'),
      senderIsBot:
          json['senderIsBot'] == true || json['isBot'] == true,
      mentions:
          (json['mentions'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }

  Message copyWith({
    String? content,
    bool? isRecalled,
    String? messageType,
    String? recallTime,
  }) {
    return Message(
      id: id,
      content: content ?? this.content,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      topicId: topicId,
      receiverId: receiverId,
      receiverName: receiverName,
      messageType: messageType ?? this.messageType,
      messageSubtype: messageSubtype,
      createdAt: createdAt,
      displayTime: displayTime,
      isRecalled: isRecalled ?? this.isRecalled,
      recallTime: recallTime ?? this.recallTime,
      quotedMessage: quotedMessage,
      forwardedMessages: forwardedMessages,
      fileInfo: fileInfo,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      attachment: attachment,
      senderIsBot: senderIsBot,
      mentions: mentions,
    );
  }
}

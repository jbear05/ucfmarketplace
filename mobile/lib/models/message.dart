class MessageSender {
  final String id;
  final String name;
  MessageSender({required this.id, required this.name});
  factory MessageSender.fromJson(Map<String, dynamic> json) =>
      MessageSender(id: json['_id'] ?? '', name: json['name'] ?? '');
}

class Message {
  final String id;
  final String threadId;
  final MessageSender sender;
  final String body;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id:        json['_id'] ?? '',
    threadId:  json['thread'] ?? '',
    sender:    MessageSender.fromJson(json['sender'] ?? {}),
    body:      json['body'] ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}

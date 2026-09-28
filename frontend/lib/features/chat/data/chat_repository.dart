import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat.dart';
import '../../../core/providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioProvider));
});

/// Module 9 endpoints: `/conversations/*`.
class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  /// The customer's conversation with a business, started if needed (UC-13).
  Future<ConversationDetail> open(int businessId) async {
    final res = await _dio.post('/conversations', data: {'business_id': businessId});
    return ConversationDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ConversationSummary>> list() async {
    final res = await _dio.get('/conversations');
    return (res.data as List)
        .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationDetail> get(int conversationId) async {
    final res = await _dio.get('/conversations/$conversationId');
    return ConversationDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MessagePage> messages(int conversationId,
      {int? beforeId, int? afterId, int limit = 30}) async {
    final res = await _dio.get('/conversations/$conversationId/messages', queryParameters: {
      'limit': limit,
      if (beforeId != null) 'before_id': beforeId,
      if (afterId != null) 'after_id': afterId,
    });
    return MessagePage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChatMessage> send(int conversationId,
      {required String body, required String clientId, String? photoKey}) async {
    final res = await _dio.post('/conversations/$conversationId/messages', data: {
      'body': body,
      'client_id': clientId,
      if (photoKey != null) 'photo': photoKey,
    });
    return ChatMessage.fromJson(res.data as Map<String, dynamic>);
  }

  /// Marks the conversation read ("Seen"); returns the unread total left.
  Future<int> markRead(int conversationId) async {
    final res = await _dio.post('/conversations/$conversationId/read');
    return (res.data as Map<String, dynamic>)['unread_total'] as int;
  }

  Future<void> report(int conversationId, ConversationReportReason reason, {String note = ''}) =>
      _dio.post('/conversations/$conversationId/report',
          data: {'reason': reason.api, 'note': note});
}

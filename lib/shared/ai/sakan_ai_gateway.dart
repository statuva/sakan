import 'ai_models.dart';

abstract interface class SakanAiGateway {
  Future<void> ensureAuthorized();

  Future<SakanAiResult> generate({
    required SakanAiFeature feature,
    String? targetId,
    String? prompt,
    Map<String, dynamic> grounding = const <String, dynamic>{},
    String locale = 'en',
  });

  Future<SakanAiResult> chat({
    required String message,
    List<SakanAiMessage> recentMessages = const <SakanAiMessage>[],
    String? conversationId,
    String locale = 'en',
  });
}

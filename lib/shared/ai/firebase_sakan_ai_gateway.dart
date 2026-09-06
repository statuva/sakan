import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/current_family_context.dart';
import '../repositories/profile_repository.dart';
import '../services/current_family_service.dart';
import 'ai_models.dart';
import 'sakan_ai_gateway.dart';

class FirebaseSakanAiGateway implements SakanAiGateway {
  FirebaseSakanAiGateway({
    required CurrentFamilyService currentFamilyService,
    required ProfileRepository profileRepository,
    FirebaseFunctions? functions,
  }) : _currentFamilyService = currentFamilyService,
       _profileRepository = profileRepository,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'me-central1');

  final CurrentFamilyService _currentFamilyService;
  final ProfileRepository _profileRepository;
  final FirebaseFunctions _functions;

  @override
  Future<void> ensureAuthorized() async {
    await _authorizedAdultContext();
  }

  @override
  Future<SakanAiResult> generate({
    required SakanAiFeature feature,
    String? targetId,
    String? prompt,
    Map<String, dynamic> grounding = const <String, dynamic>{},
    String locale = 'en',
  }) async {
    final context = await _authorizedAdultContext();
    return _call(
      'sakanGenerate',
      <String, dynamic>{
        'version': 1,
        'familyId': context.familyId,
        'feature': feature.name,
        'targetId': targetId,
        'prompt': prompt,
        'grounding': grounding,
        'locale': locale,
      },
    );
  }

  @override
  Future<SakanAiResult> chat({
    required String message,
    List<SakanAiMessage> recentMessages = const <SakanAiMessage>[],
    String? conversationId,
    String locale = 'en',
  }) async {
    final context = await _authorizedAdultContext();
    final boundedRecentMessages = recentMessages.length <= 8
        ? recentMessages
        : recentMessages.sublist(recentMessages.length - 8);
    return _call(
      'sakanChat',
      <String, dynamic>{
        'version': 1,
        'familyId': context.familyId,
        'message': message.trim(),
        'conversationId': conversationId,
        'recentMessages': boundedRecentMessages
            .map((item) => item.toMap())
            .toList(growable: false),
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'locale': locale,
      },
    );
  }

  Future<CurrentFamilyContext> _authorizedAdultContext() async {
    final context = await _currentFamilyService.load();
    if (!context.canUseAi) {
      throw const SakanAiException(
        'Sakan AI is currently available to confirmed adults only.',
        code: 'permission-denied',
      );
    }

    final privacy = await _profileRepository.getPrivacyPreferences(
      familyId: context.familyId,
      memberId: context.userId,
    );
    if (!privacy.aiConsent) {
      throw const SakanAiException(
        'Turn on AI assistance in Privacy Settings before using this feature.',
        code: 'consent-required',
      );
    }
    return context;
  }

  Future<SakanAiResult> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const SakanAiException(
          'Sign in again before using Sakan AI.',
          code: 'unauthenticated',
        );
      }

      await user.getIdToken(true);

      final callable = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 110),
        ),
      );
      final response = await callable.call<Map<String, dynamic>>(payload);
      return SakanAiResult.fromMap(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw SakanAiException(
        _friendlyMessage(error.code, error.message),
        code: error.code,
      );
    } on SakanAiException {
      rethrow;
    } catch (_) {
      throw const SakanAiException(
        'Sakan could not reach AI right now. Your saved family data is safe.',
      );
    }
  }

  String _friendlyMessage(String code, String? backendMessage) {
    return switch (code) {
      'permission-denied' =>
        backendMessage ?? 'This AI feature is available to confirmed adults.',
      'failed-precondition' =>
        backendMessage ?? 'AI consent is required for this request.',
      'resource-exhausted' =>
        backendMessage ?? 'Sakan AI has reached its current usage limit.',
      'invalid-argument' =>
        backendMessage ?? 'Sakan needs a little more detail.',
      'unauthenticated' => 'Sign in again before using Sakan AI.',
      'internal' =>
        backendMessage ?? 'Sakan could not validate this AI response.',
      _ => 'Sakan AI is temporarily unavailable. The regular app still works.',
    };
  }
}

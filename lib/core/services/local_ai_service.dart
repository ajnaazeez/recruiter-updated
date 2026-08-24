import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localAiServiceProvider = Provider<LocalAIService>((ref) {
  return LocalAIService();
});

class GeneratedJobContent {
  final String description;
  final List<String> responsibilities;
  final List<String> requirements;

  GeneratedJobContent({
    required this.description,
    required this.responsibilities,
    required this.requirements,
  });
}

class LocalAIService {
  final FirebaseFunctions _functions;

  LocalAIService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<GeneratedJobContent> generateJobContent(
    String role,
    List<String> skills,
  ) async {
    try {
      print('DEBUG_AI: Starting generation. Role: $role, Skills: $skills');
      final HttpsCallable callable = _functions.httpsCallable('generateJobDescription');
      
      print('DEBUG_AI: Calling function generateJobDescription on region us-central1');
      final HttpsCallableResult result = await callable.call({
        'role': role,
        'skills': skills,
      });
      print('DEBUG_AI: Call succeeded. Result data type: ${result.data.runtimeType}');

      final Map<String, dynamic> data = Map<String, dynamic>.from(result.data as Map);

      final description = data['description'] as String? ?? '';
      final responsibilities = List<String>.from(data['responsibilities'] ?? []);
      final requirements = List<String>.from(data['requirements'] ?? []);

      return GeneratedJobContent(
        description: description,
        responsibilities: responsibilities,
        requirements: requirements,
      );
    } on FirebaseFunctionsException catch (e) {
      print('DEBUG_AI: FirebaseFunctionsException occurred: [${e.code}] - ${e.message} - details: ${e.details}');
      if (e.code == 'unauthenticated') {
        throw Exception('Please sign in to generate job descriptions.');
      } else if (e.code == 'permission-denied') {
        throw Exception('Access denied. Recruiter profile required.');
      } else if (e.code == 'invalid-argument') {
        throw Exception(e.message ?? 'Invalid inputs provided.');
      }
      throw Exception('AI generation is temporarily unavailable. Please try again.');
    } catch (e, stackTrace) {
      print('DEBUG_AI: Unexpected error generating job content: $e\n$stackTrace');
      throw Exception('AI generation is temporarily unavailable. Please try again.');
    }
  }
}

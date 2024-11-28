import 'package:groq/groq.dart';

class AIService {
  final Groq groq = Groq(
    apiKey: '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',
  );

  Future<String> generateDescription(String keywords, String category) async {
    try {
      groq.startChat();
      
      const instructions = '''
        You are a clothing description expert. Generate appealing descriptions from keywords.
        Rules:
        1. Use the keywords as inspiration but expand naturally
        2. Keep descriptions under 30 words
        3. Focus on style, condition, and potential uses
        4. Be positive and engaging
      ''';
      
      groq.setCustomInstructionsWith(instructions);

      final text = '''
        Category: $category
        Keywords: $keywords
        Generate a brief, natural-sounding description for this clothing item.
      ''';

      GroqResponse response = await groq.sendMessage(text);
      return response.choices.first.message.content;
      
    } on GroqException catch (error) {
      throw Exception('Groq API error: ${error.message}');
    } catch (e) {
      throw Exception('Error generating description: $e');
    }
  }
}

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
        5. Do not use quotation marks in the response
      ''';
      
      groq.setCustomInstructionsWith(instructions);

      final text = '''
        Category: $category
        Keywords: $keywords
        Generate a brief, natural-sounding description for this clothing item. Do not use quotation marks.
      ''';

      GroqResponse response = await groq.sendMessage(text);
      return response.choices.first.message.content.replaceAll('"', '').replaceAll("'", '');
      
    } on GroqException catch (error) {
      throw Exception('Groq API error: ${error.message}');
    } catch (e) {
      throw Exception('Error generating description: $e');
    }
  }

  Future<bool> checkInappropriateContent(String content) async {
    try {
      print('DEBUG: Starting AI content check');
      groq.startChat();
      
      const instructions = '''
        You are a content moderator. Analyze text for inappropriate content.
        Rules:
        1. Check for hate speech, explicit content, harassment, or offensive language
        2. Return "true" if content is inappropriate, "false" if it's safe
        3. Be strict but fair in moderation
        4. Consider context and intent
      ''';
      
      print('DEBUG: Setting AI instructions');
      groq.setCustomInstructionsWith(instructions);

      final text = '''
        Content to analyze: $content
        Is this content inappropriate? Reply with only "true" or "false".
      ''';

      print('DEBUG: Sending content to AI for analysis');
      GroqResponse response = await groq.sendMessage(text);
      final result = response.choices.first.message.content.toLowerCase().trim() == 'true';
      print('DEBUG: AI response raw: ${response.choices.first.message.content}');
      print('DEBUG: AI analysis result: $result');
      return result;
      
    } catch (e) {
      print('DEBUG: Error in AI check: $e');
      // If AI check fails, err on the side of caution
      return true;
    }
  }
}

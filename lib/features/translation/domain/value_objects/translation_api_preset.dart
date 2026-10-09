/// A ready-made OpenAI-compatible endpoint the user can translate through with
/// their own API key. Models are suggestions: providers rename them, and the
/// user can type any other.
class TranslationApiPreset {
  const TranslationApiPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.keyUrl,
    this.needsKey = true,
  });

  final String id;
  final String name;

  /// Root the `/chat/completions` path is appended to.
  final String baseUrl;
  final String defaultModel;

  /// Where the user creates a key; null when none is needed.
  final String? keyUrl;
  final bool needsKey;

  static const custom = TranslationApiPreset(
    id: 'custom',
    name: 'Custom',
    baseUrl: '',
    defaultModel: '',
  );

  static const all = <TranslationApiPreset>[
    TranslationApiPreset(
      id: 'gemini',
      name: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      defaultModel: 'gemini-2.5-flash',
      keyUrl: 'https://aistudio.google.com/apikey',
    ),
    TranslationApiPreset(
      id: 'groq',
      name: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
      keyUrl: 'https://console.groq.com/keys',
    ),
    TranslationApiPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'meta-llama/llama-3.3-70b-instruct:free',
      keyUrl: 'https://openrouter.ai/keys',
    ),
    TranslationApiPreset(
      id: 'ollama',
      name: 'Ollama (local)',
      baseUrl: 'http://localhost:11434/v1',
      defaultModel: 'qwen2.5:7b',
      needsKey: false,
    ),
    custom,
  ];

  static TranslationApiPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => custom);
}

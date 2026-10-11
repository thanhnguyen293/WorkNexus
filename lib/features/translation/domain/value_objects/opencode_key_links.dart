/// Where to create an API key for an OpenCode provider id. Providers not listed
/// fall back to OpenCode's own console, which is where `opencode` / `opencode-go`
/// keys come from and where the other providers are documented.
const String kOpenCodeConsoleUrl = 'https://opencode.ai/auth';

const Map<String, String> _keyPages = {
  'opencode': kOpenCodeConsoleUrl,
  'opencode-go': kOpenCodeConsoleUrl,
  'anthropic': 'https://console.anthropic.com/settings/keys',
  'openai': 'https://platform.openai.com/api-keys',
  'google': 'https://aistudio.google.com/apikey',
  'openrouter': 'https://openrouter.ai/keys',
  'deepseek': 'https://platform.deepseek.com/api_keys',
  'groq': 'https://console.groq.com/keys',
  'xai': 'https://console.x.ai',
  'mistral': 'https://console.mistral.ai/api-keys',
};

/// The page where [providerId] (case/space-insensitive) issues API keys.
String openCodeKeyUrl(String providerId) =>
    _keyPages[providerId.trim().toLowerCase()] ?? kOpenCodeConsoleUrl;

/// The OpenCode provider a `provider/model` id runs on — the one whose key the
/// translation needs. OpenCode's own default (no model pinned) is `opencode`.
String openCodeProviderOf(String model) {
  final slash = model.indexOf('/');
  return slash > 0 ? model.substring(0, slash) : 'opencode';
}

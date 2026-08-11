import Constants from 'expo-constants';

type Extra = {
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  openaiApiKey?: string;
  useEdgeExtraction?: boolean | string;
  extractProxyUrl?: string;
};

const extra = (Constants.expoConfig?.extra ?? {}) as Extra;

function truthy(value: unknown): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
  }
  return false;
}

export const env = {
  supabaseUrl:
    process.env.EXPO_PUBLIC_SUPABASE_URL ?? extra.supabaseUrl ?? '',
  supabaseAnonKey:
    process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? extra.supabaseAnonKey ?? '',
  openaiApiKey:
    process.env.EXPO_PUBLIC_OPENAI_API_KEY ?? extra.openaiApiKey ?? '',
  useEdgeExtraction: truthy(
    process.env.EXPO_PUBLIC_USE_EDGE_EXTRACTION ?? extra.useEdgeExtraction,
  ),
  extractProxyUrl: (
    process.env.EXPO_PUBLIC_EXTRACT_PROXY_URL ??
    extra.extractProxyUrl ??
    'http://localhost:8787'
  ).replace(/\/$/, ''),
};

export function isSupabaseConfigured(): boolean {
  return Boolean(env.supabaseUrl && env.supabaseAnonKey);
}

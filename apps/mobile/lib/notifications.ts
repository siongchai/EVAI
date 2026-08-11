import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import * as Device from 'expo-device';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';

import { getSupabase } from '@/lib/supabase';

const PREFS_KEY = 'evai.notifications_prefs';
const MONTHLY_NOTIFICATION_ID = 'evai-monthly-summary';

export type NotificationPrefs = {
  monthlySummaryEnabled: boolean;
};

const DEFAULT_PREFS: NotificationPrefs = {
  monthlySummaryEnabled: false,
};

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

export function notificationsSupported(): boolean {
  return Platform.OS === 'ios' || Platform.OS === 'android';
}

export async function loadNotificationPrefs(): Promise<NotificationPrefs> {
  try {
    const raw = await AsyncStorage.getItem(PREFS_KEY);
    if (!raw) return { ...DEFAULT_PREFS };
    const parsed = JSON.parse(raw) as Partial<NotificationPrefs>;
    return {
      monthlySummaryEnabled: Boolean(parsed.monthlySummaryEnabled),
    };
  } catch {
    return { ...DEFAULT_PREFS };
  }
}

async function saveNotificationPrefs(prefs: NotificationPrefs): Promise<void> {
  await AsyncStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
}

function easProjectId(): string | null {
  const fromExtra = Constants.expoConfig?.extra?.eas?.projectId;
  if (typeof fromExtra === 'string' && fromExtra && !fromExtra.includes('replace-with')) {
    return fromExtra;
  }
  const fromEas = Constants.easConfig?.projectId;
  if (typeof fromEas === 'string' && fromEas) return fromEas;
  return null;
}

async function ensurePermissions(): Promise<boolean> {
  if (!notificationsSupported()) return false;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('monthly-summary', {
      name: 'Monthly summary',
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }

  const current = await Notifications.getPermissionsAsync();
  if (current.granted || current.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL) {
    return true;
  }
  const requested = await Notifications.requestPermissionsAsync();
  return (
    requested.granted ||
    requested.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL
  );
}

async function cancelMonthlySummary(): Promise<void> {
  await Notifications.cancelScheduledNotificationAsync(MONTHLY_NOTIFICATION_ID).catch(
    () => undefined,
  );
}

async function scheduleMonthlySummary(): Promise<void> {
  await cancelMonthlySummary();
  await Notifications.scheduleNotificationAsync({
    identifier: MONTHLY_NOTIFICATION_ID,
    content: {
      title: 'EVAi monthly summary',
      body: 'Open EVAi to review this month’s charging cost and energy.',
      data: { type: 'monthly_summary' },
      ...(Platform.OS === 'android' ? { channelId: 'monthly-summary' } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.MONTHLY,
      day: 1,
      hour: 9,
      minute: 0,
    },
  });
}

async function registerExpoPushToken(userId: string): Promise<string | null> {
  if (!Device.isDevice) return null;
  const projectId = easProjectId();
  if (!projectId) return null;

  try {
    const token = (
      await Notifications.getExpoPushTokenAsync({ projectId })
    ).data;
    await getSupabase()
      .from('profiles')
      .update({
        expo_push_token: token,
        notifications_enabled: true,
      })
      .eq('id', userId);
    return token;
  } catch (error) {
    console.warn('Expo push token registration skipped', error);
    return null;
  }
}

async function clearExpoPushToken(userId: string): Promise<void> {
  try {
    await getSupabase()
      .from('profiles')
      .update({
        expo_push_token: null,
        notifications_enabled: false,
      })
      .eq('id', userId);
  } catch (error) {
    console.warn('Could not clear push token', error);
  }
}

export async function setMonthlySummaryEnabled(
  userId: string,
  enabled: boolean,
): Promise<NotificationPrefs> {
  if (!notificationsSupported()) {
    throw new Error('Notifications are only available on iOS and Android builds.');
  }

  if (enabled) {
    const granted = await ensurePermissions();
    if (!granted) {
      throw new Error('Notification permission was not granted.');
    }
    await scheduleMonthlySummary();
    await registerExpoPushToken(userId);
  } else {
    await cancelMonthlySummary();
    await clearExpoPushToken(userId);
  }

  const prefs = { monthlySummaryEnabled: enabled };
  await saveNotificationPrefs(prefs);
  return prefs;
}

export async function refreshNotificationState(userId: string): Promise<NotificationPrefs> {
  const prefs = await loadNotificationPrefs();
  if (!notificationsSupported()) return prefs;
  if (prefs.monthlySummaryEnabled) {
    const granted = await ensurePermissions();
    if (granted) {
      await scheduleMonthlySummary();
      await registerExpoPushToken(userId);
    }
  }
  return prefs;
}

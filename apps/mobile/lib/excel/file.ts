import { Platform } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';

export async function pickExcelFile(): Promise<ArrayBuffer | null> {
  if (Platform.OS === 'web') {
    return pickFileWeb({
      accept:
        '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      as: 'arrayBuffer',
    });
  }

  const result = await DocumentPicker.getDocumentAsync({
    type: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-excel',
      '*/*',
    ],
    copyToCacheDirectory: true,
    multiple: false,
  });

  if (result.canceled || !result.assets?.[0]) return null;

  const asset = result.assets[0];
  const response = await fetch(asset.uri);
  return response.arrayBuffer();
}

export type MigratableFile =
  | { kind: 'excel'; data: ArrayBuffer; name: string }
  | { kind: 'json'; text: string; name: string };

/** Pick an EVAi Excel (.xlsx) or Swift JSON export for migration. */
export async function pickMigratableFile(): Promise<MigratableFile | null> {
  if (Platform.OS === 'web') {
    return pickMigratableFileWeb();
  }

  const result = await DocumentPicker.getDocumentAsync({
    type: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-excel',
      'application/json',
      'text/json',
      '*/*',
    ],
    copyToCacheDirectory: true,
    multiple: false,
  });

  if (result.canceled || !result.assets?.[0]) return null;
  const asset = result.assets[0];
  const name = asset.name || 'export';
  const lower = name.toLowerCase();

  if (lower.endsWith('.json') || asset.mimeType?.includes('json')) {
    const response = await fetch(asset.uri);
    return { kind: 'json', text: await response.text(), name };
  }

  const response = await fetch(asset.uri);
  return { kind: 'excel', data: await response.arrayBuffer(), name };
}

function pickMigratableFileWeb(): Promise<MigratableFile | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept =
      '.xlsx,.json,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/json';
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) {
        resolve(null);
        return;
      }
      const name = file.name || 'export';
      if (name.toLowerCase().endsWith('.json') || file.type.includes('json')) {
        resolve({ kind: 'json', text: await file.text(), name });
        return;
      }
      resolve({ kind: 'excel', data: await file.arrayBuffer(), name });
    };
    input.click();
  });
}

function pickFileWeb(options: {
  accept: string;
  as: 'arrayBuffer';
}): Promise<ArrayBuffer | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = options.accept;
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) {
        resolve(null);
        return;
      }
      resolve(await file.arrayBuffer());
    };
    input.click();
  });
}

export async function saveExcelFile(
  workbook: ArrayBuffer,
  fileName = 'evai-charging-sessions.xlsx',
): Promise<void> {
  if (Platform.OS === 'web') {
    const blob = new Blob([workbook], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    URL.revokeObjectURL(url);
    return;
  }

  const base64 = arrayBufferToBase64(workbook);
  const directory = FileSystem.cacheDirectory;
  if (!directory) {
    throw new Error('File cache is unavailable on this device.');
  }
  const path = `${directory}${fileName}`;
  await FileSystem.writeAsStringAsync(path, base64, {
    encoding: FileSystem.EncodingType.Base64,
  });

  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(path, {
      mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      dialogTitle: 'Export charging sessions',
      UTI: 'org.openxmlformats.spreadsheetml.sheet',
    });
  }
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i += 1) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

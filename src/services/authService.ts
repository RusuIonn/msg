
import { AccessKey } from '@/types';
import { v4 as uuidv4 } from 'uuid';

const STORAGE_KEY = 'mrp_access_keys';

// Helper to get DB
const getDb = (): AccessKey[] => {
  try {
    const data = localStorage.getItem(STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  } catch (e) {
    return [];
  }
};

// Helper to save DB
const saveDb = (keys: AccessKey[]) => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(keys));
};

export const authService = {
  // Generate a new key
  generateKey: (userId: string, pageId: string, daysValid: number = 30, note?: string): AccessKey => {
    const keys = getDb();
    
    // Check if active key already exists for this pair? (Optional, skipping for flexibility)
    
    const newKey: AccessKey = {
      key: uuidv4(), // Unique Key
      userId,
      pageId,
      createdAt: Date.now(),
      expiresAt: Date.now() + (daysValid * 24 * 60 * 60 * 1000),
      isRevoked: false,
      note
    };

    keys.push(newKey);
    saveDb(keys);
    return newKey;
  },

  // Validate a key
  validateKey: (inputKey: string): { valid: boolean; error?: string; data?: AccessKey } => {
    const keys = getDb();
    const found = keys.find(k => k.key === inputKey);

    if (!found) {
      return { valid: false, error: 'Cheie invalidă. Acces interzis.' };
    }

    if (found.isRevoked) {
      return { valid: false, error: 'Această cheie a fost revocată de administrator.' };
    }

    if (Date.now() > found.expiresAt) {
      return { valid: false, error: 'Cheia a expirat. Contactați administratorul pentru reînnoire.' };
    }

    return { valid: true, data: found };
  },

  // Revoke a key
  revokeKey: (keyString: string) => {
    const keys = getDb();
    const updated = keys.map(k => k.key === keyString ? { ...k, isRevoked: true } : k);
    saveDb(updated);
  },

  // Renew a key (extend expiry)
  renewKey: (keyString: string, daysToAdd: number = 30) => {
    const keys = getDb();
    const updated = keys.map(k => k.key === keyString ? { ...k, expiresAt: Date.now() + (daysToAdd * 24 * 60 * 60 * 1000), isRevoked: false } : k);
    saveDb(updated);
  },

  // List all keys (Admin only)
  getAllKeys: (): AccessKey[] => {
    return getDb().sort((a, b) => b.createdAt - a.createdAt);
  }
};

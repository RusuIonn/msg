import { createCipheriv, createDecipheriv, scrypt, randomBytes } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scrypt);

async function getKey(password: string): Promise<Buffer> {
  return (await scryptAsync(password, 'salt', 32)) as Buffer;
}

export async function encrypt(text: string): Promise<string> {
  const key = await getKey(process.env.ENCRYPTION_KEY);
  const iv = randomBytes(16); // Generate a random IV
  const cipher = createCipheriv('aes-256-cbc', key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  // Prepend the IV to the encrypted text (as hex)
  return iv.toString('hex') + ':' + encrypted;
}

export async function decrypt(encryptedText: string): Promise<string> {
  const key = await getKey(process.env.ENCRYPTION_KEY);
  const parts = encryptedText.split(':');
  const iv = Buffer.from(parts.shift(), 'hex'); // Extract the IV
  const encrypted = parts.join(':');
  const decipher = createDecipheriv('aes-256-cbc', key, iv);
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

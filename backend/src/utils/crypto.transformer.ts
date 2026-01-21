import { ValueTransformer } from 'typeorm';
import { encrypt, decrypt } from './crypto.helper';

export class CryptoTransformer implements ValueTransformer {
  to(value: string): string {
    return encrypt(value);
  }

  from(value: string): string {
    return decrypt(value);
  }
}

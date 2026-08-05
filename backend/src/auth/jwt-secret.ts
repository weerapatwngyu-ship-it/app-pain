import { ConfigService } from '@nestjs/config';

const INSECURE_PLACEHOLDERS = ['change-me', 'secret', 'changeme'];

/** Reads JWT_SECRET, refusing to start on a missing or placeholder value.
 * A known secret means anyone can mint a token for any account, so failing
 * loudly at boot is far safer than silently signing with a default. */
export function requireJwtSecret(config: ConfigService): string {
  const secret = config.get<string>('JWT_SECRET')?.trim();

  if (!secret || INSECURE_PLACEHOLDERS.includes(secret.toLowerCase()) || secret.length < 16) {
    throw new Error(
      'JWT_SECRET is missing, too short, or still set to a placeholder. ' +
        'Set it to a random string of at least 16 characters before starting the server.',
    );
  }
  return secret;
}

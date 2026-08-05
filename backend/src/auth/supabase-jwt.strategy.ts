import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { passportJwtSecret } from 'jwks-rsa';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from './auth.service';

/** Claims this app relies on from a Supabase-issued access token. */
export interface SupabaseJwtPayload {
  sub: string;
  email?: string;
  user_metadata?: { full_name?: string; name?: string; avatar_url?: string };
}

/** Verifies access tokens minted by Supabase Auth.
 *
 * Supabase publishes the public half of its signing keys as a JWKS document,
 * so tokens are checked locally against a cached key rather than by calling
 * Supabase on every request. Keys are matched by the token's `kid`, which is
 * what lets Supabase rotate them without a redeploy here. */
@Injectable()
export class SupabaseJwtStrategy extends PassportStrategy(Strategy, 'supabase-jwt') {
  constructor(
    config: ConfigService,
    private readonly authService: AuthService,
  ) {
    const supabaseUrl = config.get<string>('SUPABASE_URL')?.replace(/\/$/, '');
    if (!supabaseUrl) {
      throw new Error('SUPABASE_URL is required — set it to https://<project-ref>.supabase.co');
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      audience: 'authenticated',
      algorithms: ['ES256', 'RS256', 'HS256'],
      secretOrKeyProvider: passportJwtSecret({
        jwksUri: `${supabaseUrl}/auth/v1/.well-known/jwks.json`,
        cache: true,
        rateLimit: true,
      }),
    });
  }

  /** Supabase owns the identity; this app owns the profile. Map one to the
   * other, creating the local row (and patient record) on first sign-in. */
  async validate(payload: SupabaseJwtPayload) {
    if (!payload.sub) throw new UnauthorizedException('Token has no subject');

    const user = await this.authService.findOrCreateFromSupabase({
      supabaseUserId: payload.sub,
      email: payload.email ?? null,
      name: payload.user_metadata?.full_name ?? payload.user_metadata?.name ?? null,
    });

    return { userId: user.id, email: user.email, role: user.role };
  }
}

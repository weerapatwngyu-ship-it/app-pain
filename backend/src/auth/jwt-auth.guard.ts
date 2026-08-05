import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/// Authenticates against Supabase-issued access tokens. Kept under the
/// original name so every controller guarding a route stays unchanged.
@Injectable()
export class JwtAuthGuard extends AuthGuard('supabase-jwt') {}

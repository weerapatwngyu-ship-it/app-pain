import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared handles onto the Supabase client.
///
/// Repositories query Postgres directly — there is no server of this app's
/// own in between — so what a query may read or write is decided by the Row
/// Level Security policies in `supabase/schema.sql`, evaluated against the
/// signed-in user. Filters here are for shaping results, not for security.
SupabaseClient get db => Supabase.instance.client;

String? get currentUserId => db.auth.currentUser?.id;

/// Bucket holding avatars and doctor photos (public read, owner-only write).
const avatarsBucket = 'avatars';

import { createClient } from '@supabase/supabase-js';

// This is a browser publishable key, never a service-role or secret key.
const url = 'https://kjincyabqwqdmvcctsvq.supabase.co';
const publishableKey = 'sb_publishable_epVTDY45ypijPec0oWnFFQ_7C4VUtdS';

export const cloudClient = createClient(url, publishableKey, {
  auth: {
    flowType: 'pkce', detectSessionInUrl: true, persistSession: true, autoRefreshToken: true,
    // The dashboard uses the same Supabase project and GitHub Pages origin.
    // Keep its login independent from the game's optional account login.
    storageKey: 'seoul-gate-auth',
  },
});

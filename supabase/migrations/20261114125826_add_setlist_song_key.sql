-- Add a nullable per-Setlist-song key label.
-- Existing setlist_songs rows and global songs/chords data are unchanged.
ALTER TABLE public.setlist_songs
  ADD COLUMN IF NOT EXISTS song_key text;

-- Refresh PostgREST so the new nullable field is available to the UI.
NOTIFY pgrst, 'reload schema';

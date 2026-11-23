
-- ==========================================
-- Phase 4: Query Optimization Indexes
-- ==========================================

-- R23: Covering index for deep pagination
-- Supports ORDER BY started_at DESC
-- Includes columns needed by the SELECT query

CREATE INDEX IF NOT EXISTS idx_streams_started_at_covering
ON spotify.streams (started_at DESC)
INCLUDE (stream_id, user_id, track_id, ms_played);


-- R13: Partial index for public playlists
-- Helps NOT EXISTS find matching playlist IDs
-- NULL playlist IDs are excluded from this index

CREATE INDEX IF NOT EXISTS idx_streams_playlist_id_not_null
ON spotify.streams (playlist_id)
WHERE playlist_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tracks_album_disc_track_covering
ON spotify.tracks (album_id, disc_no, track_no)
INCLUDE (title, duration_ms, explicit);

CREATE INDEX IF NOT EXISTS idx_streams_user_started_at_covering
ON spotify.streams (user_id, started_at DESC)
INCLUDE (track_id, ms_played, platform);

CREATE INDEX IF NOT EXISTS idx_albums_artist_release_covering
ON spotify.albums (artist_id, release_date DESC)
INCLUDE (album_id, album_title, album_type);

CREATE INDEX IF NOT EXISTS idx_tracks_isrc_covering
ON spotify.tracks (isrc)
INCLUDE (track_id, title, album_id);

CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_track_covering
ON spotify.playlist_tracks (playlist_id, track_id);

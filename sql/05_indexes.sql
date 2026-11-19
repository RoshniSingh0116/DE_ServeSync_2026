
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

-- Spotify DBMS Project · Team 008
-- sql/02_load_data.sql

-- Purpose:
-- Loads all 10 CSV files into the spotify schema

\set ON_ERROR_STOP on
SET search_path TO spotify;


\copy spotify.artists FROM 'seed_data/artists.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.users FROM 'seed_data/users.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.albums FROM 'seed_data/albums.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.tracks FROM 'seed_data/tracks.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.playlists FROM 'seed_data/playlists.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.track_artists FROM 'seed_data/track_artists.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.playlist_tracks FROM 'seed_data/playlist_tracks.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.liked_tracks FROM 'seed_data/liked_tracks.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.artist_follows FROM 'seed_data/artist_follows.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy spotify.streams FROM 'seed_data/streams.csv' WITH (FORMAT CSV, HEADER TRUE)

ANALYZE;

SELECT 
    table_name,
    loaded_rows,
    expected_rows,
    CASE
        WHEN loaded_rows = expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (
    SELECT
        'artists' AS table_name,
        COUNT(*) AS loaded_rows,
        3000 AS expected_rows
    FROM spotify.artists

    UNION ALL

    SELECT
        'albums',
        COUNT(*),
        12000
    FROM spotify.albums

    UNION ALL

    SELECT
        'tracks',
        COUNT(*),
        67808
    FROM spotify.tracks

    UNION ALL

    SELECT
        'track_artists',
        COUNT(*),
        77489
    FROM spotify.track_artists

    UNION ALL

    SELECT
        'users',
        COUNT(*),
        30000
    FROM spotify.users

    UNION ALL

    SELECT
        'playlists',
        COUNT(*),
        10000
    FROM spotify.playlists

    UNION ALL

    SELECT
        'playlist_tracks',
        COUNT(*),
        120004
    FROM spotify.playlist_tracks

    UNION ALL

    SELECT
        'streams',
        COUNT(*),
        250000
    FROM spotify.streams

    UNION ALL

    SELECT
        'liked_tracks',
        COUNT(*),
        58533
    FROM spotify.liked_tracks

    UNION ALL

    SELECT
        'artist_follows',
        COUNT(*),
        69901
    FROM spotify.artist_follows
) AS row_counts
ORDER BY table_name;



SELECT
    SUM(row_count) AS total_loaded_rows,
    698735 AS expected_total_rows,
    CASE
        WHEN SUM(row_count) = 698735 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (
    SELECT COUNT(*) AS row_count FROM spotify.artists
    UNION ALL
    SELECT COUNT(*) FROM spotify.albums
    UNION ALL
    SELECT COUNT(*) FROM spotify.tracks
    UNION ALL
    SELECT COUNT(*) FROM spotify.track_artists
    UNION ALL
    SELECT COUNT(*) FROM spotify.users
    UNION ALL
    SELECT COUNT(*) FROM spotify.playlists
    UNION ALL
    SELECT COUNT(*) FROM spotify.playlist_tracks
    UNION ALL
    SELECT COUNT(*) FROM spotify.streams
    UNION ALL
    SELECT COUNT(*) FROM spotify.liked_tracks
    UNION ALL
    SELECT COUNT(*) FROM spotify.artist_follows
) AS all_counts;



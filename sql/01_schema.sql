CREATE SCHEMA IF NOT EXISTS spotify;

SET search_path TO spotify;


-- 1. USERS TABLE
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    country_code CHAR(2),
    birth_date DATE,
    subscription VARCHAR(30),
    created_at TIMESTAMPTZ,

    CHECK (email LIKE '%@%._%'),
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$')
);


-- 2. ARTISTS TABLE
CREATE TABLE artists (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(150) NOT NULL,
    country_code CHAR(2),
    primary_genre VARCHAR(100),
    is_verified BOOLEAN,
    monthly_listeners INT,
    created_at TIMESTAMPTZ,

    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
    CHECK (monthly_listeners IS NULL OR monthly_listeners >= 0)
);


-- 3. ALBUMS TABLE
CREATE TABLE albums (
    album_id INT PRIMARY KEY,
    artist_id INT NOT NULL,
    album_title VARCHAR(255) NOT NULL,
    album_type VARCHAR(30),
    release_date DATE,
    label VARCHAR(150),
    upc BIGINT,

    FOREIGN KEY (artist_id)
        REFERENCES artists(artist_id),

    CHECK (LENGTH(TRIM(album_title)) > 0),
    CHECK (
        album_type IS NULL OR
        album_type IN ('ALBUM', 'EP', 'SINGLE', 'COMPILATION')
    ),
    CHECK (upc IS NULL OR upc::TEXT ~ '^[0-9]{12}$')
);


-- 4. TRACKS TABLE
CREATE TABLE tracks (
    track_id INT PRIMARY KEY,
    album_id INT NOT NULL,
    disc_no INT,
    track_no INT,
    title VARCHAR(255) NOT NULL,
    duration_ms INT,
    explicit BOOLEAN,
    isrc VARCHAR(20),
    popularity INT,

    FOREIGN KEY (album_id)
        REFERENCES albums(album_id),

    CHECK (disc_no IS NULL OR disc_no >= 1),
    CHECK (track_no IS NULL OR track_no >= 1),
    CHECK (duration_ms IS NULL OR duration_ms > 0),
    CHECK (isrc IS NULL OR isrc ~ '^[A-Za-z0-9]{12}$'),
    CHECK (popularity IS NULL OR popularity BETWEEN 0 AND 100)
);


-- 5. PLAYLISTS TABLE
CREATE TABLE playlists (
    playlist_id INT PRIMARY KEY,
    owner_user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    is_public BOOLEAN,
    is_collaborative BOOLEAN,
    created_at TIMESTAMPTZ,

    FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id),

    CHECK (LENGTH(TRIM(name)) > 0)
);


-- 6. ARTIST_FOLLOWS TABLE
CREATE TABLE artist_follows (
    user_id INT NOT NULL,
    artist_id INT NOT NULL,
    followed_at TIMESTAMPTZ,

    PRIMARY KEY (user_id, artist_id),

    FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    FOREIGN KEY (artist_id)
        REFERENCES artists(artist_id)
);


-- 7. LIKED_TRACKS TABLE
CREATE TABLE liked_tracks (
    user_id INT NOT NULL,
    track_id INT NOT NULL,
    liked_at TIMESTAMPTZ,

    PRIMARY KEY (user_id, track_id),

    FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    FOREIGN KEY (track_id)
        REFERENCES tracks(track_id)
);


-- 8. PLAYLIST_TRACKS TABLE
CREATE TABLE playlist_tracks (
    playlist_id INT NOT NULL,
    position INT NOT NULL,
    track_id INT NOT NULL,
    added_by_user_id INT,
    added_at TIMESTAMPTZ,

    PRIMARY KEY (playlist_id, position),

    FOREIGN KEY (playlist_id)
        REFERENCES playlists(playlist_id),

    FOREIGN KEY (track_id)
        REFERENCES tracks(track_id),

    FOREIGN KEY (added_by_user_id)
        REFERENCES users(user_id),

    CHECK (position >= 1)
);


-- 9. TRACK_ARTISTS TABLE
CREATE TABLE track_artists (
    track_id INT NOT NULL,
    artist_id INT NOT NULL,
    role VARCHAR(50),

    PRIMARY KEY (track_id, artist_id),

    FOREIGN KEY (track_id)
        REFERENCES tracks(track_id),

    FOREIGN KEY (artist_id)
        REFERENCES artists(artist_id),

    CHECK (role IS NULL OR LENGTH(TRIM(role)) > 0)
);


-- 10. STREAMS TABLE
CREATE TABLE streams (
    stream_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    track_id INT NOT NULL,
    started_at TIMESTAMPTZ,
    ms_played INT,
    platform VARCHAR(50),
    source_type VARCHAR(50),
    playlist_id INT,
    skipped BOOLEAN,
    offline BOOLEAN,

    FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    FOREIGN KEY (track_id)
        REFERENCES tracks(track_id),

    FOREIGN KEY (playlist_id)
        REFERENCES playlists(playlist_id),

    CHECK (ms_played IS NULL OR ms_played >= 0)
);
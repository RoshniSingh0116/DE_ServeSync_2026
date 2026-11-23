-- PHASE 5: PARTITIONING EXPERIMENT
-- Monthly RANGE partitioning on started_at
-- Database: spotify_large

-- 1. Remove the previous test table, if it exists.
-- This does NOT delete the original spotify.streams table.
DROP TABLE IF EXISTS spotify.streams_partition_test CASCADE;


-- 2. Create the partitioned parent table.
CREATE TABLE spotify.streams_partition_test (
    stream_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ms_played INTEGER CHECK (ms_played IS NULL OR ms_played >= 0),
    platform VARCHAR(50),
    source_type VARCHAR(50),
    playlist_id INTEGER,
    skipped BOOLEAN,
    offline BOOLEAN,

    PRIMARY KEY (stream_id, started_at)
)
PARTITION BY RANGE (started_at);


-- 3. Create the January 2025 partition.
CREATE TABLE spotify.streams_partition_test_2025_01
PARTITION OF spotify.streams_partition_test
FOR VALUES FROM ('2025-01-01 00:00:00+00')
TO ('2025-02-01 00:00:00+00');


-- 4. Create the February 2025 partition.
CREATE TABLE spotify.streams_partition_test_2025_02
PARTITION OF spotify.streams_partition_test
FOR VALUES FROM ('2025-02-01 00:00:00+00')
TO ('2025-03-01 00:00:00+00');


-- 5. Insert sample records into the parent table.
-- PostgreSQL automatically routes each record
-- to the correct monthly partition.
INSERT INTO spotify.streams_partition_test
(stream_id, user_id, track_id, started_at, ms_played, platform)
VALUES
(900000001, 1038, 1001, '2025-01-10 10:00:00+00', 180000, 'web'),
(900000002, 1038, 1002, '2025-01-15 11:00:00+00', 200000, 'mobile'),
(900000003, 1038, 1003, '2025-02-10 12:00:00+00', 150000, 'web'),
(900000004, 1038, 1004, '2025-02-20 13:00:00+00', 210000, 'mobile');


-- 6. Verify the parent table and its partitions.
SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS total_records
FROM spotify.streams_partition_test
GROUP BY tableoid
ORDER BY partition_name;


-- 7. Check January partition pruning.
-- Only the January partition should be scanned.
EXPLAIN
SELECT *
FROM spotify.streams_partition_test
WHERE started_at >= '2025-01-01 00:00:00+00'
  AND started_at < '2025-02-01 00:00:00+00';


-- 8. Check February partition pruning.
-- Only the February partition should be scanned.
EXPLAIN
SELECT *
FROM spotify.streams_partition_test
WHERE started_at >= '2025-02-01 00:00:00+00'
  AND started_at < '2025-03-01 00:00:00+00';


-- 9. Display the partitioned table structure.
-- Run this command in the psql terminal, not pgAdmin's
-- SQL Query Tool.

-- \d+ spotify.streams_partition_test

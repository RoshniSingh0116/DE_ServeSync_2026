# Phase 5: Scalability Report

**Database:** PostgreSQL 18  
**Seed database:** `spotify_db`  
**Large database:** `spotify_large`  
**Schema:** `spotify`  
**Large dataset:** Approximately 20× the seed dataset  
**Benchmark method:** Average execution time of 3 runs for each query

---

## 1. Results table

The optimized queries from Phase 4 were benchmarked on the seed dataset. The large dataset was then benchmarked using the optimized queries after applying the additional indexes.

The growth factor is calculated as:

\[
\text{Growth}=\frac{\text{Optimized time on large dataset}}{\text{Optimized time on seed dataset}}
\]

All execution times are in milliseconds (ms). The target is based on the average of 3 runs.

| Query | Target (ms) | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what we changed |
| ----- | ----------- | ---------------------- | ----------------------- | --------------------- | ------------- | ----------------------- |
| R01 | < 250 | 3.934 | 27.591 | 7.01× | Yes | — |
| R02 | < 5 | 1.809 | 0.193 | 0.11× | Yes | Added a covering composite index on `(album_id, disc_no, track_no)` to avoid a sequential scan and sorting. |
| R03 | < 250 | 21.952 | 168.595 | 7.68× | Yes | — |
| R04 | < 5 | 5.371 | 0.465 | 0.09× | Yes | Added a covering composite index on `(user_id, started_at DESC)` to avoid scanning and sorting the streams table. |
| R05 | < 5 | 0.143 | 1.185 | 8.29× | Yes | — |
| R06 | < 5 | 0.043 | 0.213 | 4.95× | Yes | — |
| R07 | < 5,000 | 7.905 | 79.064 | 10.00× | Yes | — |
| R08 | < 250 | 9.814 | 114.287 | 11.65× | Yes | — |
| R09 | < 250 | 5.591 | 0.769 | 0.14× | Yes | — |
| R10 | < 5,000 | 10.379 | 147.097 | 14.17× | Yes | — |
| R11 | < 5 | 0.495 | 0.634 | 1.28× | Yes | Added a covering index on `(artist_id, release_date DESC)` for faster album lookups by followed artists and release date. |
| R12 | < 5,000 | 8.053 | 80.467 | 9.99× | Yes | — |
| R13 | < 250 | 2.302 | 43.937 | 19.09× | Yes | — |
| R14 | < 5,000 | 8.044 | 93.927 | 11.68× | Yes | — |
| R15 | < 250 | 1.971 | 23.493 | 11.92× | Yes | — |
| R16 | < 5,000 | 9.721 | 124.340 | 12.79× | Yes | — |
| R17 | < 5,000 | 3.670 | 106.998 | 29.15× | Yes | — |
| R18 | < 5,000 | 14.517 | 192.823 | 13.28× | Yes | — |
| R19 | < 5,000 | 32.378 | 813.176 | 25.12× | Yes | — |
| R20 | < 5,000 | 61.483 | 1611.201 | 26.21× | Yes | — |
| R21 | < 5 | 2.691 | 0.132 | 0.05× | Yes | Added a covering index on `tracks(isrc)` to make ISRC lookups faster. |
| R22 | < 250 | 22.404 | 252.572 | 11.27× | **No** | Added a composite index on `(playlist_id, track_id)`. It removed the incremental sort, but the query still scans and groups all playlist-track rows. The final average remains slightly above the target. |
| R23 | < 5,000 | 10.938 | 11.469 | 1.05× | Yes | — |
| R24 | < 5,000 | 11.822 | 95.591 | 8.09× | Yes | — |
| R25 | < 250 | 17.360 | 140.571 | 8.10× | Yes | — |
| W01 | < 5 | 0.570 | 1.008 | 1.77× | Yes | — |
| W02 | < 5 | 0.468 | 0.916 | 1.96× | Yes | — |
| W03 | < 5 | 0.519 | 0.778 | 1.50× | Yes | — |
| W04 | < 3,000 | 31.173 | 918.740 | 29.47× | Yes | — |
| W05 | < 250 | 8.411 | 134.294 | 15.97× | Yes | — |

### 1.1 Performance target summary

| Query group | Number of queries | Passed | Failed | Target |
| ----------------------------------- | ----------------- | ------ | ------ | -------------- |
| Real-time / listener-facing | 9 | 9 | 0 | Under 5 ms |
| Interactive artist tools and search | 9 | 8 | 1 | Under 250 ms |
| Reports and analytics | 11 | 11 | 0 | Under 5,000 ms |
| Batch jobs | 1 | 1 | 0 | Under 3,000 ms |
| **Total** | **30** | **29** | **1** | — |

**Result:** 29 out of 30 queries meet their performance targets, giving a pass rate of approximately **96.67%**.

R22 is the only query that misses its target. Its average is 252.572 ms, which is 2.572 ms above the required 250 ms.

W05 is included in the interactive artist tools and search group. Its average is 134.294 ms, so it meets the under-250-ms target.

### 1.2 R23: OFFSET pagination

R23 continues to use `OFFSET 200000`. We did not replace it with keyset pagination.

The query takes 10.938 ms on the seed dataset and 11.469 ms on the large dataset, resulting in only 1.05× growth.

OFFSET pagination can become slower for deeper pages because PostgreSQL must still read and skip the preceding rows.

For a production application, keyset pagination would be a better approach. For example:

```sql
WHERE started_at < :last_started_at
```

The `last_started_at` value would be the timestamp of the last row on the previous page. If multiple streams have the same timestamp, `stream_id` can be used as a tie-breaker.

---

## 2. Growth analysis

The large dataset contains approximately 20 times as many records as the seed dataset.

The growth in execution time is not the same for every query. Some queries use indexes to retrieve a small number of records, while others scan and aggregate a large portion of a table.

For this analysis, the queries are grouped using the following ranges:

- **Under 10×:** Grew less than the overall 20× increase in data.
- **10× to 20×:** Grew substantially, approximately within this range.
- **More than 20×:** Grew faster than the dataset.

### 2.1 How much the data grew

| Table | Rows in seed dataset | Rows in large dataset |
| --------------- | -------------------- | --------------------- |
| artists | 3,000 | 60,000 |
| users | 30,000 | 600,000 |
| albums | 12,000 | 240,000 |
| tracks | 67,808 | 1,360,381 |
| playlists | 10,000 | 200,000 |
| track_artists | 77,489 | 1,554,720 |
| playlist_tracks | 120,004 | 2,400,008 |
| liked_tracks | 58,533 | 1,171,457 |
| artist_follows | 69,901 | 1,399,801 |
| streams | 250,000 | 5,000,000 |

The total number of rows increased from approximately 698,735 to 13,986,367, which is approximately a 20× increase.

### 2.2 Queries that stayed approximately the same (under 10×)

These queries grew less than the overall 20× increase in the dataset.

| Query | Seed time (ms) | Large time (ms) | Growth |
| ----- | -------------- | --------------- | ------ |
| R01 | 3.934 | 27.591 | 7.01× |
| R02 | 1.809 | 0.193 | 0.11× |
| R03 | 21.952 | 168.595 | 7.68× |
| R04 | 5.371 | 0.465 | 0.09× |
| R05 | 0.143 | 1.185 | 8.29× |
| R06 | 0.043 | 0.213 | 4.95× |
| R09 | 5.591 | 0.769 | 0.14× |
| R11 | 0.495 | 0.634 | 1.28× |
| R12 | 8.053 | 80.467 | 9.99× |
| R21 | 2.691 | 0.132 | 0.05× |
| R23 | 10.938 | 11.469 | 1.05× |
| R24 | 11.822 | 95.591 | 8.09× |
| R25 | 17.360 | 140.571 | 8.10× |
| W01 | 0.570 | 1.008 | 1.77× |
| W02 | 0.468 | 0.916 | 1.96× |
| W03 | 0.519 | 0.778 | 1.50× |

**Why did they stay relatively fast?**

Many of these queries use indexes to find a particular user, album, artist, playlist, or track instead of scanning the entire table.

An indexed lookup generally grows more slowly than a full-table scan. A B-tree lookup has approximately logarithmic growth, rather than having to process every row.

Some queries, including R02, R04, R09 and R21, are even faster on the large dataset because additional indexes were added during Phase 5.

For example, R04 improved from 5.371 ms on the seed dataset to 0.465 ms on the large dataset after adding an index on the user's ID and stream timestamp.

R23 also remained nearly constant in this benchmark. However, OFFSET pagination can become slower for deeper pages because PostgreSQL still has to skip the preceding rows.

### 2.3 Queries that grew approximately with the dataset (10× to 20×)

| Query | Seed time (ms) | Large time (ms) | Growth |
| ----- | -------------- | --------------- | ------ |
| R07 | 7.905 | 79.064 | 10.00× |
| R08 | 9.814 | 114.287 | 11.65× |
| R10 | 10.379 | 147.097 | 14.17× |
| R13 | 2.302 | 43.937 | 19.09× |
| R14 | 8.044 | 93.927 | 11.68× |
| R15 | 1.971 | 23.493 | 11.92× |
| R16 | 9.721 | 124.340 | 12.79× |
| R18 | 14.517 | 192.823 | 13.28× |
| R22 | 22.404 | 252.572 | 11.27× |
| W05 | 8.411 | 134.294 | 15.97× |

**Why did they grow?**

These queries perform more work as the underlying tables become larger. Some read a substantial portion of a table, join multiple tables, or group records.

For example:

- **R07:** Processes stream information and joins it with artist-related data. More stream records mean more records to process.
- **R10:** Performs aggregation on stream data. The large dataset contains substantially more stream records to aggregate.
- **R13:** Checks playlist and stream relationships. More playlists and stream records increase the work.
- **R14:** Processes playlist-related records, so its execution time increases as `playlist_tracks` grows.
- **R16:** Processes stream activity over a time period. A larger stream table means more records may need to be examined.
- **R18:** Performs analytical processing on streams, which requires more work as the stream table grows.
- **W05:** Performs a write operation involving track and playlist relationships. More relationship records can increase the amount of work.

These queries still meet their required performance targets, although their execution times have increased.

### 2.4 Queries that grew more than 20×

| Query | Seed time (ms) | Large time (ms) | Growth |
| ----- | -------------- | --------------- | ------ |
| R17 | 3.670 | 106.998 | 29.15× |
| R19 | 32.378 | 813.176 | 25.12× |
| R20 | 61.483 | 1611.201 | 26.21× |
| W04 | 31.173 | 918.740 | 29.47× |

These queries grew more than the overall dataset size.

**Possible reasons from their workload and execution plans:**

- **R17:** Processes user and stream information. A larger user table and stream table increase the work required for joins and aggregation.
- **R19:** Performs analytical processing involving streams, tracks and artists. The larger dataset increases the number of records involved in the joins.
- **R20:** Processes a large amount of stream and user information. Aggregation and join operations become more expensive when the number of records increases.
- **W04:** Performs a batch operation involving artist and track-artist relationships. It has to process many more relationship records and update artist information.

All four still meet their assigned targets. However, these queries deserve attention because their execution times are growing faster than the dataset.

The growth factor alone does not prove that a query has a bad execution plan. Cache state, the number of rows returned, index usage, sorting and join strategies also affect the measured time.

---

## 3. What broke at scale and how it was fixed

During Phase 5, additional indexes were introduced to improve queries that were doing unnecessary sequential scans or sorting.

R22 was also investigated because it was the only query that missed its target.

### 3.1 R02: Album track listing

**Problem:** The query had to find tracks belonging to an album and return them in disc and track order.

Before optimization, PostgreSQL used a parallel sequential scan on `tracks` and then sorted the matching rows.

**Index added:**

```sql
CREATE INDEX IF NOT EXISTS idx_tracks_album_disc_track_covering
ON spotify.tracks (album_id, disc_no, track_no)
INCLUDE (title, duration_ms, explicit);
```

**Plan before:**

- Parallel sequential scan on `tracks`.
- Filtered rows using `album_id`.
- Performed a sort on `disc_no` and `track_no`.
- Execution time: 25.207 ms in the inspected plan.

**Plan after:**

- Used an Index Only Scan through `idx_tracks_album_disc_track_covering`.
- No separate sort was required.
- Heap Fetches: 0.
- Execution time: 0.132 ms in the inspected plan.

The final three-run average on the large dataset was 0.193 ms, comfortably below the 5 ms target.

### 3.2 R04: Recently played tracks

**Problem:** The query retrieves the most recent streams for a particular user. Before optimization, PostgreSQL had to scan a large part of the streams table and sort the matching records.

**Index added:**

```sql
CREATE INDEX IF NOT EXISTS idx_streams_user_started_at_covering
ON spotify.streams (user_id, started_at DESC)
INCLUDE (track_id, ms_played, platform);
```

**Plan before:**

- Parallel sequential scan on `streams`.
- Filtered by `user_id`.
- Sorted matching records by `started_at DESC`.
- Performed track lookups.
- Execution time: 71.915 ms in the inspected plan.

**Plan after:**

- Used an Index Only Scan on `idx_streams_user_started_at_covering`.
- Avoided the separate sort.
- Used the track primary key for track details.
- Heap Fetches: 0.
- Execution time: 0.190 ms in the inspected plan.

The final large-dataset average was 0.465 ms, below the 5 ms target.

### 3.3 R11: Followed artists' latest albums

**Problem:** The query joins followed artists with their albums and filters albums by release date. The previous plan performed a parallel sequential scan on albums.

**Index added:**

```sql
CREATE INDEX IF NOT EXISTS idx_albums_artist_release_covering
ON spotify.albums (artist_id, release_date DESC)
INCLUDE (album_id, album_title, album_type);
```

**Plan before:**

- Parallel sequential scan on `albums`.
- Filtered albums using `release_date`.
- Joined with `artist_follows`.
- Looked up artist details.
- Execution time: 9.216 ms in the inspected plan.

**Plan after:**

- Index Only Scan on `artist_follows`.
- Index Only Scan using `idx_albums_artist_release_covering`.
- Artist primary-key lookup.
- Execution time: 0.137 ms in the inspected plan.

The final large-dataset average was 0.634 ms, below the 5 ms target.

### 3.4 R21: ISRC lookup

**Problem:** The query searches for a track using its ISRC. Before optimization, PostgreSQL performed a parallel sequential scan on the tracks table.

**Index added:**

```sql
CREATE INDEX IF NOT EXISTS idx_tracks_isrc_covering
ON spotify.tracks (isrc)
INCLUDE (track_id, title, album_id);
```

**Plan before:**

- Parallel sequential scan on `tracks`.
- Filtered using the ISRC value.
- Execution time: 34.276 ms in the inspected plan.

**Plan after:**

- Used an Index Only Scan on `idx_tracks_isrc_covering`.
- Heap Fetches: 0.
- Execution time: 0.036 ms in the inspected plan.

The final large-dataset average was 0.132 ms, below the 5 ms target.

**Note:** The particular ISRC used by R21 did not match a row in the large dataset. The timing demonstrates a fast lookup, not a successful track match.

### 3.5 R22: Duplicate tracks in playlists

**Problem:** R22 identifies tracks that appear more than once in the same playlist.

The query groups records from `playlist_tracks` by `playlist_id` and `track_id`, then keeps groups with more than one occurrence.

The large dataset contains approximately 2.4 million rows in `playlist_tracks`. The query has to process a large number of records before it can identify duplicate groups.

**Index added:**

```sql
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_track_covering
ON spotify.playlist_tracks (playlist_id, track_id);
```

**Plan before:**

- Index Scan using `playlist_tracks_pkey`.
- Incremental Sort on playlist and track identifiers.
- GroupAggregate to identify duplicates.
- Final Sort by duplicate count and playlist.
- Execution time in the inspected plan: 509.592 ms.

**Plan after:**

- Index Only Scan using `idx_playlist_tracks_playlist_track_covering`.
- The incremental sort was eliminated.
- GroupAggregate and final sorting were still required.
- Execution time in the inspected plan: 263.322 ms.

The final three-run average was 252.572 ms.

**Result:** The additional index improved the query, but it did not fully meet the target. The required target is under 250 ms, and the final average is 2.572 ms above it.

Therefore, R22 is recorded as a failed target in this report. We should not claim that the index completely fixed the problem.

### 3.6 Summary of changes

| Query | Main change | Result |
| ----- | ------------------------------------------------------------------ | ------------------------------------------ |
| R02 | Added composite covering index on album and track ordering columns | Passed |
| R04 | Added composite covering index on user and stream timestamp | Passed |
| R11 | Added composite covering index on artist and release date | Passed |
| R21 | Added covering index on ISRC | Passed |
| R22 | Added composite index on playlist and track identifiers | Improved, but still narrowly misses target |

No PostgreSQL server configuration settings were changed during these optimizations.

---

## 4. Storage analysis

Storage is an important part of scalability because increasing the number of rows also increases the space required by tables and their indexes.

The total database size should be measured using `pg_database_size()`. Table and index sizes should be measured separately to understand how much space is used by the actual data and by indexes.

The following measurements are from the project's earlier storage checks.

### 4.1 Overall database storage

| Storage measurement | Seed (`spotify_db`) | Large (`spotify_large`) |
| --------------------------- | ---------------------- | ----------------------- |
| Total database size | 71 MB | 1,928 MB (approximately 1.88 GB) |

The large database uses approximately 27.15× the storage of the seed database. This is higher than the 20× increase in row count because indexes and database storage overhead also contribute to total size.

### 4.2 Table-wise and index-wise storage

| Table | Seed table size | Seed index size | Large table size | Large index size | Large total |
| --------------- | --------------- | --------------- | ---------------- | ---------------- | ------------ |
| streams | 20 MB | 5496 kB | 399 MB | 555 MB | 954 MB |
| playlist_tracks | 6120 kB | 2632 kB | 120 MB | 103 MB | 222 MB |
| tracks | 5856 kB | 1504 kB | 115 MB | 186 MB | 300 MB |
| users | 2768 kB | 2888 kB | 55 MB | 60 MB | 115 MB |
| track_artists | 3432 kB | 1712 kB | 67 MB | 33 MB | 101 MB |
| artist_follows | 3024 kB | 1552 kB | 59 MB | 30 MB | 89 MB |
| liked_tracks | 2536 kB | 1296 kB | 50 MB | 25 MB | 75 MB |
| albums | 1000 kB | 280 kB | 20 MB | 18 MB | 39 MB |
| playlists | 648 kB | 240 kB | 13 MB | 4408 kB | 17 MB |
| artists | 232 kB | 152 kB | 4648 kB | 2648 kB | 7328 kB |

*Note: Values are displayed in their original rounded MB/kB units. The total database size also includes database objects and overhead not represented by these selected table rows. Therefore, adding the displayed rounded table totals will not necessarily equal the complete database size.*

### 4.3 Storage observations

The large dataset contains approximately 20 times more records than the seed dataset. Therefore, table storage increases substantially.

Indexes also require storage. Although they improve query performance, every index takes additional disk space and must be maintained when records are inserted, updated or deleted.

The `streams` table deserves particular attention because it contains 5 million records in the large dataset. Its table and index storage together account for approximately 954 MB in the measurements.

As the application grows, this table is likely to become one of the most important tables to manage for storage and maintenance.

---

## 5. Architecture for 100× scalability

For this section, 100× means 100 times the original seed dataset.

The current large dataset is approximately 20× the seed dataset. Therefore, 100× represents approximately five times the current large dataset.

At this scale, simply adding more indexes may not be sufficient. The database architecture should also support partitioning, sharding, read replicas, caching and regular maintenance.

### 5.1 Partitioning

**Recommended table:** `streams`

**Recommended partitioning method:** RANGE partitioning on `started_at`, preferably monthly.

**Why?**

The streams table grows continuously as users listen to music. Most analytics queries work with a particular time period, such as the latest 28 days or a particular month.

Range partitioning allows PostgreSQL to divide the streams table into smaller monthly partitions.

For example:

```sql
CREATE TABLE spotify.streams_partitioned (
    stream_id BIGINT NOT NULL,
    user_id INTEGER,
    track_id INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ms_played INTEGER NOT NULL,
    platform VARCHAR(7) NOT NULL,
    playlist_id INTEGER,

    PRIMARY KEY (stream_id, started_at)
)
PARTITION BY RANGE (started_at);
```

The column definitions and remaining constraints should be copied from the actual `spotify.streams` table before using this as a complete replacement schema.

Example monthly partition:

```sql
CREATE TABLE spotify.streams_2026_11
PARTITION OF spotify.streams_partitioned
FOR VALUES FROM ('2026-11-01 00:00:00+00')
TO ('2026-12-01 00:00:00+00');
```

A new partition should be created before the next month begins. A default partition can also be used to catch rows that do not match an existing range.

**Partition pruning**

Suppose a query requests streams from November 2026:

```sql
EXPLAIN
SELECT *
FROM spotify.streams_partitioned
WHERE started_at >= '2026-11-01 00:00:00+00'
  AND started_at < '2026-12-01 00:00:00+00';
```

PostgreSQL can scan only the November partition instead of scanning every monthly partition. This is called partition pruning.

The actual plan should be checked with `EXPLAIN` after creating and loading the partitioned table.

**Important primary-key rule**

In PostgreSQL, a PRIMARY KEY or UNIQUE constraint on a partitioned table must include all partition-key columns.

Since the partition key is `started_at`, the primary key must include `started_at`, for example:

```sql
PRIMARY KEY (stream_id, started_at)
```

This means PostgreSQL cannot enforce global uniqueness of `stream_id` alone through that partitioned primary key. If global uniqueness is required, it must be handled separately.

Partitioning is useful for managing large time-based data, archiving old records and reducing the amount of data scanned by time-filtered queries. However, it does not automatically make every query faster. Queries that do not filter by `started_at` may need to access multiple partitions.

**Our Phase 5 experiment**

We tested monthly range partitioning using a separate table named `spotify.streams_partition_test`.

We created two monthly partitions for January and February 2025 and inserted four synthetic records. The records were automatically routed to their corresponding partitions.

We also used `EXPLAIN` to verify that queries with UTC-aligned timestamp boundaries scanned only the relevant monthly partition.

This confirmed partition routing and partition pruning. However, the experiment was not a benchmark of the original 5-million-row `streams` table, so it does not establish a measured performance improvement on that table.

### 5.2 Sharding

Sharding means dividing data across multiple database servers.

If the database becomes too large for one server to handle efficiently, streams could be distributed across multiple shards.

**Recommended sharding key:** `user_id`.

**Why shard by user?**

Many listener-facing operations are related to one user:

- Recently Played
- Liked Songs
- User playlist operations
- User listening history

If all records for a user are stored on the same shard, these operations can be handled by one database server.

**What happens to artist and analytics queries?**

Queries that need data from all users become cross-shard queries.

For example:

- Artist listening statistics
- Popular tracks
- Total streams
- Monthly listener reports
- Overall platform analytics

The application or a query coordinator would need to collect partial results from each shard and combine them.

Counts and sums can often be combined by adding partial results. More complicated operations, such as global ranking or distinct-user calculations, require additional coordination.

Sharding by time is less suitable for the entire workload because all new streams would go to the newest time shard. Time-based partitioning inside a database is a better first step for managing this data.

### 5.3 Read replicas and caching

Read replicas are additional database servers that receive replicated data from the primary database. They can handle read-heavy queries and reduce the workload on the primary.

| Destination | Queries | Reason |
| ---------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Primary database | W01, W02, W03, W04, W05 | These queries perform write operations. |
| Primary database | R04, R05, R06 | These are user-facing queries where users should immediately see their own recent changes. |
| Read replica | R01, R03, R08, R09, R11, R15, R21 | Artist pages, searches and other read operations can tolerate a small replication delay. |
| Read replica | R07, R10, R12, R13, R14, R16, R17, R18, R19, R20, R22, R23, R24, R25 | These are heavier reports and analytics queries that should not compete with listener-facing operations on the primary. |

**Caching candidates**

Frequently requested information that does not change very often can be cached.

Possible candidates include:

- Popular track and artist information.
- Frequently accessed artist pages.
- Repeated search results.
- Dashboard statistics.
- Frequently requested analytics results.

Caching can reduce repeated database reads. However, cached information must be refreshed when the underlying data changes.

Writes must go to the primary database. Read replicas may have replication lag, so queries that need to show a user's latest changes should continue to use the primary.

These are proposed architectural improvements and have not been benchmarked as part of the current Phase 5 measurements.

### 5.4 Maintenance

As the streams table grows, regular maintenance becomes important.

**1. VACUUM and ANALYZE**

PostgreSQL uses VACUUM to clean up dead tuples and maintain table visibility information. ANALYZE collects statistics that help the query planner select appropriate execution plans.

After large data loads, run:

```sql
VACUUM ANALYZE spotify.streams;
```

Regular maintenance helps keep query plans efficient, particularly for large tables and index-only scans.

**2. Autovacuum**

Autovacuum should be monitored to make sure that large tables are maintained regularly.

The streams table should be monitored because it receives continuous inserts and grows faster than many other tables.

**3. Archiving old streams**

Older streams may not need to remain in the main online database forever.

If monthly partitions are used, older partitions can be detached and archived. This reduces the amount of active data that the main database needs to manage.

**4. Summary tables**

Frequently requested reports can use precomputed summary tables.

For example, daily stream counts by track, artist or platform can be calculated periodically rather than scanning millions of stream records for every dashboard request.

The summary tables must be refreshed correctly whenever new data is processed.

**5. Index maintenance**

Indexes improve read performance but increase storage and write costs. Index usage should be monitored so that unnecessary indexes do not consume disk space or slow down insert operations.

---

## 6. Conclusion

The Phase 5 benchmark shows that the database handles a dataset approximately 20 times larger than the seed dataset while meeting most of the required performance targets.

Out of 30 queries, **29 meet their assigned targets**, giving a pass rate of approximately **96.67%**. The only query that misses its target is R22, which takes an average of 252.572 ms against the required under-250-ms target.

Additional indexes improved R02, R04, R11 and R21 significantly. The composite index added for R22 also improved its execution plan, but the query still needs further optimization to meet the target.

The growth analysis shows that index-based queries generally perform well as the dataset grows. Queries that scan, join, sort or aggregate large amounts of data show higher growth and should be monitored as the database becomes larger.

The storage analysis also shows that the large database requires substantially more disk space than the seed database. The `streams` table and its indexes account for a significant portion of the measured storage.

For future scalability, the database can benefit from:

1. Monthly range partitioning of the streams table.
2. Sharding by user if one database server becomes insufficient.
3. Read replicas for read-heavy queries.
4. Caching for frequently requested information.
5. Regular VACUUM, ANALYZE and index maintenance.
6. Summary tables for expensive analytical queries.

**Is the database ready for the next stage?**

The current results show that the database is performing well at approximately 20× the seed dataset. However, it is not yet possible to claim that it is fully ready for 100× scale. R22 still needs optimization, and the proposed architecture changes need to be tested at a larger scale.

The remaining risks are the increasing cost of analytical queries, storage growth, index maintenance overhead and the possibility that queries that currently meet their targets may exceed them at 100×.

Overall, Phase 5 demonstrates that the database can handle substantial data growth while meeting most of its defined performance requirements. It also identifies the areas that need attention before moving to a much larger production workload.
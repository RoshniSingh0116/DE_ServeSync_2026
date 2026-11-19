

# Phase 3 — Baseline Query Timings

## Benchmark method

The unchanged `queries/workload_30.sql` was executed against the Phase 2 seed database using PostgreSQL 18.6.

The benchmark helper executed each query three times using `EXPLAIN (ANALYZE, BUFFERS)`. Write queries W01–W05 were executed inside `BEGIN` and `ROLLBACK` so that benchmark changes did not persist in the database.


Raw execution plans for all three runs are stored in `benchmarks/results/baseline/`. The machine-readable averages and scan information are available in `benchmarks/results/baseline/summary.csv`.

The scan types and reasons below are based on the observed execution plans.

## Baseline Benchmark Results with Scan Types and Reasons

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan Type | Reason |
|---|---|---:|---:|---:|---:|---|---|
| R01: Artist page: artist 33's 10 most-streamed tracks in the last 28 days | READ | 34.190 | 9.182 | 8.300 | 17.224 | Parallel Seq Scan (`streams`); Seq Scan (`track_artists`); Index Scan (`tracks_pkey`) | Reads many stream and artist-track records, then joins, groups and sorts them to find the artist's top 10 tracks. |
| R02: Album page: tracklist of album 1469 | READ | 4.533 | 1.684 | 1.737 | 2.651 | Seq Scan (`tracks`) | Reads all 67,808 tracks to find the 14 tracks belonging to the selected album, then sorts the results. |
| R03: Search: tracks whose title contains "love", most popular first | READ | 22.001 | 20.665 | 21.147 | 21.271 | Seq Scan (`tracks`) | `ILIKE '%love%'` searches inside titles, so PostgreSQL reads the entire tracks table and sorts matching rows by popularity. |
| R04: Recently played: user 1038's last 50 streams | READ | 6.024 | 5.192 | 5.157 | 5.458 | Parallel Seq Scan (`streams`); Index Scan (`tracks_pkey`) | Scans the large streams table to find one user's listening history, retrieves track details using the primary-key index, and sorts the latest 50. |
| R05: Playlist page: playlist 501 in order, with every artist on each track | READ | 3.611 | 0.125 | 0.131 | 1.289 | Index Scan (`playlist_tracks_pkey`, `tracks_pkey`, `track_artists_pkey`, `artists_pkey`) | Uses primary-key indexes to retrieve a small number of playlist tracks and artist details. Very fast because few rows are involved. |
| R06: Liked Songs: user 1038's liked tracks, newest first | READ | 0.665 | 0.042 | 0.041 | 0.249 | Index Scan (`liked_tracks_pkey`, `tracks_pkey`) | Uses indexes to find the user's liked tracks and retrieve their details. Only two liked tracks were found. |
| R07: Royalties: streams of 30 seconds or more per artist in June 2026, top 20 | READ | 13.175 | 10.618 | 10.908 | 11.567 | Parallel Seq Scan (`streams`); Parallel Index Only Scan (`track_artists_pkey`) | Reads many streams, joins them with artist-track records, and groups and sorts the results to find the top artists. |
| R08: Spotify for Artists: skip rate of each of artist 33's tracks | READ | 11.602 | 10.083 | 10.448 | 10.711 | Parallel Seq Scan (`streams`); Seq Scan (`track_artists`); Index Scan (`tracks_pkey`) | Reads large tables, joins listening records with artist information, and groups the results to calculate skip rates. |
| R09: Wrapped 2025: user 1038's top 5 artists by minutes listened | READ | 6.011 | 5.529 | 5.906 | 5.815 | Parallel Seq Scan (`streams`); Index Scan (`track_artists_pkey`, `artists_pkey`) | Scans streams to find one user's listening activity in 2025, then uses indexes to retrieve artist details and calculate the top artists. |
| R10: Platform analytics: daily streams per platform in June 2026 | READ | 11.147 | 10.958 | 10.342 | 10.816 | Parallel Seq Scan (`streams`) | Reads the streams table, filters listening activity from June 2026, then sorts and groups the matching records by date. |
| R11: Release Radar: 2026 releases by artists user 1038 follows | READ | 2.424 | 0.479 | 0.454 | 1.119 | Seq Scan (`albums`); Index Only Scan (`artist_follows_pkey`); Index Scan (`artists_pkey`) | Scans the relatively small albums table, while indexed lookups retrieve followed artists. Only nine final records are returned. |
| R12: Compliance: explicit tracks streamed by users who were under 18 at the time | READ | 21.339 | 18.574 | 18.623 | 19.512 | Parallel Seq Scan (`streams`); Seq Scan (`tracks`, `users`) | Reads multiple tables, joins streams with tracks and users, applies the age filter, and sorts the results to find the latest 200 records. |
| R13: Curation team: public playlists that have never been played | READ | 22.577 | 21.511 | 21.435 | 21.841 | Seq Scan (`playlists`, `streams`); Hashed SubPlan | Reads all streams to build a hashed list of played playlist IDs and scans playlists to find public playlists that have never been played. |
| R14: Collaborative playlists: number of different people who added tracks | READ | 9.431 | 7.853 | 7.988 | 8.424 | Seq Scan (`playlist_tracks`, `playlists`); Hash Join | Scans both tables, joins collaborative playlists with their tracks, groups the results, counts contributors and tracks, and sorts the top 50. |
| R15: Fans also like: artists most followed by the followers of artist 33 | READ | 6.312 | 1.878 | 1.840 | 3.343 | Seq Scan (`artist_follows`); Index Only Scan (`artist_follows_pkey`); Index Scan (`artists_pkey`) | Scans artist follows to find followers of the selected artist, then uses indexes to check their other follows and retrieve artist details. |
| R16: Artist profiles: distinct listeners of every artist in the last 28 days | READ | 17.172 | 16.824 | 17.505 | 17.167 | Seq Scan (`streams`, `track_artists`); Hash Join | Reads two large tables, joins streams with artist-track records, groups by artist and user, and calculates distinct listeners before sorting. |
| R17: Growth: free users with 4+ streams in June 2026 | READ | 10.980 | 10.990 | 10.836 | 10.935 | Seq Scan (`streams`, `users`); Hash Join; HashAggregate | Reads all streams and users, joins them, counts listening activity for each user, filters users with at least four streams, and sorts the results. |
| R18: Platform analytics: share of offline listening per platform | READ | 14.928 | 14.705 | 14.540 | 14.724 | Parallel Seq Scan (`streams`); Partial HashAggregate; Gather Merge; Finalize GroupAggregate | Reads the entire streams table, calculates platform-wise counts using parallel aggregation, combines partial results, and sorts the final output. |
| R19: Verified artists report: total streams and the latest stream of every verified artist | READ | 8596.590 | 8687.842 | 8707.169 | 8663.867 | Seq Scan (`artists`); repeated Seq Scans (`streams`, `track_artists`) in correlated subplans | Slowest query. For each of the 334 verified artists, correlated subqueries repeatedly scan large tables, join and aggregate the data, then sort the results. |
| R20: Listening patterns: streams per hour of the day per country | READ | 150.483 | 150.155 | 145.449 | 148.696 | Seq Scan (`streams`, `users`); Hash Join; External Merge Sort | Reads and joins all streams and users, then sorts 250,000 records. The sort spills to temporary disk because it does not fit in available sort memory. |
| R21: Rights management: look up a recording by its ISRC code | READ | 2.809 | 2.646 | 2.648 | 2.701 | Seq Scan (`tracks`); Index Scan (`albums_pkey`) | Reads all tracks to find the matching ISRC, then uses the album primary-key index to retrieve album details. |
| R22: Playlist hygiene: playlists that contain the same track more than once | READ | 22.988 | 22.315 | 21.888 | 22.397 | Seq Scan (`playlist_tracks`); HashAggregate; Sort | Reads all playlist-track records, groups duplicate playlist-track combinations, and sorts the results. The aggregation uses multiple batches and temporary disk space. |
| R23: Support console: all streams, newest first, page 8,001 (25 per page) | READ | 43.946 | 44.857 | 44.624 | 44.476 | Seq Scan (`streams`); External Merge Sort | Reads all 250,000 streams and sorts them by listening time. The sort spills to temporary disk before returning the latest 25 records. |
| R24: Label report: average track length and explicit share per album type | READ | 11.674 | 11.417 | 11.508 | 11.533 | Seq Scan (`tracks`, `albums`); Hash Join; HashAggregate | Reads both tables, joins tracks with albums, groups the results by album type, and calculates the counts. |
| R25: Discovery: tracks released in the last 30 days, ranked by streams | READ | 17.371 | 16.818 | 17.203 | 17.131 | Seq Scan (`streams`, `tracks`, `albums`); Hash Joins; HashAggregate | Reads three tables, joins streams with tracks and albums, groups the results by track and release date, and sorts the top 50. |
| W01: Player: log a stream of track 1389 by user 1038 | WRITE | 2.067 | 0.473 | 0.474 | 1.005 | Single-row INSERT; no table scan | Inserts one stream record. PostgreSQL checks three foreign-key constraints. |
| W02: Heart button: user 1038 likes track 1389 | WRITE | 0.975 | 0.465 | 0.468 | 0.636 | INSERT with primary-key conflict check; no full table scan | Inserts one liked-track record. The primary-key index checks for duplicates, and foreign-key constraints validate the user and track. |
| W03: Add to playlist: append track 1389 to the end of playlist 501 | WRITE | 0.999 | 0.515 | 0.500 | 0.671 | Index Scan (`playlists_pkey`); Index Only Scan Backward (`playlist_tracks_pkey`) | Uses indexes to find the playlist and its last track position, then inserts one playlist-track record. |
| W04: Nightly job: recompute every artist's monthly listeners (last 28 days) | WRITE | 42.730 | 39.535 | 39.268 | 40.511 | Seq Scan (`streams`, `track_artists`, `artists`); Hash Join / Merge Join; GroupAggregate | Reads large tables, joins listening activity with artist information, groups the results to calculate monthly listeners, and updates 3,000 artist records. |
| W05: Takedown: remove tracks from the album containing track 1389 from every playlist | WRITE | 8.563 | 8.081 | 8.355 | 8.333 |Index Scan (`tracks_pkey`); Seq Scan (`tracks`, `playlist_tracks`); Hash Join   | Uses the primary-key index to find the target track, then scans the tracks and playlist_tracks tables to identify matching playlist entries. Deletes the matching records.  |
| **Total (sum of 30 queries)** | | **9119.317** | **9152.011** | **9166.892** | **9146.073** | | |



## Baseline Observations

1. **Sequential Scans:** Most read queries use Sequential Scans because PostgreSQL needs to examine a large number of rows to find the required data.

2. **Index Scans:** Queries such as R05 and R06 are faster because they use Index Scans to retrieve specific records instead of scanning entire tables.

3. **Slowest Query (R19):** R19 is the slowest query, with an average execution time of **8663.867 ms** (approximately 8.8 seconds). It repeatedly scans the `streams` and `track_artists` tables through correlated subqueries for multiple artists, resulting in high execution time.

4. **Sorting Overhead:** Queries R20 and R23 take more time because they perform sorting operations on large datasets. Both use External Merge Sort, which writes temporary data to disk.

5. **Joins and Aggregations:** Queries such as R12, R14, R16, R17, R22, and R25 involve multiple table joins and aggregation operations. These operations increase execution time because PostgreSQL processes large amounts of data.

6. **Parallel Processing:** Queries such as R01, R04, R07, R08, R09, R10, R12, and R18 use parallel scans or parallel processing to divide work among multiple workers.

7. **Fast Write Queries:** W01, W02, and W03 execute quickly because they perform small insert operations and use indexes for constraint validation instead of scanning entire tables.

8. **W04 Performance:** W04 has an average execution time of **40.511 ms**. It scans multiple tables, performs joins and aggregation, calculates monthly listeners, and updates 3,000 artist records.

9. **Pattern Matching:** R03 takes more time because it uses `ILIKE '%love%'`. Since the search pattern starts with a wildcard (`%`), a normal B-tree index cannot efficiently locate matching records, resulting in a Sequential Scan.

10. **Overall Performance:** The baseline results show that large Sequential Scans, repeated correlated subqueries, joins, aggregations, and disk-based sorting are the major factors affecting query performance.

## Conclusion

The baseline benchmark identifies the queries that require optimization. R19 is the most expensive query, while R20 and R23 also have significant sorting overhead. These results will help us evaluate the improvements achieved after applying indexing and other database optimization techniques in the next phase.


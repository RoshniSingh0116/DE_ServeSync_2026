# Phase 4 — Query Optimization Report

**Project:** Spotify Music Streaming Database  
**Team:** 008 | **Database:** PostgreSQL 18  
**Dataset:** Seed dataset (250,000 streams)

## 1. Objective and method

Phase 4 optimizes the 30-query workload while preserving results. R13 is a correctness fix because the original `NOT IN` query returned an incorrect result due to NULL values.

Queries were measured using `EXPLAIN (ANALYZE, BUFFERS)`. Write queries run inside `BEGIN` and `ROLLBACK`, so benchmark changes are not committed.

- Baseline: 3 runs per query.
- Optimized: 5 runs per query.
- Improvement = `(baseline average − optimized average) / baseline average × 100`.
- Since run counts differ, timings are indicative; very small differences may be measurement noise.

## 2. Benchmark comparison

Times are average milliseconds. Positive percentages mean faster; negative percentages mean slower.

| Query | Before | After | Change |
|---|---:|---:|---:|
| R01 | 17.224 | 3.934 | 77.16% faster |
| R02 | 2.651 | 1.809 | 31.76% faster |
| R03 | 21.271 | 21.952 | 3.20% slower |
| R04 | 5.458 | 5.371 | 1.59% faster |
| R05 | 1.289 | 0.143 | 88.91% faster |
| R06 | 0.249 | 0.043 | 82.73% faster |
| R07 | 11.567 | 7.905 | 31.66% faster |
| R08 | 10.711 | 9.814 | 8.37% faster |
| R09 | 5.815 | 5.591 | 3.85% faster |
| R10 | 10.816 | 10.379 | 4.04% faster |
| R11 | 1.119 | 0.495 | 55.76% faster |
| R12 | 19.512 | 8.053 | 58.73% faster |
| R13 | 21.841 | 2.302 | Correctness fix* |
| R14 | 8.424 | 8.044 | 4.51% faster |
| R15 | 3.343 | 1.971 | 41.04% faster |
| R16 | 17.167 | 9.721 | 43.37% faster |
| R17 | 10.935 | 3.670 | 66.44% faster |
| R18 | 14.724 | 14.517 | 1.41% faster |
| R19 | 8,663.867 | 32.378 | 99.63% faster |
| R20 | 148.696 | 61.483 | 58.65% faster |
| R21 | 2.701 | 2.691 | 0.37% faster |
| R22 | 22.397 | 22.404 | 0.03% slower |
| R23 | 44.476 | 10.938 | 75.41% faster |
| R24 | 11.533 | 11.822 | 2.51% slower |
| R25 | 17.131 | 17.360 | 1.34% slower |
| W01 | 1.005 | 0.570 | 43.28% faster |
| W02 | 0.636 | 0.468 | 26.42% faster |
| W03 | 0.671 | 0.519 | 22.65% faster |
| W04 | 40.511 | 31.173 | 23.05% faster |
| W05 | 8.333 | 8.411 | 0.94% slower |

*R13 is not a like-for-like comparison: original `NOT IN` returned 0 rows because `streams.playlist_id` contains NULLs; corrected `NOT EXISTS` returns 1,891 rows. Do not report its timing change as an equivalent-query speedup.*

## 3. Indexes created

**R23 and timestamp-filtered queries:**
```sql
CREATE INDEX IF NOT EXISTS idx_streams_started_at_covering
ON spotify.streams (started_at DESC)
INCLUDE (stream_id, user_id, track_id, ms_played);
```
This supports newest-first ordering and timestamp filtering. R23 changes from a sequential scan plus external sort to an Index Only Scan with zero heap fetches. It also appears in optimized plans for R01, R07, R12, R16, R17 and W04.

**R13:**
```sql
CREATE INDEX IF NOT EXISTS idx_streams_playlist_id_not_null
ON spotify.streams (playlist_id)
WHERE playlist_id IS NOT NULL;
```
This partial index supports the `NOT EXISTS` anti-join and excludes NULL playlist IDs that cannot match.

Recorded index sizes:
- `idx_streams_playlist_id_not_null`: 928 kB
- `idx_streams_started_at_covering`: 9,912 kB (about 9.7 MiB)

The `streams` table size was not included in the supplied benchmark artifacts. Run this in `spotify_db` to complete the table-to-index comparison:

```sql
SELECT
    c.relname AS relation_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'spotify'
  AND c.relname IN (
    'streams',
    'idx_streams_started_at_covering',
    'idx_streams_playlist_id_not_null'
  )
ORDER BY pg_relation_size(c.oid);
```

## 4. Main query optimizations

- **R12:** Rewrote the age condition as a date comparison. The optimized plan uses the covering timestamp index. `EXCEPT ALL` comparison returned no differences on the current seed dataset; leap-day and boundary-date semantics should still be considered.
- **R13:** Replaced `NOT IN` with `NOT EXISTS`. NULL values made the original condition evaluate to UNKNOWN, causing the incorrect empty result. The corrected query returns 1,891 rows and uses the partial index.
- **R19:** Replaced two correlated subqueries per verified artist with one grouped aggregation and a `LEFT JOIN`. This avoids repeated scans; average time fell from 8,663.867 ms to 32.378 ms. `EXCEPT ALL` returned no differences.
- **R20:** A `MATERIALIZED` CTE aggregates country/hour counts before sorting. The final sort handles 96 groups instead of 250,000 joined rows; average time fell from 148.696 ms to 61.483 ms. `EXCEPT ALL` returned no differences.
- **R23:** The covering index removes the sequential scan and external sort. The query still uses `OFFSET 200000`, so it must traverse many index entries.

The five strongest plan-based improvements are R19, R23, R17, R01 and R20. Raw before/after plans are saved under the corresponding query IDs in the baseline and optimized result folders.

## 5. Write overhead and remaining limitations

W01–W03 are very short operations; their timing differences should not be attributed to the custom indexes. W04 benefits from the covering timestamp index. W05 is only 0.078 ms slower; its DELETE scans `playlist_tracks`, which is not targeted by either custom index.

Queries not materially optimized:
- **R03:** leading-wildcard `ILIKE`; a B-tree index cannot efficiently support this pattern. A trigram index could be considered.
- **R04, R08–R10, R14, R18, R21–R22, R24–R25:** plans still perform broad scans, joins or aggregations. Some must read much of the relevant table, so sequential scans may be appropriate.
- **R23:** keyset pagination could scale better than a large OFFSET, but the supplied workload requires OFFSET.

## 6. Conclusion

Phase 4 adds two justified indexes and optimizes R12, R13, R19 and R20. The clearest performance gains are R19, R23, R17, R01 and R20. R13 also fixes the required NULL-related correctness bug.

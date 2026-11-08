**Problem Understanding**

## Problem Statement

Spotify faces various challenges in managing its music-related data, including slow responses to user activities, delayed artist statistics, incorrect royalty calculations, and inaccurate reports. Additionally, scheduled tasks must be completed on time, and the system must handle increasing amounts of data efficiently. These issues affect listeners, artists, labels, rights holders, and internal teams


## Business Requirements and Stakeholders

| **Problem** | **Business Requirement** | **Stakeholder** | **Classification** | **Related queries** |
|---|---|---|---|---|
| P1 | Users should be able to open artist, album, and playlist pages quickly without experiencing delays, even when viewing highly popular artists or playlists. | Listeners | Customer-facing / Real-Time | R01, R02, R05 |
| P2 | Users should be able to search for music and access their Recently Played and Liked Songs quickly, even if they have a large listening history or many liked songs. | Listeners | Customer-facing / Real-Time | R03, R04, R06, W01, W02 |
| P3 | Artists need access to recent and accurate statistics about their music, such as skip rates, listener counts, and fans-also-like information, with updates available within seconds or minutes. | Artists | Customer-facing / Real-Time | R08, R15, R16, W04 |
| P4 | Royalty calculations must correctly count eligible streams by applying the 30-second rule. Labels and rights holders also need fast and accurate track ownership and rights information through ISRC lookups. | Royalties/Finance, Labels/Rights Holders | Reporting / Analytics; Customer-facing / Real-Time | R07, R21, R24, W05 |
| P5 | The curation team needs an accurate list of public playlists that have never been played so that playlist usage can be identified correctly. | Curation Team | Reporting / Analytics | R13 |
| P6 | Spotify's personalization activities, including Wrapped, Release Radar, and new-release discovery, need to be completed on time so that users receive their personalized content and recommendations when expected. | Personalization Team, Listeners | Reporting / Analytics | R09, R11, R25 |
| P7 | Spotify needs to identify explicit tracks that have been streamed by minors accurately to support its content safety and compliance requirements. | Compliance Team | Reporting / Analytics | R12 |
| P8 | Users need to add tracks, collaborate on playlists, view updated playlist statistics, and identify or remove duplicate tracks without experiencing delays. | Playlist Users | Customer-facing / Real-Time | R14, R22, W03 |
| P9 | The business needs reliable reports and analysis covering upsell opportunities, daily streams, offline listening share, hourly listening patterns, and artist performance. These reports must remain available without timeouts even as data grows significantly, up to 20 times its current size.| Growth Team | Reporting / Analytics | R10, R17, R18, R19, R20, R23 |


## Assumptions

1. Real-time operations are expected to provide interactive response times, generally within hundreds of milliseconds. P3 may allow updates within seconds or minutes.

2. Popular artists and heavy listeners generate uneven workloads, so average query performance may not represent actual user experience.

3. The empty results in P5 may be caused by query issues, incorrect joins, or NULL handling rather than the actual absence of unplayed public playlists.

4. P7 depends on the availability and accuracy of user date-of-birth information and explicit-content indicators in the provided data.

5. Royalty calculations in P4 must produce exact results; approximate or sampled counts are not acceptable.

6. Existing query results must remain unchanged during performance optimization, except when an identified incorrect result requires a correctness fix, such as an issue caused by SQL NULL semantics.

7. The 20x data growth mentioned in P9 is assumed to primarily affect the streams table, making it an important scalability consideration.
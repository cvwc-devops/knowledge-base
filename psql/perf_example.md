# Performance check

> postgres-# FROM pg_stat_bgwriter; 

| ts | checkpoints_timed | checkpoints_req | buffers_checkpoint | buffers_backend | buffers_clean | buffers_alloc |
|------------------------------- | ------------------- | ----------------- | -------------------- | ----------------- | --------------- |
| 2025-12-19 11:39:58.621638+00 | 263 | 406 | 1641392 | 582202 | 10548 | 2625814 |
| 2025-12-19 11:41:10.350832+00 | 263 | 410 | 1654640 | 582293 | 10630 | 2651905 |

You’ve got two snapshots ~71.7s apart. The key signal is this:
- checkpoints_req: 406 → 410 (+4) in ~72s
That’s checkpoint(s) being forced by WAL pressure (not just time-based). When checkpoints_req climbs faster than checkpoints_timed, Postgres is hitting its WAL/checkpoint limits and has to checkpoint early, which can create write spikes and latency.

**Quick delta read (what changed in ~72s)**
- buffers_checkpoint: 1,641,392 → 1,654,640 (+13,248)
A checkpoint wrote ~13k buffers during that interval (could be one or more checkpoints).
- buffers_backend: 582,202 → 582,293 (+91)
Backends are doing a small amount of direct writes (not terrible in this tiny window).
- buffers_clean: 10,548 → 10,630 (+82)
Background writer isn’t doing much cleaning relative to checkpoint activity.
- buffers_alloc: 2,625,814 → 2,651,905 (+26,091)
Lots of buffer allocations → suggests active working set / churn.

**What this usually means (performance impact)**
Frequent requested checkpoints typically mean:
- WAL is filling up to your configured limit (e.g., max_wal_size) and Postgres forces checkpoints.
- That can cause bursty IO, increased checkpoint_write_time, and query latency (especially on write-heavy workloads).

## The 3 highest-impact fixes to try first
### 1) Reduce forced checkpoints: increase WAL headroom

Run:
```
SHOW max_wal_size;
SHOW min_wal_size;
SHOW checkpoint_timeout;
SHOW checkpoint_completion_target;
```

Common tuning direction (safe and widely used):
- Increase max_wal_size (often the #1 fix) so Postgres checkpoints less often.
- Keep checkpoint_timeout reasonable (e.g., 10–30 min depending on your RPO/RTO and IO).
- Set checkpoint_completion_target high (commonly 0.9) to spread checkpoint writes out.

### 2) Confirm whether checkpoints are actually hurting you (time spent)
If you’re on PG14+, check:
```
SELECT * FROM pg_stat_checkpointer;
```
Look at:
- checkpoint_write_time
- checkpoint_sync_time
- rates of checkpoints_req

If you don’t have pg_stat_checkpointer, you can still infer pain via logs:
```
SHOW log_checkpoints;
```

### 3) If backend writes grow, tune bgwriter (less common than WAL sizing)
If you start seeing buffers_backend climbing fast relative to buffers_clean, consider:
```
SHOW bgwriter_delay;
SHOW bgwriter_lru_maxpages;
SHOW bgwriter_lru_multiplier;
```
> But: in your 72s window, backend writes are tiny, so I’d fix checkpoint pressure first.

#### A) When were stats last reset?
```
SELECT pg_stat_get_bgwriter_stat_reset_time() AS bgwriter_reset;
(If that function isn’t available:)
SELECT stats_reset FROM pg_stat_bgwriter;
```

#### B) WAL/checkpoint configuration
```
SHOW shared_buffers;
SHOW max_wal_size;
SHOW min_wal_size;
SHOW checkpoint_timeout;
SHOW checkpoint_completion_target;
SHOW wal_compression;
SHOW synchronous_commit;
```

#### C) Are we IO-bound during checkpoints?
```
SELECT
  now(),
  checkpoints_timed, checkpoints_req,
  buffers_checkpoint, buffers_backend, buffers_clean,
  maxwritten_clean
FROM pg_stat_bgwriter;
```
> (Especially watch maxwritten_clean: if it climbs, bgwriter is hitting its ceiling.)

### Rule of thumb interpretation for your snapshot
- checkpoints_req moving quickly ⇒ WAL headroom is likely too small for your write rate.
- Fix: raise max_wal_size + ensure checkpoint_completion_target spreads IO.

---

















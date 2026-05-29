# PostgreSQL DBA Support Queries Runbook

## Table of Contents

- [1. Session and Connection Overview](#1-session-and-connection-overview)
  - [1.1 Current connection count by state](#11-current-connection-count-by-state)
  - [1.2 Connection count by database, user, client and state](#12-connection-count-by-database-user-client-and-state)
  - [1.3 Check max connections and current usage](#13-check-max-connections-and-current-usage)
  - [1.4 Include reserved/superuser connection settings](#14-include-reservedsuperuser-connection-settings)
  - [1.5 Long-running active queries](#15-long-running-active-queries)
  - [1.6 Idle in transaction sessions](#16-idle-in-transaction-sessions)
  - [1.7 Sessions waiting on anything](#17-sessions-waiting-on-anything)
- [2. Identify Lock Contention](#2-identify-lock-contention)
  - [2.1 Sessions currently waiting on locks](#21-sessions-currently-waiting-on-locks)
  - [2.2 Join `pg_stat_activity` with `pg_locks`](#22-join-pg_stat_activity-with-pg_locks)
  - [2.3 Blocked sessions and their blockers](#23-blocked-sessions-and-their-blockers)
  - [2.4 Lock tree / blocking chain](#24-lock-tree-blocking-chain)
  - [2.5 Locks by relation](#25-locks-by-relation)
  - [2.6 Heavy locks: AccessExclusiveLock and ungranted locks](#26-heavy-locks-accessexclusivelock-and-ungranted-locks)
  - [2.7 Safe cancel or terminate commands to review](#27-safe-cancel-or-terminate-commands-to-review)
- [3. Memory Usage and Configuration](#3-memory-usage-and-configuration)
  - [3.1 Key memory settings](#31-key-memory-settings)
  - [3.2 Memory settings converted to MB where possible](#32-memory-settings-converted-to-mb-where-possible)
  - [3.3 Estimate worst-case work memory exposure](#33-estimate-worst-case-work-memory-exposure)
  - [3.4 Active temporary file usage by database](#34-active-temporary-file-usage-by-database)
  - [3.5 Sort/hash spill candidates from `pg_stat_statements`](#35-sorthash-spill-candidates-from-pg_stat_statements)
  - [3.6 Live memory contexts, PostgreSQL 14+](#36-live-memory-contexts-postgresql-14)
- [4. Using `pg_stat_activity`](#4-using-pg_stat_activity)
  - [4.1 What is running right now?](#41-what-is-running-right-now)
  - [4.2 Backend types](#42-backend-types)
  - [4.3 Old transactions that may block vacuum](#43-old-transactions-that-may-block-vacuum)
- [5. Using `pg_stat_statements`](#5-using-pg_stat_statements)
  - [5.1 Confirm extension exists](#51-confirm-extension-exists)
  - [5.2 Create extension if approved](#52-create-extension-if-approved)
  - [5.3 Top queries by total execution time](#53-top-queries-by-total-execution-time)
  - [5.4 Top queries by mean execution time](#54-top-queries-by-mean-execution-time)
  - [5.5 Top queries by disk reads](#55-top-queries-by-disk-reads)
  - [5.6 Top queries by WAL generation, PostgreSQL 13+](#56-top-queries-by-wal-generation-postgresql-13)
  - [5.7 Reset statistics after a baseline snapshot](#57-reset-statistics-after-a-baseline-snapshot)
- [6. Using `pg_stat_replication`](#6-using-pg_stat_replication)
  - [6.1 Replication status and lag](#61-replication-status-and-lag)
  - [6.2 Replication slots and retained WAL risk](#62-replication-slots-and-retained-wal-risk)
  - [6.3 Standby receive/replay state](#63-standby-receivereplay-state)
- [7. CPU Alert Triage](#7-cpu-alert-triage)
  - [7.1 Many active sessions](#71-many-active-sessions)
  - [7.2 Queries consuming most execution time](#72-queries-consuming-most-execution-time)
  - [7.3 Query plans currently running longer than 5 minutes](#73-query-plans-currently-running-longer-than-5-minutes)
  - [7.4 Database transaction and tuple churn](#74-database-transaction-and-tuple-churn)
- [8. Memory Alert Triage](#8-memory-alert-triage)
  - [8.1 Connection pressure plus memory settings](#81-connection-pressure-plus-memory-settings)
  - [8.2 Temp file spill trend by database](#82-temp-file-spill-trend-by-database)
  - [8.3 Active queries that may be using memory](#83-active-queries-that-may-be-using-memory)
- [9. Disk and I/O Alert Triage](#9-disk-and-io-alert-triage)
  - [9.1 Database cache hit ratio](#91-database-cache-hit-ratio)
  - [9.2 Largest databases](#92-largest-databases)
  - [9.3 Largest tables and indexes](#93-largest-tables-and-indexes)
  - [9.4 Table bloat indicators: dead tuples](#94-table-bloat-indicators-dead-tuples)
  - [9.5 Index usage check](#95-index-usage-check)
  - [9.6 PostgreSQL 16+ I/O statistics](#96-postgresql-16-io-statistics)
  - [9.7 Checkpoint and background writer pressure](#97-checkpoint-and-background-writer-pressure)
  - [9.8 WAL generation summary, PostgreSQL 14+](#98-wal-generation-summary-postgresql-14)
- [10. Vacuum, Autovacuum, and Transaction ID Health](#10-vacuum-autovacuum-and-transaction-id-health)
  - [10.1 Tables needing vacuum attention](#101-tables-needing-vacuum-attention)
  - [10.2 Transaction ID wraparound risk](#102-transaction-id-wraparound-risk)
  - [10.3 Old transactions blocking cleanup](#103-old-transactions-blocking-cleanup)
  - [10.4 Currently running vacuum/autovacuum](#104-currently-running-vacuumautovacuum)
- [11. Backup, Restore, and Maintenance Progress](#11-backup-restore-and-maintenance-progress)
  - [11.1 CREATE INDEX progress](#111-create-index-progress)
  - [11.2 Base backup progress, PostgreSQL 13+](#112-base-backup-progress-postgresql-13)
  - [11.3 COPY progress, PostgreSQL 14+](#113-copy-progress-postgresql-14)
- [12. Alert-Oriented Quick Checks](#12-alert-oriented-quick-checks)
  - [12.1 Lock alert](#121-lock-alert)
  - [12.2 Connection alert](#122-connection-alert)
  - [12.3 Long transaction alert](#123-long-transaction-alert)
  - [12.4 Replication lag alert](#124-replication-lag-alert)
  - [12.5 Temp file alert](#125-temp-file-alert)
- [13. Practical Incident Workflow](#13-practical-incident-workflow)
  - [Lock contention](#lock-contention)
  - [Max connections](#max-connections)
  - [CPU alert](#cpu-alert)
  - [Memory alert](#memory-alert)
  - [Disk alert](#disk-alert)
- [14. Helpful psql Commands](#14-helpful-psql-commands)
- [15. Notes on Views](#15-notes-on-views)
- [16. Minimum Extensions / Settings to Consider](#16-minimum-extensions-settings-to-consider)
- [17. Quick DBA Support Bundle](#17-quick-dba-support-bundle)
- [18. XID means Transaction ID in PostgreSQL](#18-xid-means-transaction-id-in-postgresql)
- [19. What to do if XID age is rising](#19-what-to-do-if-xid-age-is-rising)
- [20. Safe remediation options for XID](#20-safe-remediation-options-for-xid)
- [21. Performance Checks](#21-performance-checks)

Purpose: quick PostgreSQL support queries for lock contention, max connections, active sessions, memory settings, query performance, replication health, and alerts for CPU, memory, and disk pressure.

Assumptions:
- Run these from `psql` as a role with enough privileges to view statistics.
- Some views expose limited query text unless the role has `pg_read_all_stats` or superuser privileges.
- `pg_stat_statements` requires the extension to be installed and loaded.
- Version-specific views are marked where relevant.

---

## 1. Session and Connection Overview

### 1.1 Current connection count by state

```sql
SELECT
    state,
    COUNT(*) AS connections
FROM pg_stat_activity
GROUP BY state
ORDER BY connections DESC;
```

### 1.2 Connection count by database, user, client and state

```sql
SELECT
    datname,
    usename,
    client_addr,
    state,
    COUNT(*) AS connections
FROM pg_stat_activity
GROUP BY datname, usename, client_addr, state
ORDER BY connections DESC;
```

### 1.3 Check max connections and current usage

```sql
WITH settings AS (
    SELECT setting::int AS max_connections
    FROM pg_settings
    WHERE name = 'max_connections'
), usage AS (
    SELECT COUNT(*) AS used_connections
    FROM pg_stat_activity
)
SELECT
    used_connections,
    max_connections,
    max_connections - used_connections AS free_connections,
    ROUND((used_connections::numeric / max_connections) * 100, 2) AS pct_used
FROM usage, settings;
```

### 1.4 Include reserved/superuser connection settings

```sql
SELECT
    name,
    setting,
    unit,
    context,
    short_desc
FROM pg_settings
WHERE name IN (
    'max_connections',
    'superuser_reserved_connections',
    'reserved_connections'
)
ORDER BY name;
```

Note: `reserved_connections` exists in newer PostgreSQL versions. If this query errors, remove that parameter.

### 1.5 Long-running active queries

```sql
SELECT
    pid,
    usename,
    datname,
    client_addr,
    application_name,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    now() - xact_start AS xact_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC NULLS LAST;
```

### 1.6 Idle in transaction sessions

```sql
SELECT
    pid,
    usename,
    datname,
    client_addr,
    application_name,
    state,
    now() - xact_start AS xact_age,
    now() - state_change AS idle_age,
    wait_event_type,
    wait_event,
    LEFT(query, 2000) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC NULLS LAST;
```

### 1.7 Sessions waiting on anything

```sql
SELECT
    pid,
    usename,
    datname,
    client_addr,
    application_name,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE wait_event_type IS NOT NULL
ORDER BY query_age DESC NULLS LAST;
```

---

## 2. Identify Lock Contention

### 2.1 Sessions currently waiting on locks

```sql
SELECT
    a.pid,
    a.usename,
    a.datname,
    a.client_addr,
    a.application_name,
    a.state,
    a.wait_event_type,
    a.wait_event,
    now() - a.query_start AS waiting_for,
    LEFT(a.query, 2000) AS waiting_query
FROM pg_stat_activity a
WHERE a.wait_event_type = 'Lock'
ORDER BY waiting_for DESC NULLS LAST;
```

### 2.2 Join `pg_stat_activity` with `pg_locks`

```sql
SELECT
    a.pid,
    a.usename,
    a.datname,
    a.client_addr,
    a.application_name,
    a.state,
    a.wait_event_type,
    a.wait_event,
    l.locktype,
    l.mode,
    l.granted,
    l.relation::regclass AS relation_name,
    l.page,
    l.tuple,
    l.virtualxid,
    l.transactionid,
    now() - a.query_start AS query_age,
    LEFT(a.query, 2000) AS query
FROM pg_stat_activity a
JOIN pg_locks l
    ON l.pid = a.pid
WHERE a.wait_event_type = 'Lock'
   OR l.granted = false
ORDER BY l.granted, query_age DESC NULLS LAST;
```

### 2.3 Blocked sessions and their blockers

```sql
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    blocked.datname AS blocked_database,
    now() - blocked.query_start AS blocked_for,
    LEFT(blocked.query, 2000) AS blocked_query,
    blocker.pid AS blocker_pid,
    blocker.usename AS blocker_user,
    blocker.datname AS blocker_database,
    blocker.state AS blocker_state,
    now() - blocker.query_start AS blocker_query_age,
    now() - blocker.xact_start AS blocker_xact_age,
    LEFT(blocker.query, 2000) AS blocker_query
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(blocker_pid)
    ON true
JOIN pg_stat_activity blocker
    ON blocker.pid = b.blocker_pid
ORDER BY blocked_for DESC NULLS LAST;
```

### 2.4 Lock tree / blocking chain

```sql
WITH RECURSIVE lock_tree AS (
    SELECT
        a.pid,
        a.usename,
        a.datname,
        a.state,
        a.wait_event_type,
        a.wait_event,
        pg_blocking_pids(a.pid) AS blocking_pids,
        0 AS depth,
        ARRAY[a.pid] AS path,
        now() - a.query_start AS query_age,
        LEFT(a.query, 1000) AS query
    FROM pg_stat_activity a
    WHERE cardinality(pg_blocking_pids(a.pid)) > 0

    UNION ALL

    SELECT
        b.pid,
        b.usename,
        b.datname,
        b.state,
        b.wait_event_type,
        b.wait_event,
        pg_blocking_pids(b.pid) AS blocking_pids,
        lt.depth + 1,
        lt.path || b.pid,
        now() - b.query_start AS query_age,
        LEFT(b.query, 1000) AS query
    FROM lock_tree lt
    JOIN pg_stat_activity b
      ON b.pid = ANY(lt.blocking_pids)
    WHERE NOT b.pid = ANY(lt.path)
)
SELECT *
FROM lock_tree
ORDER BY path, depth;
```

### 2.5 Locks by relation

```sql
SELECT
    COALESCE(l.relation::regclass::text, 'not relation lock') AS relation_name,
    l.locktype,
    l.mode,
    l.granted,
    COUNT(*) AS lock_count
FROM pg_locks l
GROUP BY relation_name, l.locktype, l.mode, l.granted
ORDER BY lock_count DESC, relation_name;
```

### 2.6 Heavy locks: AccessExclusiveLock and ungranted locks

```sql
SELECT
    a.pid,
    a.usename,
    a.datname,
    a.client_addr,
    a.application_name,
    l.locktype,
    l.mode,
    l.granted,
    l.relation::regclass AS relation_name,
    now() - a.query_start AS query_age,
    LEFT(a.query, 2000) AS query
FROM pg_locks l
JOIN pg_stat_activity a
    ON a.pid = l.pid
WHERE l.mode = 'AccessExclusiveLock'
   OR l.granted = false
ORDER BY l.granted, query_age DESC NULLS LAST;
```

### 2.7 Safe cancel or terminate commands to review

Generate commands only. Review before running.

```sql
SELECT
    pid,
    usename,
    state,
    now() - query_start AS query_age,
    'SELECT pg_cancel_backend(' || pid || ');' AS cancel_command,
    'SELECT pg_terminate_backend(' || pid || ');' AS terminate_command,
    LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND state <> 'idle'
ORDER BY query_age DESC NULLS LAST;
```

Guidance:
- Prefer `pg_cancel_backend(pid)` first for active queries.
- Use `pg_terminate_backend(pid)` only when you understand the business impact.
- Be very careful terminating autovacuum, replication, backup, migration, or application maintenance sessions.

---

## 3. Memory Usage and Configuration

### 3.1 Key memory settings

```sql
SELECT
    name,
    setting,
    unit,
    context,
    source,
    pending_restart,
    short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'temp_buffers',
    'effective_cache_size',
    'huge_pages',
    'max_connections',
    'max_worker_processes',
    'max_parallel_workers',
    'max_parallel_workers_per_gather',
    'max_wal_senders'
)
ORDER BY name;
```

### 3.2 Memory settings converted to MB where possible

```sql
SELECT
    name,
    setting,
    unit,
    CASE
        WHEN unit = '8kB' THEN ROUND(setting::numeric * 8 / 1024, 2)
        WHEN unit = 'kB' THEN ROUND(setting::numeric / 1024, 2)
        WHEN unit = 'MB' THEN setting::numeric
        WHEN unit = 'GB' THEN setting::numeric * 1024
        ELSE NULL
    END AS value_mb,
    source,
    pending_restart
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'temp_buffers',
    'effective_cache_size'
)
ORDER BY name;
```

### 3.3 Estimate worst-case work memory exposure

This is not actual memory usage. It is a rough upper-bound risk check.

```sql
WITH s AS (
    SELECT
        MAX(CASE WHEN name = 'max_connections' THEN setting::numeric END) AS max_connections,
        MAX(CASE WHEN name = 'work_mem' THEN setting::numeric END) AS work_mem_raw,
        MAX(CASE WHEN name = 'work_mem' THEN unit END) AS work_mem_unit
    FROM pg_settings
    WHERE name IN ('max_connections', 'work_mem')
), wm AS (
    SELECT
        max_connections,
        CASE
            WHEN work_mem_unit = '8kB' THEN work_mem_raw * 8 / 1024
            WHEN work_mem_unit = 'kB' THEN work_mem_raw / 1024
            WHEN work_mem_unit = 'MB' THEN work_mem_raw
            WHEN work_mem_unit = 'GB' THEN work_mem_raw * 1024
            ELSE NULL
        END AS work_mem_mb
    FROM s
)
SELECT
    max_connections,
    work_mem_mb,
    ROUND(max_connections * work_mem_mb, 2) AS theoretical_work_mem_mb
FROM wm;
```

Important: one backend can use multiple `work_mem` allocations at the same time, for example for multiple sort/hash nodes. Do not treat this as a true cap.

### 3.4 Active temporary file usage by database

```sql
SELECT
    datname,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_bytes,
    ROUND(temp_bytes::numeric / NULLIF(temp_files, 0), 2) AS avg_temp_bytes_per_file
FROM pg_stat_database
WHERE temp_files > 0
ORDER BY temp_bytes DESC;
```

### 3.5 Sort/hash spill candidates from `pg_stat_statements`

Requires `pg_stat_statements`.

```sql
SELECT
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_exec_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_exec_ms,
    temp_blks_read,
    temp_blks_written,
    pg_size_pretty((temp_blks_read + temp_blks_written) * current_setting('block_size')::int::bigint) AS temp_io,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
WHERE temp_blks_read > 0
   OR temp_blks_written > 0
ORDER BY (temp_blks_read + temp_blks_written) DESC
LIMIT 25;
```

### 3.6 Live memory contexts, PostgreSQL 14+

Requires suitable privileges.

```sql
SELECT
    name,
    ident,
    parent,
    level,
    total_bytes,
    pg_size_pretty(total_bytes) AS total,
    free_bytes,
    pg_size_pretty(free_bytes) AS free,
    used_bytes,
    pg_size_pretty(used_bytes) AS used
FROM pg_backend_memory_contexts
ORDER BY total_bytes DESC
LIMIT 50;
```

Note: `pg_backend_memory_contexts` shows memory contexts for the current backend, not every session.

---

## 4. Using `pg_stat_activity`

Use this view for current session state, active SQL, wait events, transaction age, and client/application details.

### 4.1 What is running right now?

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    backend_type,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    now() - xact_start AS xact_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC NULLS LAST;
```

### 4.2 Backend types

```sql
SELECT
    backend_type,
    state,
    COUNT(*) AS count
FROM pg_stat_activity
GROUP BY backend_type, state
ORDER BY count DESC;
```

### 4.3 Old transactions that may block vacuum

```sql
SELECT
    pid,
    usename,
    datname,
    state,
    backend_xmin,
    age(backend_xmin) AS backend_xmin_age,
    now() - xact_start AS xact_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC NULLS LAST;
```

---

## 5. Using `pg_stat_statements`

Use this for query-level performance history: total time, mean time, calls, rows, buffer hits/reads, temp spills, and write pressure.

### 5.1 Confirm extension exists

```sql
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_stat_statements';
```

### 5.2 Create extension if approved

Run during a planned change window if not already enabled.

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

The extension also usually requires `shared_preload_libraries = 'pg_stat_statements'` and a PostgreSQL restart if it is not already loaded.

### 5.3 Top queries by total execution time

```sql
SELECT
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_exec_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_exec_ms,
    ROUND(max_exec_time::numeric, 2) AS max_exec_ms,
    rows,
    shared_blks_hit,
    shared_blks_read,
    temp_blks_written,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 25;
```

### 5.4 Top queries by mean execution time

```sql
SELECT
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_exec_ms,
    ROUND(max_exec_time::numeric, 2) AS max_exec_ms,
    rows,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
WHERE calls >= 5
ORDER BY mean_exec_time DESC
LIMIT 25;
```

### 5.5 Top queries by disk reads

```sql
SELECT
    calls,
    shared_blks_read,
    shared_blks_hit,
    ROUND(
        100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0),
        2
    ) AS hit_pct,
    pg_size_pretty(shared_blks_read * current_setting('block_size')::int::bigint) AS read_volume,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 25;
```

### 5.6 Top queries by WAL generation, PostgreSQL 13+

```sql
SELECT
    calls,
    wal_records,
    wal_fpi,
    pg_size_pretty(wal_bytes) AS wal_bytes,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
ORDER BY wal_bytes DESC
LIMIT 25;
```

### 5.7 Reset statistics after a baseline snapshot

Use carefully. This clears historical query stats.

```sql
SELECT pg_stat_statements_reset();
```

---

## 6. Using `pg_stat_replication`

Use this on the primary to inspect streaming replication status and lag.

### 6.1 Replication status and lag

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS sent_replay_lag_bytes
FROM pg_stat_replication
ORDER BY pg_wal_lsn_diff(sent_lsn, replay_lsn) DESC NULLS LAST;
```

### 6.2 Replication slots and retained WAL risk

```sql
SELECT
    slot_name,
    plugin,
    slot_type,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    wal_status,
    safe_wal_size,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC NULLS LAST;
```

### 6.3 Standby receive/replay state

Run this on a standby.

```sql
SELECT
    pg_is_in_recovery() AS is_standby,
    pg_last_wal_receive_lsn() AS last_receive_lsn,
    pg_last_wal_replay_lsn() AS last_replay_lsn,
    pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())) AS receive_replay_gap,
    now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

---

## 7. CPU Alert Triage

PostgreSQL does not expose full OS CPU usage by default. Use these SQL checks to find database symptoms, then confirm with OS tools such as `top`, `htop`, `pidstat`, `sar`, or cloud metrics.

### 7.1 Many active sessions

```sql
SELECT
    state,
    wait_event_type,
    wait_event,
    COUNT(*) AS sessions
FROM pg_stat_activity
WHERE state <> 'idle'
GROUP BY state, wait_event_type, wait_event
ORDER BY sessions DESC;
```

### 7.2 Queries consuming most execution time

```sql
SELECT
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_exec_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_exec_ms,
    rows,
    LEFT(query, 2000) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### 7.3 Query plans currently running longer than 5 minutes

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    now() - query_start AS query_age,
    wait_event_type,
    wait_event,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
ORDER BY query_age DESC;
```

### 7.4 Database transaction and tuple churn

```sql
SELECT
    datname,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted,
    deadlocks,
    conflicts
FROM pg_stat_database
ORDER BY (xact_commit + xact_rollback) DESC;
```

---

## 8. Memory Alert Triage

### 8.1 Connection pressure plus memory settings

```sql
WITH conn AS (
    SELECT COUNT(*) AS current_connections
    FROM pg_stat_activity
), settings AS (
    SELECT
        MAX(CASE WHEN name = 'max_connections' THEN setting END) AS max_connections,
        MAX(CASE WHEN name = 'shared_buffers' THEN setting || COALESCE(unit, '') END) AS shared_buffers,
        MAX(CASE WHEN name = 'work_mem' THEN setting || COALESCE(unit, '') END) AS work_mem,
        MAX(CASE WHEN name = 'maintenance_work_mem' THEN setting || COALESCE(unit, '') END) AS maintenance_work_mem,
        MAX(CASE WHEN name = 'autovacuum_work_mem' THEN setting || COALESCE(unit, '') END) AS autovacuum_work_mem
    FROM pg_settings
    WHERE name IN (
        'max_connections',
        'shared_buffers',
        'work_mem',
        'maintenance_work_mem',
        'autovacuum_work_mem'
    )
)
SELECT *
FROM conn, settings;
```

### 8.2 Temp file spill trend by database

```sql
SELECT
    datname,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_bytes,
    deadlocks,
    stats_reset
FROM pg_stat_database
ORDER BY temp_bytes DESC;
```

### 8.3 Active queries that may be using memory

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    state,
    now() - query_start AS query_age,
    wait_event_type,
    wait_event,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_age DESC NULLS LAST;
```

---

## 9. Disk and I/O Alert Triage

### 9.1 Database cache hit ratio

```sql
SELECT
    datname,
    blks_read,
    blks_hit,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_bytes
FROM pg_stat_database
ORDER BY blks_read DESC;
```

### 9.2 Largest databases

```sql
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS database_size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

### 9.3 Largest tables and indexes

```sql
SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_indexes_size(relid)) AS index_size,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 50;
```

### 9.4 Table bloat indicators: dead tuples

```sql
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
    last_vacuum,
    last_autovacuum,
    vacuum_count,
    autovacuum_count
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 50;
```

### 9.5 Index usage check

```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 50;
```

### 9.6 PostgreSQL 16+ I/O statistics

```sql
SELECT
    backend_type,
    object,
    context,
    reads,
    writes,
    extends,
    hits,
    evictions,
    reuses,
    fsyncs,
    stats_reset
FROM pg_stat_io
ORDER BY reads + writes + extends DESC
LIMIT 50;
```

### 9.7 Checkpoint and background writer pressure

```sql
SELECT
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean,
    buffers_backend,
    buffers_backend_fsync,
    buffers_alloc,
    stats_reset
FROM pg_stat_bgwriter;
```

### 9.8 WAL generation summary, PostgreSQL 14+

```sql
SELECT
    wal_records,
    wal_fpi,
    pg_size_pretty(wal_bytes) AS wal_bytes,
    wal_buffers_full,
    wal_write,
    wal_sync,
    wal_write_time,
    wal_sync_time,
    stats_reset
FROM pg_stat_wal;
```

---

## 10. Vacuum, Autovacuum, and Transaction ID Health

### 10.1 Tables needing vacuum attention

```sql
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
    last_vacuum,
    last_autovacuum,
    vacuum_count,
    autovacuum_count
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 50;
```

### 10.2 Transaction ID wraparound risk

```sql
SELECT
    datname,
    age(datfrozenxid) AS xid_age,
    datfrozenxid
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
```

### 10.3 Old transactions blocking cleanup

```sql
SELECT
    pid,
    usename,
    datname,
    state,
    backend_xmin,
    age(backend_xmin) AS backend_xmin_age,
    now() - xact_start AS xact_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC NULLS LAST;
```

### 10.4 Currently running vacuum/autovacuum

```sql
SELECT
    pid,
    datname,
    relid::regclass AS relation_name,
    phase,
    heap_blks_total,
    heap_blks_scanned,
    heap_blks_vacuumed,
    index_vacuum_count,
    max_dead_tuples,
    num_dead_tuples
FROM pg_stat_progress_vacuum
ORDER BY heap_blks_scanned DESC;
```

---

## 11. Backup, Restore, and Maintenance Progress

### 11.1 CREATE INDEX progress

```sql
SELECT
    pid,
    datname,
    relid::regclass AS table_name,
    index_relid::regclass AS index_name,
    command,
    phase,
    lockers_total,
    lockers_done,
    blocks_total,
    blocks_done,
    tuples_total,
    tuples_done
FROM pg_stat_progress_create_index;
```

### 11.2 Base backup progress, PostgreSQL 13+

```sql
SELECT
    pid,
    phase,
    backup_total,
    backup_streamed,
    tablespaces_total,
    tablespaces_streamed
FROM pg_stat_progress_basebackup;
```

### 11.3 COPY progress, PostgreSQL 14+

```sql
SELECT
    pid,
    datid,
    datname,
    relid::regclass AS relation_name,
    command,
    type,
    bytes_processed,
    bytes_total,
    tuples_processed,
    tuples_excluded
FROM pg_stat_progress_copy;
```

---

## 12. Alert-Oriented Quick Checks

### 12.1 Lock alert

```sql
SELECT
    COUNT(*) AS sessions_waiting_on_locks
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
```

### 12.2 Connection alert

```sql
WITH c AS (
    SELECT COUNT(*)::numeric AS used_connections
    FROM pg_stat_activity
), s AS (
    SELECT setting::numeric AS max_connections
    FROM pg_settings
    WHERE name = 'max_connections'
)
SELECT
    used_connections,
    max_connections,
    ROUND(100 * used_connections / max_connections, 2) AS pct_used
FROM c, s;
```

### 12.3 Long transaction alert

```sql
SELECT
    pid,
    usename,
    datname,
    state,
    now() - xact_start AS xact_age,
    LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND now() - xact_start > interval '15 minutes'
ORDER BY xact_age DESC;
```

### 12.4 Replication lag alert

```sql
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS byte_lag
FROM pg_stat_replication
ORDER BY pg_wal_lsn_diff(sent_lsn, replay_lsn) DESC NULLS LAST;
```

### 12.5 Temp file alert

```sql
SELECT
    datname,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_bytes
FROM pg_stat_database
WHERE temp_bytes > 0
ORDER BY temp_bytes DESC;
```

---

## 13. Practical Incident Workflow

### Lock contention

1. Run `2.1` to confirm sessions waiting on locks.
2. Run `2.3` to identify blockers.
3. Check whether blocker is idle in transaction, long-running DDL, migration, backup, or application query.
4. Prefer application owner confirmation before termination.
5. Use `2.7` to generate cancel/terminate commands.

### Max connections

1. Run `1.3` for current usage.
2. Run `1.2` to identify source client/user/application.
3. Check if sessions are idle, idle in transaction, or active.
4. Consider connection pool limits before increasing `max_connections`.

### CPU alert

1. Confirm OS CPU pressure outside PostgreSQL.
2. Run `7.1` for active session shape.
3. Run `7.2` for historical expensive SQL.
4. Run `7.3` for live long-running SQL.
5. Use `EXPLAIN (ANALYZE, BUFFERS)` carefully on representative queries, not blindly on production-impacting statements.

### Memory alert

1. Check OS memory and swap pressure.
2. Run `8.1` for connection count and memory configuration.
3. Run `8.2` and `3.5` for temp spill evidence.
4. Watch for high connection count plus high `work_mem`.
5. Avoid increasing `work_mem` globally without checking concurrency.

### Disk alert

1. Confirm filesystem usage with OS/cloud monitoring.
2. Run `9.2` and `9.3` for largest databases/tables.
3. Run `9.4` and `10.1` for dead tuple pressure.
4. Run `6.2` for replication slots retaining WAL.
5. Run `9.8` for WAL generation if available.

---

## 14. Helpful psql Commands

```sql
-- Current database and user
SELECT current_database(), current_user, inet_server_addr(), inet_server_port();

-- PostgreSQL version
SELECT version();

-- Show important file locations
SHOW config_file;
SHOW hba_file;
SHOW data_directory;

-- Expanded display in psql
\x on

-- Timing in psql
\timing on
```

---

## 15. Notes on Views

- `pg_stat_activity`: one row per server process. Best first stop for current activity, waits, long transactions, and connection pressure.
- `pg_locks`: one row per active lockable object/request. Join with `pg_stat_activity` to understand who holds or waits for locks.
- `pg_stat_statements`: historical normalized query statistics. Best for finding recurring expensive SQL.
- `pg_stat_replication`: primary-side streaming replication status and lag.
- `pg_stat_database`: database-level counters for transactions, block reads/hits, temp files, deadlocks, and conflicts.
- `pg_stat_user_tables`: table-level activity, dead tuples, vacuum/analyze history.
- `pg_stat_user_indexes`: index scan and tuple fetch activity.
- `pg_stat_bgwriter`, `pg_stat_wal`, `pg_stat_io`: write, WAL, and I/O pressure depending on PostgreSQL version.

---

## 16. Minimum Extensions / Settings to Consider

```sql
-- Requires change control and usually restart if adding to shared_preload_libraries
SHOW shared_preload_libraries;

-- For pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Helpful settings to inspect
SELECT name, setting, unit, source, pending_restart
FROM pg_settings
WHERE name IN (
    'track_activities',
    'track_activity_query_size',
    'track_counts',
    'track_io_timing',
    'compute_query_id',
    'shared_preload_libraries'
)
ORDER BY name;
```

Operational note: enabling `track_io_timing` can add overhead on some systems. Test or validate before enabling broadly.

---

## 17. Quick DBA Support Bundle

Run this bundle when you need a fast first look.

```sql
-- 1. Version
SELECT version();

-- 2. Connection usage
WITH c AS (SELECT COUNT(*)::numeric AS used_connections FROM pg_stat_activity),
     s AS (SELECT setting::numeric AS max_connections FROM pg_settings WHERE name = 'max_connections')
SELECT used_connections, max_connections, ROUND(100 * used_connections / max_connections, 2) AS pct_used
FROM c, s;

-- 3. Connection states
SELECT state, wait_event_type, wait_event, COUNT(*)
FROM pg_stat_activity
GROUP BY state, wait_event_type, wait_event
ORDER BY count DESC;

-- 4. Lock waits
SELECT pid, usename, datname, wait_event_type, wait_event, now() - query_start AS age, LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY age DESC;

-- 5. Blocking pairs
SELECT blocked.pid AS blocked_pid,
       blocker.pid AS blocker_pid,
       now() - blocked.query_start AS blocked_for,
       LEFT(blocked.query, 1000) AS blocked_query,
       LEFT(blocker.query, 1000) AS blocker_query
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(blocker_pid) ON true
JOIN pg_stat_activity blocker ON blocker.pid = b.blocker_pid
ORDER BY blocked_for DESC;

-- 6. Long active queries
SELECT pid, usename, datname, state, now() - query_start AS age, wait_event_type, wait_event, LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY age DESC NULLS LAST
LIMIT 20;

-- 7. Memory settings
SELECT name, setting, unit, source, pending_restart
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'autovacuum_work_mem', 'effective_cache_size', 'max_connections')
ORDER BY name;

-- 8. Database temp and cache stats
SELECT datname,
       ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
       temp_files,
       pg_size_pretty(temp_bytes) AS temp_bytes,
       deadlocks
FROM pg_stat_database
ORDER BY temp_bytes DESC;

-- 9. Largest tables
SELECT schemaname, relname, pg_size_pretty(pg_total_relation_size(relid)) AS total_size, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;

-- 10. Replication status on primary
SELECT application_name, client_addr, state, sync_state, write_lag, flush_lag, replay_lag,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS byte_lag
FROM pg_stat_replication;

-- 11. XID Checks
SELECT datname, age(datfrozenxid) AS xid_age, datfrozenxid
FROM pg_database
ORDER BY age(datfrozenxid) DESC;

-- 12 Check old transactions
SELECT pid, usename, datname, state, backend_xmin,
    age(backend_xmin) AS backend_xmin_age,
    now() - xact_start AS xact_age,
    LEFT(query, 2000) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC NULLS LAST;

-- 13 Check tables with old frozen XIDs
SELECT schemaname,  relname, age(relfrozenxid) AS xid_age,
    n_live_tup,  n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY age(relfrozenxid) DESC
LIMIT 50;
```

## 18. XID means Transaction ID in PostgreSQL.

PostgreSQL assigns an XID to transactions that modify data. It uses that ID to decide which row versions are visible to which transactions. This is central to PostgreSQL’s MVCC model, where updates do not overwrite rows directly; they create new row versions.

XID health is very important for:
- transaction visibility
- vacuum cleanup
- avoiding table bloat
- preventing transaction ID wraparound
- keeping the database available

PostgreSQL transaction IDs are finite. Eventually, they can wrap around and start reusing old values.

That is dangerous because PostgreSQL must be able to tell whether a transaction ID is “in the past” or “in the future.” If very old row versions are not frozen in time, PostgreSQL could misinterpret row visibility.

To prevent that, PostgreSQL uses VACUUM and autovacuum to “freeze” old transaction IDs.

**The serious failure mode is:
If XID age gets too high and PostgreSQL cannot vacuum/freeze old rows, PostgreSQL can force the database into a protective shutdown mode to prevent data corruption.

### Key settings to know:
```sql
SELECT name, setting, unit, context, source, pending_restart
FROM pg_settings
WHERE name IN (
    'autovacuum',
    'autovacuum_freeze_max_age',
    'vacuum_freeze_min_age',
    'vacuum_freeze_table_age',
    'autovacuum_vacuum_cost_limit',
    'autovacuum_vacuum_cost_delay',
    'autovacuum_max_workers',
    'maintenance_work_mem'
)
ORDER BY name;
```

### Common causes of XID risk
The most common causes are:

1. Autovacuum cannot keep up
High-write tables, large tables, low autovacuum worker count, low cost limits, or heavy I/O pressure can cause vacuum to fall behind.

2. Long-running transactions
Old transactions can hold back cleanup because PostgreSQL must preserve row versions they might still need.

3. Idle in transaction sessions
These are especially dangerous. A connection can sit doing nothing while still holding an old transaction snapshot.

4. Replication slots
Physical or logical replication slots can retain WAL. Logical replication can also interact with old catalog state. Slots that are inactive or lagging should be watched carefully.

5. Large tables with low churn but old frozen XID
Even mostly-static large tables still need freezing eventually. If they are huge, anti-wraparound vacuum can become painful when left too late.

6. Autovacuum disabled
Disabling autovacuum on tables is risky unless there is a very deliberate maintenance process replacing it.

### default is commonly 200 million transactions
When a database or table gets too close to that age, PostgreSQL becomes increasingly aggressive about anti-wraparound vacuum.

- Under 100M : Usually healthy
- 100M–150M : Watch and confirm autovacuum is working
- 150M–180M : Investigate; tune or manually vacuum if needed
- 180M+ : High concern if default autovacuum_freeze_max_age is 200M
- Near 200M : Urgent anti-wraparound risk

## 19. What to do if XID age is rising

```sql
-- status
SELECT
    datname,
    age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;

-- Then identify worst tables:
SELECT schemaname, relname,
    age(relfrozenxid) AS xid_age,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY age(relfrozenxid) DESC
LIMIT 20;

-- Check whether autovacuum is currently running
SELECT pid, datname, relid::regclass AS relation_name, phase,
    heap_blks_total, heap_blks_scanned, heap_blks_vacuumed,
    index_vacuum_count, max_dead_tuples, num_dead_tuples
FROM pg_stat_progress_vacuum
ORDER BY heap_blks_scanned DESC;

-- check for blockers:
SELECT pid, usename, datname, state, backend_xmin,
    age(backend_xmin) AS backend_xmin_age,
    now() - xact_start AS xact_age,
    LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC NULLS LAST;
```

## 20. Safe remediation options for XID
- For very large or hot tables, do this carefully. It can create I/O pressure.
```sql
VACUUM (VERBOSE, FREEZE) schema.table_name;
```

- You may also need to tune autovacuum more aggressively for specific tables:
```sql
ALTER TABLE schema.table_name SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_vacuum_threshold = 5000,
    autovacuum_freeze_max_age = 150000000
);
```
- For high-churn large tables, table-specific autovacuum settings are often better than only changing global settings.


Lastly:
- monitor are age(datfrozenxid) at the database level
- age(relfrozenxid) at the table level
- long-running transactions, idle-in-transaction sessions, autovacuum progress, and replication slot lag.

The most common problems are autovacuum falling behind, long transactions holding old snapshots, and very large high-churn tables not being vacuumed aggressively enough.

Make sure autovacuum can run, tune autovacuum for large or busy tables, and use manual VACUUM FREEZE carefully when needed.


## 21. Performance Checks
```sql
SELECT
    category,
    name,
    setting,
    unit,
    CASE
        WHEN unit = '8kB' THEN pg_size_pretty(setting::numeric * 8 * 1024)
        WHEN unit = 'kB' THEN pg_size_pretty(setting::numeric * 1024)
        WHEN unit = 'MB' THEN pg_size_pretty(setting::numeric * 1024 * 1024)
        WHEN unit = 'GB' THEN pg_size_pretty(setting::numeric * 1024 * 1024 * 1024)
        ELSE setting
    END AS pretty_value,
    context,
    source,
    pending_restart,
    boot_val,
    reset_val,
    short_desc
FROM pg_settings
WHERE name IN (
    -- Connection / concurrency
    'max_connections',
    'superuser_reserved_connections',
    'reserved_connections',

    -- Memory
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'temp_buffers',
    'effective_cache_size',
    'huge_pages',

    -- Planner / optimizer
    'random_page_cost',
    'seq_page_cost',
    'cpu_tuple_cost',
    'cpu_index_tuple_cost',
    'cpu_operator_cost',
    'effective_io_concurrency',
    'default_statistics_target',
    'constraint_exclusion',
    'enable_partition_pruning',
    'enable_partitionwise_join',
    'enable_partitionwise_aggregate',
    'jit',

    -- Parallelism
    'max_worker_processes',
    'max_parallel_workers',
    'max_parallel_workers_per_gather',
    'max_parallel_maintenance_workers',
    'parallel_setup_cost',
    'parallel_tuple_cost',

    -- WAL / checkpoints
    'wal_level',
    'wal_compression',
    'wal_buffers',
    'checkpoint_timeout',
    'checkpoint_completion_target',
    'max_wal_size',
    'min_wal_size',
    'synchronous_commit',
    'full_page_writes',

    -- Autovacuum / vacuum
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_naptime',
    'autovacuum_vacuum_threshold',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_threshold',
    'autovacuum_analyze_scale_factor',
    'autovacuum_vacuum_cost_delay',
    'autovacuum_vacuum_cost_limit',
    'vacuum_cost_delay',
    'vacuum_cost_limit',
    'vacuum_freeze_min_age',
    'vacuum_freeze_table_age',
    'autovacuum_freeze_max_age',

    -- Statistics / tracking
    'track_activities',
    'track_activity_query_size',
    'track_counts',
    'track_io_timing',
    'track_wal_io_timing',
    'compute_query_id',
    'shared_preload_libraries',

    -- Logging / diagnostics
    'log_min_duration_statement',
    'log_lock_waits',
    'deadlock_timeout',
    'log_temp_files',
    'auto_explain.log_min_duration',

    -- Replication
    'max_wal_senders',
    'max_replication_slots',
    'hot_standby',
    'hot_standby_feedback',
    'wal_sender_timeout',
    'wal_receiver_timeout'
)
ORDER BY
    CASE
        WHEN category ILIKE 'Resource Usage%' THEN 1
        WHEN category ILIKE 'Query Tuning%' THEN 2
        WHEN category ILIKE 'Write-Ahead Log%' THEN 3
        WHEN category ILIKE 'Autovacuum%' THEN 4
        WHEN category ILIKE 'Statistics%' THEN 5
        WHEN category ILIKE 'Reporting and Logging%' THEN 6
        WHEN category ILIKE 'Replication%' THEN 7
        ELSE 99
    END,
    category,
    name;
```

### For AWS RDS/Aurora, this is especially useful because source and pending_restart tell you whether a value came from the parameter group and whether it needs a restart.
```sql
SELECT
    name,
    setting,
    unit,
    context,
    source,
    pending_restart,
    short_desc
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'effective_cache_size',
    'random_page_cost',
    'effective_io_concurrency',
    'max_worker_processes',
    'max_parallel_workers',
    'max_parallel_workers_per_gather',
    'wal_buffers',
    'checkpoint_timeout',
    'checkpoint_completion_target',
    'max_wal_size',
    'min_wal_size',
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_scale_factor',
    'autovacuum_vacuum_cost_limit',
    'autovacuum_vacuum_cost_delay',
    'track_io_timing',
    'compute_query_id',
    'shared_preload_libraries',
    'log_min_duration_statement',
    'log_lock_waits',
    'log_temp_files'
)
ORDER BY name;
```

### Check memory risk:
```sql
WITH settings AS (
    SELECT
        MAX(CASE WHEN name = 'max_connections' THEN setting::numeric END) AS max_connections,
        MAX(CASE WHEN name = 'work_mem' THEN setting::numeric END) AS work_mem_raw,
        MAX(CASE WHEN name = 'work_mem' THEN unit END) AS work_mem_unit,
        MAX(CASE WHEN name = 'maintenance_work_mem' THEN setting::numeric END) AS maintenance_work_mem_raw,
        MAX(CASE WHEN name = 'maintenance_work_mem' THEN unit END) AS maintenance_work_mem_unit
    FROM pg_settings
    WHERE name IN (
        'max_connections',
        'work_mem',
        'maintenance_work_mem'
    )
),
converted AS (
    SELECT
        max_connections,
        CASE
            WHEN work_mem_unit = '8kB' THEN work_mem_raw * 8 / 1024
            WHEN work_mem_unit = 'kB' THEN work_mem_raw / 1024
            WHEN work_mem_unit = 'MB' THEN work_mem_raw
            WHEN work_mem_unit = 'GB' THEN work_mem_raw * 1024
            ELSE NULL
        END AS work_mem_mb,
        CASE
            WHEN maintenance_work_mem_unit = '8kB' THEN maintenance_work_mem_raw * 8 / 1024
            WHEN maintenance_work_mem_unit = 'kB' THEN maintenance_work_mem_raw / 1024
            WHEN maintenance_work_mem_unit = 'MB' THEN maintenance_work_mem_raw
            WHEN maintenance_work_mem_unit = 'GB' THEN maintenance_work_mem_raw * 1024
            ELSE NULL
        END AS maintenance_work_mem_mb
    FROM settings
)
SELECT
    max_connections,
    work_mem_mb,
    ROUND(max_connections * work_mem_mb, 2) AS theoretical_work_mem_mb,
    maintenance_work_mem_mb
FROM converted;
```

** Important caveat: max_connections × work_mem is not actual memory usage. It is a worst-case exposure check. One backend can use multiple work_mem allocations at once for sorts, hashes, joins, and parallel query workers.

## end




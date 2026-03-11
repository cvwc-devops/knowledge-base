# PostgreSQL scripts

## 1) Blocked locks (find blocker + victim, then kill blocker)
**Show who is blocking whom**
```
SELECT
  a.pid                         AS blocked_pid,
  a.usename                     AS blocked_user,
  a.state                       AS blocked_state,
  now() - a.query_start         AS blocked_for,
  left(a.query, 120)            AS blocked_query,

  b.pid                         AS blocking_pid,
  b.usename                     AS blocking_user,
  b.state                       AS blocking_state,
  now() - b.query_start         AS blocking_for,
  left(b.query, 120)            AS blocking_query
FROM pg_stat_activity a
JOIN pg_locks l1 ON l1.pid = a.pid AND NOT l1.granted
JOIN pg_locks l2 ON l2.locktype = l1.locktype
  AND l2.database IS NOT DISTINCT FROM l1.database
  AND l2.relation IS NOT DISTINCT FROM l1.relation
  AND l2.page IS NOT DISTINCT FROM l1.page
  AND l2.tuple IS NOT DISTINCT FROM l1.tuple
  AND l2.virtualxid IS NOT DISTINCT FROM l1.virtualxid
  AND l2.transactionid IS NOT DISTINCT FROM l1.transactionid
  AND l2.classid IS NOT DISTINCT FROM l1.classid
  AND l2.objid IS NOT DISTINCT FROM l1.objid
  AND l2.objsubid IS NOT DISTINCT FROM l1.objsubid
  AND l2.pid <> l1.pid
JOIN pg_stat_activity b ON b.pid = l2.pid
ORDER BY blocked_for DESC;
```

**Terminate the blocker (use the blocking_pid)**
```
SELECT pg_terminate_backend(<blocking_pid>);
```
> Tip: if the blocker is “idle in transaction”, jump to section 2 and kill those first.

## 2) Idle in transaction (usually the worst offender)
**Find them**
```
SELECT
  pid, usename, application_name, client_addr,
  now() - xact_start AS xact_age,
  state,
  left(query, 160) AS query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

**Kill the worst ones (example: older than 5 minutes)**
```
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '5 minutes'
  AND pid <> pg_backend_pid();
```
## 3) Runaway / long-running query (CPU/I/O burn)
**Find long-running active queries**
```
SELECT
  pid, usename, application_name, client_addr,
  now() - query_start AS runtime,
  state,
  wait_event_type, wait_event,
  left(query, 200) AS query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY runtime DESC;
```

**First try cancel (safer), then terminate if needed**
```
-- cancel query only
SELECT pg_cancel_backend(<pid>);

-- if it ignores cancel / keeps coming back
SELECT pg_terminate_backend(<pid>);
```

**Bulk example (active > 10 minutes):**
```
SELECT pg_cancel_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '10 minutes'
  AND pid <> pg_backend_pid();
```

## 4) Too many connections / pool misbehavior
Who is using connections**
```
SELECT
  datname,
  usename,
  application_name,
  state,
  count(*) AS connections
FROM pg_stat_activity
GROUP BY 1,2,3,4
ORDER BY connections DESC;
```

**Kill “idle” sessions from a noisy app (keep your session)**
```
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE application_name = 'your_app_name'
  AND state = 'idle'
  AND pid <> pg_backend_pid();
```

**Kill everything for a user/db (last resort)**
```
-- by database
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'mydb'
  AND pid <> pg_backend_pid();

-- by user
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'app_user'
  AND pid <> pg_backend_pid();
```

**Confirm what you’re about to kill**
```
SELECT pid, usename, application_name, client_addr, state,
       now() - coalesce(xact_start, query_start) AS age,
       left(query, 120) AS query
FROM pg_stat_activity
WHERE pid IN (<pid1>, <pid2>, <pid3>);
```

**Your current session PID (exclude it)**
```
SELECT pg_backend_pid();
```

---

## 1) Session wait events (closest mental match)
```
SELECT
  pid,
  wait_event_type,
  wait_event,
  state,
  now() - query_start AS runtime,
  left(query, 120) AS query
FROM pg_stat_activity
WHERE wait_event IS NOT NULL;
```

> This tells you:
> - what sessions are waiting on
> - why they are stalled (lock, IO, LWLock, client, etc.)

## 2) Lock-level visibility
```
SELECT
  l.pid,
  l.locktype,
  l.mode,
  l.granted,
  a.usename,
  left(a.query, 120) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
ORDER BY l.granted, l.pid;
```
## 3) Aggregate wait time (cluster-wide)
```
SELECT * FROM pg_stat_bgwriter;
```

> For IO pressure and checkpoint behavior.

## 4) If you want timing → you need extensions
```
SELECT
  calls,
  total_time,
  mean_time,
  rows,
  left(query, 120) AS query
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 20;
```
> pg_stat_statements (must be enabled)

## 5) For deep wait profiling (advanced)
- auto_explain (log slow plans)
- log_lock_waits = on
- log_min_duration_statement
- pg_wait_sampling (extension, sampling-based)

## 6) Compare Map
| Oracle → | PostgreSQL |
| ----------------- | ---------------------------- |
| V$SESSION         | pg_stat_activity             |
| V$SESSION_EVENT   | wait_event_type / wait_event |
| V$SYSTEM_EVENT    | logs + bgwriter stats        |
| pg_db_event_timers| not present                  |
| AWR               | pg_stat_statements + logs    |

> pg_db_event_timers → not a PostgreSQL object

In Postgres you compose the picture from:
- pg_stat_activity
- pg_locks
- pg_stat_statements
- logs / extensions

---

## 1) Make sure the extension is available on the system
**Check (inside psql)**
```
SELECT name, installed_version
FROM pg_available_extensions
WHERE name = 'pg_stat_statements';
```
> If it appears → binaries are installed.
> If not → you need the contrib package.

**Install OS package (if missing)**
- RHEL / Rocky / Alma / Amazon Linux
```
sudo yum install postgresql-contrib
# or for versioned installs
sudo yum install postgresql14-contrib
```
- Ubuntu / Debian
```
sudo apt install postgresql-contrib
# or versioned
sudo apt install postgresql-14
```

## 2) Enable it in postgresql.conf (required)
This is **mandatory**. The extension will not work without it.
```
shared_preload_libraries = 'pg_stat_statements'
```

If you already have entries:
```
shared_preload_libraries = 'pg_stat_statements,pg_hint_plan'
```

## 3) Restart PostgreSQL (reload is NOT enough)
```
sudo systemctl restart postgresql
# or
pg_ctl restart
```
> No restart → extension silently won’t collect data.

## 4) Create the extension (per database)
Connect to the target DB:
```
CREATE EXTENSION pg_stat_statements;
```

Verify:
```
SELECT * FROM pg_stat_statements LIMIT 1;
```

## 5) Recommended (but optional) tuning
Add these to postgresql.conf:
```
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.track_utility = off
pg_stat_statements.save = on
```
> Restart again if you change them.

## 6) Permissions (Postgres 10+)
To let non-superusers read stats:
```
GRANT pg_read_all_stats TO your_role;
```

**Common failure modes (seen a lot)**
> | Symptom	| Cause |
> | -------	| ----- |
> | relation "pg_stat_statements" does not exist	| Missed CREATE EXTENSION |
> | Empty stats	| No restart after preload |
> | permission denied	| Missing pg_read_all_stats |
> | Stats reset on restart	| pg_stat_statements.save = off |

**Quick sanity check**
Run this and you should see real data:
```
SELECT
  calls,
  round(total_time::numeric, 2) AS total_ms,
  round(mean_time::numeric, 2) AS avg_ms,
  left(query, 100) AS query
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

---

## 1) PostgreSQL logs

### A. Where logs are (depends on install)
Systemd (most Linux distros)
```
journalctl -u postgresql
```

**Follow live:**
```
journalctl -u postgresql -f
```
> File-based logging (very common)

**Check inside psql:**
```
SHOW log_directory;
SHOW log_filename;
SHOW data_directory;
```

**Typical paths:**
- /var/lib/pgsql/14/data/log/
- /var/log/postgresql/
- /var/lib/postgresql/14/main/log/

**Tail:**
```
tail -f /var/log/postgresql/postgresql-*.log
```

### B. Turn on useful logging (not noisy)
In postgresql.conf:
```
logging_collector = on
log_line_prefix = '%m [%p] %u@%d '
log_min_duration_statement = 1000   # ms
log_lock_waits = on
deadlock_timeout = 1s
```

Reload is enough here:
```
SELECT pg_reload_conf();
```

> What you get
> - Slow queries
> - Lock waits + deadlocks
> - PID you can immediately kill

### C. Filter logs like an adult
Examples:
```
grep -i "lock wait" postgresql.log
grep -i "deadlock" postgresql.log
grep -i "duration:" postgresql.log | sort -nr
```

## 2) bgwriter stats (IO + checkpoint pressure)
### A. Current stats
```
SELECT * FROM pg_stat_bgwriter;
```

Key columns to watch:
| Column | Meaning |
| ------ | ------- |
| checkpoints_timed | Normal scheduled checkpoints |
| checkpoints_req | Forced checkpoints (bad if high) |
| checkpoint_write_time | Time spent writing during checkpoints |
| buffers_backend | Backends forced to write their own buffers |
| buffers_backend_fsync | Backend fsyncs (very bad) |
| buffers_alloc | Buffer churn |

### B. Interpreting bgwriter pain (quick rules)
🚨 High checkpoints_req
- max_wal_size too small

🚨 High buffers_backend
- bgwriter can’t keep up
- increase shared_buffers, tune bgwriter

🚨 Any buffers_backend_fsync > 0
- storage or checkpoint config problem
- this should be ~0

### C. Snapshot deltas (what matters)
Raw counters are cumulative. Do this:
```
SELECT
  now() AS ts,
  checkpoints_timed,
  checkpoints_req,
  buffers_checkpoint,
  buffers_backend,
  buffers_clean,
  buffers_alloc
FROM pg_stat_bgwriter;
```
> Run it again 5–10 minutes later and compare deltas.

### D. Reset counters (only when you mean it)
```
SELECT pg_stat_reset_shared('bgwriter');
```
> Do this before a load test or incident window.

## 3) Glue logs + bgwriter together (real diagnosis)
Pattern you’ll see
- Logs show slow commits / lock waits
- bgwriter shows:
- - rising checkpoints_req
- - rising buffers_backend

> WAL or checkpoint pressure is stalling writers.

## 4) Bonus: minimal “incident mode” config
Use this temporarily during trouble:
```
log_min_duration_statement = 500
log_lock_waits = on
deadlock_timeout = 500ms
```
> Reload, observe, then roll back.

---

## TL;DR
1️⃣ Logs (live) → identify PIDs, waits, slow queries
2️⃣ pg_stat_bgwriter → see if IO / checkpoints are the root cause
3️⃣ Correlate timestamps
4️⃣ Fix config, then kill sessions

---


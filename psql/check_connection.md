## 1) Prove where the socket is (or should be)
Run:
```
sudo -u postgres ls -la /var/lib/pgsql/13/data/.s.PGSQL.5432*
sudo -u postgres ss -lpn | egrep '(:5432|postgres)'
```
## 2) Connect using the correct socket directory (quick fix)
Try:
```
sudo -u postgres psql -h /var/lib/pgsql/13/data -p 5432 -c "select 1;"
```
> If that works, you’ve confirmed it’s purely a socket-path mismatch.

## 3) Why your current setup is painful

If unix_socket_directories='.', Postgres puts the socket inside the data dir, which is typically 0700 owned by postgres. That prevents regular users/services from reaching it unless they run as postgres (root can, most others can’t). It’s also just nonstandard.

## 4) Permanent fix (recommended): move socket to /var/run/postgresql

### 1) Create the runtime dir with correct perms:
```
sudo mkdir -p /var/run/postgresql
sudo chown postgres:postgres /var/run/postgresql
sudo chmod 775 /var/run/postgresql
```

### 2) Edit postgresql.conf (likely /var/lib/pgsql/13/data/postgresql.conf) and set:
```
unix_socket_directories = '/var/run/postgresql'
# optional hardening/usability:
# unix_socket_permissions = 0770
# unix_socket_group = 'postgres'
```

### 3) Restart:
```
pg_ctl stop -D /var/lib/pgsql/13/data -m fast
pg_ctl start -D /var/lib/pgsql/13/data
```

### 4) Verify socket now exists where psql expects:
```
ls -la /var/run/postgresql/.s.PGSQL.5432*
psql -c "select 1;"
```

## 5) If the socket file doesn’t exist anywhere
Then Postgres might be up but not listening (or failed early and left a PID briefly). Check the logs it told you about:
```
sudo -u postgres tail -n 200 /var/lib/pgsql/13/data/log/*.log
```

---

## If socket login still fails after uncommenting local ... peer
Two common gotchas:
### 1) Your command still uses TCP
Make sure you don’t pass -h at all:
```
sudo -u postgres psql -c "select 1;"
```

### 2) Postgres is still down / stale pid file

If it’s down, fix the postmaster.pid situation first (as discussed earlier), then start via systemd:
```
sudo systemctl start postgresql-13
sudo journalctl -u postgresql-13 -n 80 --no-pager
```

**Quick note on your monitoring warning**
> That [WARN] psql local query failed will go away if either:
> - the check runs as postgres and uses socket (local ... peer), or
> - it uses TCP with a real password (host ... scram-sha-256 + .pgpass).

### 3) Last try.
```
sudo systemctl status postgresql-13 --no-pager
sudo -u postgres psql -c "select 1;"   # after uncommenting local peer
```
---

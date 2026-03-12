# Basic checks for Linux and PostgresSQL

## Linux
### Core commands 
```bash
ssh -i key.pem user@host
sudo -i
ls -lah
cd /var /etc /opt
cat less tail -f
grep -R "pattern"
find / -name filename
df -h
du -sh *
free -m
uptime
top / htop
ps aux | grep process
```

### Services & logs
```bash
systemctl status postgresql
systemctl restart postgresql
journalctl -u postgresql
journalctl -xe
```

### Users & permissions
```bash
id
whoami
groups
chmod 644 file
chmod 755 dir
chown user:group file

sudo -u postgres createuser app_user

sudo -u postgres createuser --login --createdb --pwprompt app_user

Create db and assign ownership 

sudo -u postgres createdb mydb -O app_user
```

### Networking basics
```bash
ss -lntp
netstat -plnt
curl localhost
ping
```

### Environment & files
```bash
env
echo $PATH
which psql
```

---

## PostgreSQL
### Connecting
```bash
psql -h localhost -U postgres
psql -d dbname

sudo -u postgres psql -c "CREATE USER app_user WITH PASSWORD 'strongpassword';"
```

### Inspecting the database
```sql

\l              -- list databases
\c dbname       -- connect
\dt             -- list tables
\d table_name   -- table schema
\du             -- users
\conninfo

-- One-time installation
\i install_health_report_function.sql
SELECT * FROM run_health_report();
SELECT * FROM run_health_summary();
SELECT * FROM run_health_critical();
SELECT * FROM has_critical_alerts();
SELECT * FROM health_alerts where severity = ‘CRITICAL’;
```

### Roles & permissions
```sql
CREATE ROLE user LOGIN PASSWORD 'pass';
GRANT CONNECT ON DATABASE db TO user;
GRANT SELECT, INSERT ON table TO user;
ALTER ROLE user CREATEDB;

REVOKE CONNECT ON DATABASE db2 FROM app_user;
GRANT CONNECT ON DATABASE db1 TO app_user;

CREATE ROLE app_user
  LOGIN
  PASSWORD 'strongpassword'
  CREATEDB
  CREATEROLE;


GRANT CONNECT ON DATABASE mydb TO app_user;

GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER USER app_user WITH PASSWORD 'newpassword';

 Verify 
\du
\l
```

### Database health checks
```sql
SELECT version();
SELECT now();
SELECT pg_database_size(current_database());
SELECT * FROM pg_stat_activity;
```

### Backups (VERY common)
```sql
pg_dump dbname > db.sql
pg_dump -Fc dbname > db.dump
pg_restore -d dbname db.dump
```

### Configuration awareness
```sql
SHOW config_file;
SHOW hba_file;
SHOW data_directory;
```

**Know where configs usually live**
```bash
/etc/postgresql/*/main/postgresql.conf
/etc/postgresql/*/main/pg_hba.conf
```

**And how to reload:**
```sql
SELECT pg_reload_conf();
```

### PostgreSQL Configuration Files

1. pg_hba.conf (MOST IMPORTANT)
Controls who can connect, from where, and how.

Common locations:
```bash
/etc/postgresql/15/main/pg_hba.conf
/var/lib/pgsql/data/pg_hba.conf

Example:
# TYPE  DATABASE  USER      ADDRESS         METHOD
local   all       postgres                  peer
local   all       app_user                  md5
host    mydb      app_user  10.0.0.0/16     md5
host    all       all       0.0.0.0/0       scram-sha-256
```

**After changing**
```sql
SELECT pg_reload_conf();
```
Or
```bash
sudo systemctl reload postgresql
```

2. postgresql.conf
Controls server behavior.
Common settings you may need:
```
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 1GB
log_statement = 'all'

/etc/postgresql/15/main/postgresql.conf
sudo systemctl restart postgresql
```

3. pg_ident.conf
Used for user mapping with peer or ident auth.

Example:
```
mymap   linuxuser   dbuser
```
**Common Gotchas**</br>
✔ User exists but cannot connect → check pg_hba.conf</br>
✔ User can connect but no access to tables → GRANT privileges</br>
✔ Remote connection fails → listen_addresses + firewall</br>
✔ Password auth not working → auth method mismatch (md5 vs scram-sha-256)</br>

## PostgreSQL Query 
### SQL fundamentals
```sql
SELECT
FROM
WHERE
JOIN (INNER / LEFT)
GROUP BY
HAVING
ORDER BY
LIMIT
```

### Indexing
```sql
CREATE INDEX idx_name ON table(column);
DROP INDEX idx_name;
```

### Performance analysis
```sql
EXPLAIN SELECT ...
EXPLAIN ANALYZE SELECT ...
```
	•	Spot sequential scans
	•	Know when an index helps
	•	Avoid SELECT *
	•	Rewrite inefficient joins/subqueries

```sql
SET enable_nestloop = off;
EXPLAIN your_query;
EXPLAIN (ANALYZE, BUFFERS) your_query;
```

**table**
```sql
CREATE TABLE customers (
    id bigint PRIMARY KEY,
    name text
);

CREATE TABLE orders (
    id bigint PRIMARY KEY,
    customer_id bigint REFERENCES customers(id),
    created_at timestamptz
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT o.id, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.id = 42;
```

**Other**</br>
Forcing hash-join</br>
SET enable_nestloop = off;</br>

**What work_mem does**</br>
	•	work_mem is the memory PostgreSQL allocates per operation, per query.</br>
	•	Hash joins build a hash table in memory using this memory.</br>
	•	If the hash table won’t fit in work_mem, PostgreSQL may:</br>
	1.	Spill it to disk (slower)</br>
	2.	Avoid hash join entirely and choose a nested loop or merge join</br>

So, larger work_mem → hash joins become cheaper.</br>
Smaller work_mem → nested loops may be preferred.</br>

SET work_mem = '64kB';  -- tiny</br>
Nested Loop is considered as work_mem is tiny and not in MB or GB sizing </br>

**Reason:**</br>
•	Hash join requires a hash table of several MB or GB</br>
•	64kB is too small → hash join would spill</br>
•	Planner thinks nested loop is cheaper</br>

SET work_mem = '64MB'; </br>
Reason:</br>
•	64MB can hold the hash table in memory</br>
•	Hash join now cheaper than repeated nested loop lookups</br>
•	Execution time drops significantly for large tables</br>

**How the planner estimates cost**
•	It calculates hash table memory = #rows × row width × overhead</br>
•	If estimated size > work_mem, it adds spill cost</br>
•	If cost of spilling > nested loop cost, nested loop wins</br>


Example:
```sql
-- Bad
SELECT * FROM orders WHERE customer_id IN (
  SELECT id FROM customers WHERE country = 'US'
);

-- Better
SELECT o.*
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE c.country = 'US';
```

**What is a partial index?**

A partial index is an index built on a subset of a table, defined by a WHERE condition:
```sql
CREATE INDEX idx_orders_recent
ON orders(created_at)
WHERE created_at >= now() - interval '30 days';
```

**The table is very large but only a small subset is queried**

Example:</br>
•	orders table: 50 million rows</br>
•	Only last 30 days are queried</br>
•	Partial index contains 500,000 rows → 1% of table</br>

Here:</br>
•	Partial index scan: tiny and fast</br>
•	Full index scan: larger, more I/O, more cache pressure</br>

**Reduced maintenance cost**</br>
	•	Updates/inserts only affect rows that satisfy the WHERE condition.</br>
	•	Full index would need updates for every insert/update.</br>
	•	Partial index → smaller, cheaper to maintain, less WAL/log overhead </br>

A partial index beats a full index when your query consistently filters on a small, predictable subset of the table. Smaller index = faster scans + lower maintenance.

---

## JSONB
```sql
CREATE TABLE events (
    id serial PRIMARY KEY,
    data jsonb,
    created_at timestamptz DEFAULT now()
);

Sample JSONB data might look like:

{"type": "click", "user_id": 123, "page": "home"}
{"type": "purchase", "user_id": 456, "amount": 19.99}
{"type": "click", "user_id": 789, "page": "checkout"}

CREATE INDEX idx_events_purchase
ON events ((data->>'user_id'))
WHERE data->>'type' = 'purchase';

Query:
SELECT id. FROM events
WHERE data->>'type' = 'purchase'
  AND data->>'user_id' = '456';

Want index scans only modify
CREATE INDEX idx_events_purchase_include
ON events ((data->>'user_id')) INCLUDE (created_at)
WHERE data->>'type' = 'purchase';

New Query:
SELECT id, created_at
FROM events
WHERE data->>'type' = 'purchase'
  AND data->>'user_id' = '456';
```

## Use GIN:
Instead of storing one entry per row, it stores one entry per key/value inside a row.
This makes it ideal for columns containing multiple values per row, like arrays or JSONB objects.
This allows PostgreSQL to quickly find all rows that contain a particular key or value.

```sql
CREATE TABLE events (
    id serial PRIMARY KEY,
    data jsonb
);

CREATE INDEX idx_events_gin ON events USING GIN (data);

SELECT *
FROM events
WHERE data @> '{"type": "purchase"}';

Full text search 

CREATE TABLE articles (
    id serial PRIMARY KEY,
    content text
);

CREATE INDEX idx_articles_content_gin ON articles USING GIN (to_tsvector('english', content));

SELECT *
FROM articles
WHERE to_tsvector('english', content) @@ to_tsquery('postgres');
```

## Arrays
```sql
CREATE TABLE users (
    id serial PRIMARY KEY,
    tags text[]
);

CREATE INDEX idx_users_tags_gin ON users USING GIN (tags);

SELECT *
FROM users
WHERE tags @> ARRAY['premium'];
```

Why not B-tree?</br>
	•	B-tree indexes only work for single-value comparisons (like = or <).</br>
	•	B-tree cannot efficiently handle:</br>
	•	Multi-key columns (jsonb, arrays)</br>
	•	Containment (@>), existence (?), or full-text search</br>
	•	GIN solves this problem by indexing every element inside a value.</br>

Considerations</br>
	•	GIN indexes are slower to update than B-tree.</br>
	•	Inserting/updating rows is more expensive.</br>
	•	But read queries become much faster for multi-key searches.</br>
	•	For very large tables or read-heavy workloads, GIN is usually a win.</br>
	•	Partial GIN indexes can further reduce size if queries only focus on a subset.</br>

Use a GIN index when you need to efficiently query multi-value, nested, or full-text data.
B-tree is great for single values; GIN is for containment and existence searches inside complex types.

```sql
EXPLAIN (ANALYZE)
SELECT *
FROM events
WHERE data @> '{"type": "purchase"}';
```

---

## Decision-Making Under Ambiguity

When unsure:</br>
	1.	Inspect before acting</br>
	2.	Prefer reversible actions</br>
	3.	Document assumptions</br>

Example:</br>

“Disk almost full”</br>
	•	First: du -sh /var/*</br>
	•	Check logs before deleting</br>
	•	Compress or rotate, not blindly remove</br>

## Time Management Strategy (Critical)

Suggested workflow during the exercise</br>
	1.	5–10 min: Read everything, write a task list</br>
	2.	Do easy wins first</br>
	3.	Parallelize thinking (while queries run, document)</br>
	4.	Leave 15–20 min for reporting</br>

If something blocks you:</br>
	•	Document the issue</br>
	•	State what you would do next</br>

## Report structure

1. Overview</br>
2. System Administration Tasks</br>
   - What was requested</br>
   - What was done</br>
   - Commands used</br>
   - Result</br>
3. PostgreSQL Administration</br>
4. Query Work</br>
   - Original issue</br>
   - Changes made</br>
   - Performance impact</br>
5. Issues / Risks / Assumptions</br>
6. Recommendations</br>

---

## Practice
	•	Launch an EC2 or local Linux VM</br>
	•	SSH using key auth</br>
	•	Install PostgreSQL</br>
	•	Create DB, user, tables</br>
	•	Write 3 joins + indexes</br>
	•	Break Postgres → fix it</br>
	•	Write a 1-page report</br>

## Mindset
	•	Calm troubleshooting</br>
	•	Clean thinking</br>
	•	Safe changes</br>
	•	Clear communication</br>

---

## Setup Example
```sql
CREATE ROLE app_user LOGIN PASSWORD 'secret';
GRANT CONNECT ON DATABASE mydb TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
```

```bash
pg_hba.conf:
host mydb app_user 0.0.0.0/0 md5
```

**Reload config**
Which Config Changes Need Restart vs Reload
| Change Type | Reload | Restart |
| ----------- | ------ | ------- |
| pg_hba.conf | Yes | No |
| Logging settings | Yes | No |
| listen_addresses | No | Yes |
| port | No | Yes |
| shared_buffers | No | Yes |
| max_connections | No | Yes |
| SSL enable/disable | No | Yes |

> always attempt reload first and only restart if the configuration change explicitly requires it.

---

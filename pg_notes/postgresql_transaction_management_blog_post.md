# Mastering PostgreSQL Transaction Management

**Control the commit, contain the failure, and keep your data honest.**

PostgreSQL does not lose data because it is careless. Data gets lost, duplicated, half-written, or quietly rolled back because humans misunderstand where a transaction begins, where it ends, and what happens after an error.

Transaction management is one of those topics that looks simple from far away. You run `BEGIN`, do some work, then `COMMIT`. Done.

But in real systems, the edge cases matter:

- `AUTOCOMMIT` is usually on, even when you think you are “not using transactions.”
- `BEGIN` and `START TRANSACTION` do the same thing, but the client prompt can reveal hidden state.
- `now()` and `clock_timestamp()` can disagree on purpose.
- `SAVEPOINT` lets you recover from a failed statement without throwing away the whole transaction.
- PL/pgSQL exception blocks create hidden savepoints.
- Once a transaction is aborted, `COMMIT` does not save your work. It rolls back.

This article walks through the parts of PostgreSQL transaction management that actually matter in production. The goal is not academic purity. The goal is operational clarity.

By the end, you should know how to control transaction boundaries, reason about failures, and avoid the classic trap where one bad statement poisons the whole transaction.

---

## A Transaction Is a Unit of Trust

A transaction is PostgreSQL’s way of saying: either all of this work becomes visible together, or none of it does.

That is the practical meaning of atomicity.

When you insert a customer, create their account record, write an audit row, and update a billing table, those steps should succeed as one unit. If step three fails, you usually do not want steps one and two left behind as production clutter.

PostgreSQL gives you transaction control so you can decide where that unit begins and ends.

The sharp part is this: PostgreSQL is always operating through transactions. Even a single standalone `SELECT` runs inside a transaction. When autocommit is enabled, the client quietly wraps each statement in its own transaction and commits it immediately.

That is why transaction management is not optional. You are using it whether you acknowledge it or not.

### Takeaway

**Every statement in PostgreSQL runs in a transaction. The only question is whether you control the boundary or let the client control it for you.**

---

## 1. Autocommit Mode: The Default That Explains Everything

In `psql`, `AUTOCOMMIT` is on by default. That means each standalone SQL statement is automatically committed as soon as it completes successfully.

Check it like this:

```sql
\echo :AUTOCOMMIT
```

Typical output:

```text
on
```

Now run two inserts:

```sql
INSERT INTO t2 VALUES (1);
INSERT INTO t2 VALUES (2);
```

With autocommit on, PostgreSQL treats those as two separate transactions. If the first insert succeeds, it is committed. If the second insert fails, the first insert stays committed.

That behavior is useful for simple interactive work. It is dangerous when you assume several statements will succeed or fail together.

Here is the subtle part: after you issue `BEGIN`, `AUTOCOMMIT` still shows as on in `psql`.

```sql
BEGIN;
\echo :AUTOCOMMIT
END;
```

Output:

```text
on
```

That does not mean PostgreSQL is auto-committing inside your explicit transaction. It means the client setting remains enabled. The explicit transaction block still controls commit behavior until you end it.

Think of `AUTOCOMMIT` as a client-side behavior, not a server-side law.

### Example: Autocommit vs Explicit Transaction

Autocommit behavior:

```sql
CREATE TABLE demo_autocommit (
    id integer PRIMARY KEY
);

INSERT INTO demo_autocommit VALUES (1); -- committed immediately
INSERT INTO demo_autocommit VALUES (1); -- fails, duplicate key
```

The first row remains because it already committed.

Explicit transaction behavior:

```sql
CREATE TABLE demo_explicit (
    id integer PRIMARY KEY
);

BEGIN;
INSERT INTO demo_explicit VALUES (1);
INSERT INTO demo_explicit VALUES (1); -- fails
COMMIT;
```

The transaction enters an aborted state after the duplicate key error. The final `COMMIT` does not save the successful insert. PostgreSQL rolls the transaction back.

### Production lesson

Autocommit is fine for one-off statements. It is not enough for multi-step business operations.

Use explicit transactions when the work must succeed or fail as one unit.

### Takeaway

**Autocommit commits every successful standalone statement. Use `BEGIN` when several statements must live or die together.**

---

## 2. Transaction IDs and `pg_current_xact_id()`

PostgreSQL uses transaction IDs, often called XIDs, to track transactional work internally.

A useful way to see this is with `pg_current_xact_id()`.

```sql
SELECT pg_current_xact_id();
```

When autocommit is on, each call runs in its own transaction. That means repeated calls can return different values.

```sql
-- first call
SELECT pg_current_xact_id();
-- result: 2324

-- second call
SELECT pg_current_xact_id();
-- result: 2325
```

That surprises people because both statements are just reads. But in PostgreSQL, even a `SELECT` has a transaction context.

Inside an explicit transaction, the value stays stable for the life of the transaction:

```sql
BEGIN;

SELECT pg_current_xact_id();
-- result: 2401

SELECT pg_current_xact_id();
-- result: 2401

COMMIT;
```

The reason is simple: both calls are part of the same transaction.

You can also watch XIDs change in `psql`:

```sql
\watch 2
```

That reruns the previous query every two seconds. If the previous query was `SELECT pg_current_xact_id();` and autocommit is on, you will see transaction IDs advance.

### Why this matters

XIDs are not just trivia. They matter for visibility, vacuum behavior, wraparound risk, and debugging transaction-heavy workloads.

You do not need to memorize every internal detail to use PostgreSQL well. But you should understand this core truth:

A transaction is not only a logical concept. PostgreSQL tracks it deeply.

### Takeaway

**With autocommit on, each statement gets its own transaction. Even simple reads can consume a transaction ID.**

---

## 3. `BEGIN` vs `START TRANSACTION`

In PostgreSQL, these are equivalent:

```sql
BEGIN;
```

```sql
START TRANSACTION;
```

Both open an explicit transaction block.

You can close that block with either:

```sql
COMMIT;
```

or:

```sql
END;
```

`END` is accepted as a synonym for `COMMIT`.

Example:

```sql
BEGIN;
-- statements
END;
```

Same behavior:

```sql
START TRANSACTION;
-- statements
COMMIT;
```

Most teams prefer `BEGIN` and `COMMIT` because they are short and familiar. Some prefer `START TRANSACTION` because it reads more explicitly in scripts.

Pick one style and make it boring.

### The `psql` prompt tells a story

In `psql`, the prompt can change based on transaction state.

A normal prompt might look like:

```text
batch2=#
```

Inside an active transaction, it may look like:

```text
batch2=*#
```

If the transaction is aborted after an error, it may look like:

```text
batch2=!#
```

That exclamation mark is your warning siren. It means the current transaction is broken. PostgreSQL will reject most commands until you issue `ROLLBACK`.

### Takeaway

**`BEGIN` and `START TRANSACTION` both open a transaction. In `psql`, watch the prompt: `*` means active, `!` means aborted.**

---

## 4. `now()` vs `clock_timestamp()` Inside Transactions

Time in PostgreSQL has nuance.

Two functions look similar but behave very differently inside a transaction:

```sql
now()
```

and:

```sql
clock_timestamp()
```

`now()` returns the transaction start time. It is stable for the whole transaction.

`clock_timestamp()` returns the actual wall-clock time at the moment the function is called. It can change within the same transaction.

Example:

```sql
BEGIN;

SELECT now(), clock_timestamp();
-- now: 2024-07-06 09:52:12
-- clk: 2024-07-06 09:52:24

-- one minute later, same transaction
SELECT now(), clock_timestamp();
-- now: 2024-07-06 09:52:12
-- clk: 2024-07-06 09:53:17

COMMIT;
```

Both functions return timestamp-with-time-zone style values, but they answer different questions.

`now()` answers:

> When did this transaction begin?

`clock_timestamp()` answers:

> What time is it right now?

### Which one should you use?

Use `now()` when you want all rows changed in the same transaction to share a consistent timestamp.

That is usually what you want for `created_at`, `updated_at`, audit events, and batch identifiers.

Use `clock_timestamp()` when you need elapsed wall-clock timing inside a long-running transaction.

For example:

```sql
BEGIN;

SELECT clock_timestamp() AS started_at;

-- expensive operation here

SELECT clock_timestamp() AS finished_at;

COMMIT;
```

### Production trap

If you are benchmarking SQL steps inside one transaction, do not use `now()` to measure elapsed time. It will not move. Use `clock_timestamp()`.

### Takeaway

**`now()` is transaction-stable. `clock_timestamp()` is wall-clock live. Choose based on whether you need consistency or elapsed time.**

---

## 5. Explicit Savepoints and Partial Rollback

A normal transaction gives you all-or-nothing behavior.

A savepoint gives you a controlled checkpoint inside a transaction.

That means you can say:

> Keep the earlier work, try this risky step, and if it fails, roll back only the risky part.

Basic pattern:

```sql
BEGIN;

-- safe work
SAVEPOINT checkpoint_name;

-- risky work
ROLLBACK TO checkpoint_name;

-- continue
COMMIT;
```

Here is a concrete example:

```sql
CREATE TABLE t1 (
    id integer PRIMARY KEY
);

START TRANSACTION;

INSERT INTO t1 VALUES (1), (2);

SAVEPOINT after_two_rows;

INSERT INTO t1 VALUES (2); -- duplicate key error

ROLLBACK TO after_two_rows;

SELECT * FROM t1;
-- rows 1 and 2 still exist inside the transaction

COMMIT;
```

The failed insert is discarded. The earlier successful inserts survive.

This is extremely useful in batch processing, import jobs, and migration scripts where some steps are allowed to fail without losing the whole unit of work.

### Do not confuse savepoints with commits

A savepoint is not a mini-commit.

It does not make data durable on its own. If the outer transaction rolls back, all savepoint-protected work rolls back too.

This matters:

```sql
BEGIN;

INSERT INTO t1 VALUES (10);
SAVEPOINT s1;
INSERT INTO t1 VALUES (11);

ROLLBACK;
```

Both rows are gone.

The savepoint only gives you a place to roll back to inside the current transaction. It does not protect you from a full transaction rollback.

### Releasing a savepoint

You can release a savepoint when you no longer need it:

```sql
RELEASE SAVEPOINT after_two_rows;
```

That tells PostgreSQL you are done with that checkpoint.

### Takeaway

**A savepoint is a recovery marker inside a transaction. It lets you undo part of the work without losing everything.**

---

## 6. Hidden Savepoints in PL/pgSQL Exception Blocks

PL/pgSQL has a powerful behavior that many developers use without realizing it.

A block with an `EXCEPTION` handler creates an implicit savepoint.

Example:

```sql
BEGIN
    INSERT INTO demo(n) VALUES (101);

    BEGIN
        INSERT INTO demo(n) VALUES (arg);
    EXCEPTION WHEN OTHERS THEN
        NULL; -- swallow the error
    END;

    -- row 101 survives even if arg fails
END;
```

The inner block is protected. If the insert using `arg` fails, PostgreSQL rolls back the work from that inner block only. The outer block can continue.

That is the hidden savepoint.

This behavior is useful, but it has a cost.

Exception handling is not free. If you wrap every row of a large import in a PL/pgSQL exception block, you may create a lot of subtransaction overhead.

Sometimes that is worth it. Sometimes it is a performance smell.

### Better pattern: avoid exceptions when possible

Instead of relying on exception handling for duplicate keys, use conflict-aware SQL when it fits:

```sql
INSERT INTO demo(n)
VALUES (101)
ON CONFLICT DO NOTHING;
```

Or:

```sql
INSERT INTO demo(id, value)
VALUES (1, 'new value')
ON CONFLICT (id)
DO UPDATE SET value = EXCLUDED.value;
```

Use exceptions for exceptional cases. Use normal SQL control flow for expected conflicts.

### Takeaway

**A PL/pgSQL `EXCEPTION` block rolls back only the protected inner block by using an implicit savepoint. Powerful, but not free.**

---

## 7. No `COMMIT` Inside Functions

A PostgreSQL function is not a good place to perform transaction control.

In older PostgreSQL versions, trying to `COMMIT` inside a function raises an error like:

```text
ERROR: invalid transaction termination
CONTEXT: PL/pgSQL function mocktransfunc1(integer)
line 4 at COMMIT
```

Example:

```sql
SELECT mocktransfunc1(4);
```

Result:

```text
ERROR: invalid transaction termination
```

Why?

Because functions run inside the transaction context of the caller. They do not own the transaction boundary.

If you need mid-execution transaction commits, use a procedure instead of a function, and call it correctly.

Procedures were introduced to support transaction control in server-side code under the right conditions.

A simplified pattern:

```sql
CREATE PROCEDURE process_batches()
LANGUAGE plpgsql
AS $$
BEGIN
    -- batch 1
    COMMIT;

    -- batch 2
    COMMIT;
END;
$$;

CALL process_batches();
```

But be careful. Transaction control inside procedures has rules. You cannot use it from every calling context. If the caller is already inside an explicit transaction block, transaction control from the procedure can still be restricted.

The bigger design question is this:

Should the database routine decide when to commit, or should the application/job controller decide?

In many production systems, keeping transaction boundaries at the application or job orchestration layer is easier to reason about.

### Takeaway

**Functions should not own commits. Use procedures only when you intentionally need server-side transaction control.**

---

## 8. The Aborted Transaction State: The `!` Prompt

This is the PostgreSQL transaction behavior every developer should learn early:

Once a transaction hits an unhandled error, the transaction is aborted.

At that point, most further SQL commands are rejected until you roll back.

Example:

```sql
BEGIN;

SELECT mocktransfunc1(1); -- duplicate key error

COMMIT;
```

You might expect `COMMIT` to save whatever succeeded before the error.

It does not.

After the error, the transaction is poisoned. `COMMIT` effectively becomes a rollback.

You may see output like:

```text
ROLLBACK
```

The table remains unchanged.

This is why savepoints matter. Without a savepoint, you cannot recover part of the work after an unhandled error inside the same transaction.

### Correct recovery

If you hit an unhandled error:

```sql
ROLLBACK;
```

Then start again.

If you expect a step might fail and you want to keep earlier work:

```sql
BEGIN;

INSERT INTO trans_demo VALUES (1);

SAVEPOINT before_risky_step;

-- risky statement
INSERT INTO trans_demo VALUES (1); -- duplicate key

ROLLBACK TO before_risky_step;

-- continue safely
INSERT INTO trans_demo VALUES (2);

COMMIT;
```

### Production lesson

Do not ignore transaction errors in logs.

A single failed statement can cause a long-running transaction to sit around doing nothing useful while holding locks, blocking vacuum cleanup, or confusing application retry logic.

### Takeaway

**After an unhandled error, the transaction is aborted. You must `ROLLBACK`, or roll back to a savepoint if you created one earlier.**

---

## 9. A Practical Transaction Playbook

Here is the field-tested version.

### Use autocommit for simple one-off work

Good:

```sql
SELECT count(*) FROM orders;
```

Fine:

```sql
UPDATE feature_flags
SET enabled = false
WHERE name = 'old_checkout';
```

Risky if it is part of a larger business operation.

### Use explicit transactions for multi-step changes

Good:

```sql
BEGIN;

UPDATE accounts
SET balance = balance - 100
WHERE id = 1;

UPDATE accounts
SET balance = balance + 100
WHERE id = 2;

INSERT INTO ledger_entries(from_account, to_account, amount)
VALUES (1, 2, 100);

COMMIT;
```

That is one logical operation. It deserves one transaction.

### Use savepoints for controlled failures

Good:

```sql
BEGIN;

INSERT INTO import_runs(filename, started_at)
VALUES ('customers.csv', now())
RETURNING id;

SAVEPOINT before_optional_cleanup;

DELETE FROM staging_customers
WHERE bad_record = true;

-- if cleanup fails
ROLLBACK TO before_optional_cleanup;

COMMIT;
```

### Use `now()` for consistent timestamps

Good:

```sql
BEGIN;

UPDATE orders
SET processed_at = now()
WHERE status = 'ready';

INSERT INTO audit_log(action, created_at)
VALUES ('processed ready orders', now());

COMMIT;
```

Every row gets the same transaction timestamp.

### Use `clock_timestamp()` for measuring elapsed time

Good:

```sql
SELECT clock_timestamp() AS step_started;

-- run expensive step

SELECT clock_timestamp() AS step_finished;
```

### Avoid exception-driven control flow when SQL has a better tool

Instead of catching duplicate key errors row by row, prefer:

```sql
INSERT INTO users(email)
VALUES ('a@example.com')
ON CONFLICT (email) DO NOTHING;
```

Or use `ON CONFLICT DO UPDATE` when you need an upsert.

### Keep transactions short

Long transactions can hold locks, delay cleanup, and increase operational risk.

A good transaction does the required work and exits.

A bad transaction opens, waits on user input, calls external services, sleeps, or processes a huge batch without checkpoints.

### Takeaway

**Use transactions intentionally. Keep them short, protect risky sections with savepoints, and never assume a failed transaction can still commit.**

---

## 10. Common Mistakes and Better Moves

### Mistake: Assuming `COMMIT` always commits

Bad assumption:

```sql
BEGIN;
-- statement succeeds
-- next statement fails
COMMIT;
```

Better understanding:

After an unhandled error, `COMMIT` results in rollback.

Use:

```sql
ROLLBACK;
```

or savepoints when partial recovery is required.

### Mistake: Measuring time with `now()` inside a transaction

Bad:

```sql
BEGIN;
SELECT now();
-- long operation
SELECT now();
COMMIT;
```

Both values can be the same.

Better:

```sql
SELECT clock_timestamp();
```

### Mistake: Using PL/pgSQL exceptions for expected conflicts

Bad pattern:

```sql
BEGIN
    INSERT INTO users(email) VALUES (email_arg);
EXCEPTION WHEN unique_violation THEN
    NULL;
END;
```

Better when conflict is expected:

```sql
INSERT INTO users(email)
VALUES (email_arg)
ON CONFLICT DO NOTHING;
```

### Mistake: Opening a transaction too early

Bad application flow:

```text
BEGIN
call remote API
wait for response
write rows
send notification
COMMIT
```

Better:

```text
call remote API first
prepare data
BEGIN
write rows
COMMIT
send notification after commit
```

Do not hold database locks while waiting on the outside world.

### Mistake: Forgetting transaction state in `psql`

If your prompt shows `!`, stop and clean up.

```sql
ROLLBACK;
```

Then continue.

### Takeaway

**Most transaction bugs come from false assumptions: assuming time moves, assuming commits always commit, or assuming errors are local when they are not.**

---

## 11. A Realistic Migration Example

Suppose you need to migrate customer records from a staging table into production tables. You want the migration run itself to be tracked. You also want bad rows to be skipped without killing the entire run.

One approach:

```sql
BEGIN;

INSERT INTO migration_runs(name, started_at)
VALUES ('customer_import_2024_07_06', now())
RETURNING id;

SAVEPOINT before_customer_batch;

INSERT INTO customers(id, email, created_at)
SELECT id, email, now()
FROM staging_customers
WHERE email IS NOT NULL
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email;

INSERT INTO migration_audit(event, created_at)
VALUES ('customer batch imported', now());

COMMIT;
```

This version avoids exception-driven duplicate handling by using `ON CONFLICT`.

If you have a truly risky optional operation, protect it:

```sql
BEGIN;

INSERT INTO migration_runs(name, started_at)
VALUES ('cleanup_after_customer_import', now());

SAVEPOINT before_cleanup;

DELETE FROM staging_customers
WHERE imported = true;

-- If this fails, use:
-- ROLLBACK TO before_cleanup;

COMMIT;
```

The broader strategy is simple:

1. Use explicit transactions for real units of work.
2. Use `ON CONFLICT` for expected uniqueness collisions.
3. Use savepoints for risky optional sections.
4. Use `now()` for consistent audit timestamps.
5. Roll back immediately after unhandled errors.

### Takeaway

**A good migration script is not just SQL that works. It is SQL that fails cleanly.**

---

## 12. Quick Reference Cheat Sheet

| Concept | What It Means | Use It When |
|---|---|---|
| `AUTOCOMMIT` | Client commits each standalone statement | Interactive one-off work |
| `BEGIN` | Starts explicit transaction | Multi-step atomic work |
| `START TRANSACTION` | Same as `BEGIN` | More verbose transaction start |
| `COMMIT` | Makes transaction changes durable | Transaction completed cleanly |
| `END` | Synonym for `COMMIT` | Rarely; `COMMIT` is clearer |
| `ROLLBACK` | Cancels whole transaction | Error or intentional abort |
| `SAVEPOINT` | Creates rollback marker | Partial recovery inside transaction |
| `ROLLBACK TO` | Rewinds to savepoint | Recover from risky step |
| `RELEASE SAVEPOINT` | Removes savepoint marker | Savepoint no longer needed |
| `now()` | Transaction start timestamp | Consistent row timestamps |
| `clock_timestamp()` | Current wall-clock timestamp | Measuring elapsed time |
| `pg_current_xact_id()` | Current transaction ID | Debugging transaction behavior |
| `psql` `*` prompt | Active transaction | Continue or commit/rollback |
| `psql` `!` prompt | Aborted transaction | Roll back now |

---

## Finally

PostgreSQL transaction management is not just about writing `BEGIN` and `COMMIT`. It is about knowing who controls the boundary, what happens when a statement fails, and how much of the work can still be saved.

The important rules are simple but unforgiving:

- Autocommit wraps each standalone statement in its own transaction.
- `BEGIN` and `START TRANSACTION` both open explicit transaction blocks.
- `now()` is frozen at transaction start; `clock_timestamp()` is live.
- Savepoints let you recover from part of a failed transaction.
- PL/pgSQL exception blocks use implicit savepoints.
- Functions should not control commits; use procedures only when that design is intentional.
- Once a transaction is aborted, `COMMIT` will not rescue it.

The punchline: PostgreSQL gives you precise tools. Use them deliberately.

A transaction should be small enough to reason about, strong enough to protect data integrity, and clear enough that the next engineer can understand what happens when something fails.

That is how you move from writing SQL that usually works to operating PostgreSQL with confidence.




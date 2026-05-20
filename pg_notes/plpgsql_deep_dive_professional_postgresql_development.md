# PL/pgSQL Deep Dive: Professional PostgreSQL Development with Examples

**Move business logic closer to the data — without turning your database into a mystery box.**

# PL/pgSQL Deep Dive: Professional PostgreSQL Development with Examples

PostgreSQL is not just a place to store data. It is a serious application platform hiding in plain sight.

Most teams start with PostgreSQL as a reliable relational database. They write tables, indexes, joins, migrations, and queries. Then the system grows. Business rules multiply. Data integrity gets harder. Race conditions appear. The application layer starts doing five round trips for work the database could have handled in one.

That is where **PL/pgSQL** earns its place.

PL/pgSQL is PostgreSQL’s procedural language. It lets you write functions, procedures, triggers, loops, conditional logic, exception handling, dynamic SQL, and reusable database-side workflows. Used well, it makes systems faster, safer, and easier to reason about. Used poorly, it becomes a pile of invisible business logic that nobody wants to touch.

This article is a practical deep dive for professional PostgreSQL development. We will cover when PL/pgSQL is useful, when it is dangerous, how to write clean functions, how to use triggers responsibly, how to handle errors, how to write dynamic SQL safely, and how to keep performance under control.

The goal is not to move your entire application into the database. The goal is sharper than that:

> Put the right logic in the right layer.

---

## Main Takeaways

- **PL/pgSQL is best for data-adjacent logic.** Validation, auditing, calculated writes, secure wrappers, maintenance jobs, and transactional workflows are strong fits.
- **Do not use PL/pgSQL as a dumping ground.** If the logic belongs to user experience, orchestration, external APIs, or complex domain workflows, keep it in the application layer.
- **Prefer set-based SQL first.** PL/pgSQL should coordinate SQL, not replace SQL with row-by-row procedural code.
- **Dynamic SQL must be treated like a loaded weapon.** Use `format()`, `%I`, `%L`, and `USING` parameters.
- **Triggers are powerful but easy to abuse.** Keep them small, predictable, documented, and observable.
- **Professional PL/pgSQL is operational code.** It needs naming conventions, tests, migrations, reviews, logging, and performance discipline.

---

# 1. What Is PL/pgSQL?

PL/pgSQL stands for **Procedural Language/PostgreSQL**. It extends SQL with programming constructs such as:

- Variables
- Conditional logic
- Loops
- Exceptions
- Functions
- Procedures
- Triggers
- Dynamic SQL
- Diagnostic messages

Plain SQL is declarative. You tell PostgreSQL what result you want. PL/pgSQL is procedural. You tell PostgreSQL what steps to run.

A simple PL/pgSQL function looks like this:

```sql
CREATE OR REPLACE FUNCTION add_tax(amount numeric, tax_rate numeric)
RETURNS numeric
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN amount + (amount * tax_rate);
END;
$$;
```

Usage:

```sql
SELECT add_tax(100, 0.23);
```

Result:

```text
123.00
```

That example is simple, but it shows the basic shape:

```sql
CREATE FUNCTION function_name(arguments)
RETURNS return_type
LANGUAGE plpgsql
AS $$
DECLARE
    -- variables go here
BEGIN
    -- executable statements go here
END;
$$;
```

## Takeaway

PL/pgSQL gives PostgreSQL procedural muscle. It is ideal when logic needs to execute close to the data, inside the same transaction, with direct access to tables, constraints, and indexes.

---

# 2. When Should You Use PL/pgSQL?

PL/pgSQL is not automatically better than application code. It is better for specific jobs.

Use PL/pgSQL when the work is tightly connected to data integrity, transactional consistency, or repeated database-side behavior.

Good use cases include:

- Enforcing complex validation rules
- Creating audit records
- Maintaining summary tables
- Wrapping sensitive queries behind controlled functions
- Running batch maintenance tasks
- Performing multi-step writes inside one transaction
- Building trigger logic
- Encapsulating repeated SQL patterns
- Reducing application round trips

Poor use cases include:

- Calling external APIs
- Rendering UI-specific logic
- Complex business workflows with many outside dependencies
- Logic that needs frequent product experimentation
- Anything your team cannot observe, test, or deploy safely

A useful rule:

> If the logic protects the data, PL/pgSQL may be the right home. If the logic explains the user journey, the application layer is usually better.

## Example: Good PL/pgSQL Fit

Suppose orders must never be marked as paid unless the payment total matches the order total.

```sql
CREATE OR REPLACE FUNCTION mark_order_paid(p_order_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_total numeric;
    v_payment_total numeric;
BEGIN
    SELECT total_amount
    INTO v_order_total
    FROM orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_payment_total
    FROM payments
    WHERE order_id = p_order_id
      AND status = 'settled';

    IF v_payment_total <> v_order_total THEN
        RAISE EXCEPTION
            'Cannot mark order % paid. Expected %, received %',
            p_order_id, v_order_total, v_payment_total;
    END IF;

    UPDATE orders
    SET status = 'paid',
        paid_at = now()
    WHERE id = p_order_id;
END;
$$;
```

This belongs close to the data because it protects an invariant: an order is paid only when settled payments match the order total.

## Takeaway

Use PL/pgSQL to guard data truth, not to hide application complexity.

---

# 3. Anatomy of a Professional PL/pgSQL Function

A professional function should be readable, predictable, and safe to change.

Here is a clean example:

```sql
CREATE OR REPLACE FUNCTION create_customer(
    p_email text,
    p_full_name text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id bigint;
BEGIN
    IF p_email IS NULL OR length(trim(p_email)) = 0 THEN
        RAISE EXCEPTION 'Email is required';
    END IF;

    IF p_full_name IS NULL OR length(trim(p_full_name)) = 0 THEN
        RAISE EXCEPTION 'Full name is required';
    END IF;

    INSERT INTO customers (email, full_name, created_at)
    VALUES (lower(trim(p_email)), trim(p_full_name), now())
    RETURNING id INTO v_customer_id;

    RETURN v_customer_id;
END;
$$;
```

Key details:

- Prefix parameters with `p_`.
- Prefix local variables with `v_`.
- Validate input early.
- Use `RETURNING ... INTO` to capture inserted IDs.
- Keep the function focused.
- Raise clear exceptions.

## Naming Convention

A simple naming convention prevents confusion:

```text
p_  input parameter
v_  local variable
r_  record variable
j_  json/jsonb variable
```

Example:

```sql
DECLARE
    v_total numeric;
    r_customer customers%ROWTYPE;
    j_payload jsonb;
```

This matters because PL/pgSQL functions often mix table columns, parameters, and variables. Clear names reduce mistakes.

## Takeaway

Clean PL/pgSQL starts with boring discipline: clear names, small functions, early validation, and explicit behavior.

---

# 4. Variables, Types, and `%TYPE`

Hardcoding types can make functions brittle. PostgreSQL gives you `%TYPE` and `%ROWTYPE` so variables can follow table definitions.

Example:

```sql
CREATE OR REPLACE FUNCTION get_customer_email(p_customer_id bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_email customers.email%TYPE;
BEGIN
    SELECT email
    INTO v_email
    FROM customers
    WHERE id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id;
    END IF;

    RETURN v_email;
END;
$$;
```

Here, `v_email` automatically uses the same type as `customers.email`.

For whole rows:

```sql
CREATE OR REPLACE FUNCTION get_customer_summary(p_customer_id bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    r_customer customers%ROWTYPE;
BEGIN
    SELECT *
    INTO r_customer
    FROM customers
    WHERE id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id;
    END IF;

    RETURN r_customer.full_name || ' <' || r_customer.email || '>';
END;
$$;
```

## Takeaway

Use `%TYPE` and `%ROWTYPE` when functions should track table structure. It makes schema changes less painful.

---

# 5. `SELECT INTO` and the `FOUND` Flag

In PL/pgSQL, `SELECT ... INTO` assigns query results to variables.

```sql
SELECT total_amount
INTO v_total
FROM orders
WHERE id = p_order_id;
```

After a SQL statement, PL/pgSQL sets the special boolean variable `FOUND`.

```sql
IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
END IF;
```

This pattern is common, but use it carefully. `FOUND` refers to the most recent relevant SQL command. If you run another statement before checking it, you may check the wrong thing.

Good:

```sql
SELECT email
INTO v_email
FROM customers
WHERE id = p_customer_id;

IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer % not found', p_customer_id;
END IF;
```

Risky:

```sql
SELECT email
INTO v_email
FROM customers
WHERE id = p_customer_id;

RAISE NOTICE 'Looking up customer';

IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer not found';
END IF;
```

The `RAISE NOTICE` itself is not the problem, but adding more statements between the query and the check makes the code easier to break later.

## `STRICT` Mode

You can require exactly one row:

```sql
SELECT email
INTO STRICT v_email
FROM customers
WHERE id = p_customer_id;
```

With `STRICT`:

- No rows causes an error.
- More than one row causes an error.
- Exactly one row succeeds.

This is useful when the data model expects one and only one match.

## Takeaway

Check `FOUND` immediately after the statement that matters. Use `INTO STRICT` when zero or multiple rows should be treated as bugs.

---

# 6. Control Flow: `IF`, `CASE`, and Loops

PL/pgSQL supports familiar control structures.

## `IF` Example

```sql
CREATE OR REPLACE FUNCTION customer_tier(p_total_spend numeric)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_total_spend >= 10000 THEN
        RETURN 'platinum';
    ELSIF p_total_spend >= 5000 THEN
        RETURN 'gold';
    ELSIF p_total_spend >= 1000 THEN
        RETURN 'silver';
    ELSE
        RETURN 'standard';
    END IF;
END;
$$;
```

## `CASE` Example

```sql
CREATE OR REPLACE FUNCTION normalize_order_status(p_status text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN CASE lower(trim(p_status))
        WHEN 'new' THEN 'pending'
        WHEN 'open' THEN 'pending'
        WHEN 'paid' THEN 'paid'
        WHEN 'complete' THEN 'completed'
        ELSE 'unknown'
    END;
END;
$$;
```

## Loop Example

```sql
CREATE OR REPLACE FUNCTION count_open_orders(p_customer_id bigint)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    r_order record;
    v_count integer := 0;
BEGIN
    FOR r_order IN
        SELECT id
        FROM orders
        WHERE customer_id = p_customer_id
          AND status IN ('pending', 'processing')
    LOOP
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;
```

That works, but it is not ideal. This is better:

```sql
CREATE OR REPLACE FUNCTION count_open_orders(p_customer_id bigint)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM orders
    WHERE customer_id = p_customer_id
      AND status IN ('pending', 'processing');

    RETURN v_count;
END;
$$;
```

The second version lets PostgreSQL do set-based work. That is usually faster and simpler.

## Takeaway

Loops are available, but they are not a license to ignore SQL. In PostgreSQL, set-based thinking usually wins.

---

# 7. Returning Data from PL/pgSQL

PL/pgSQL functions can return scalar values, rows, tables, or sets.

## Return One Value

```sql
CREATE OR REPLACE FUNCTION order_count()
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_count bigint;
BEGIN
    SELECT COUNT(*) INTO v_count FROM orders;
    RETURN v_count;
END;
$$;
```

## Return a Table

```sql
CREATE OR REPLACE FUNCTION recent_orders(p_limit integer DEFAULT 10)
RETURNS TABLE (
    order_id bigint,
    customer_id bigint,
    total_amount numeric,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT o.id, o.customer_id, o.total_amount, o.created_at
    FROM orders o
    ORDER BY o.created_at DESC
    LIMIT p_limit;
END;
$$;
```

Usage:

```sql
SELECT * FROM recent_orders(5);
```

## Return JSON

```sql
CREATE OR REPLACE FUNCTION customer_profile_json(p_customer_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    j_profile jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', c.id,
        'email', c.email,
        'full_name', c.full_name,
        'created_at', c.created_at
    )
    INTO j_profile
    FROM customers c
    WHERE c.id = p_customer_id;

    IF j_profile IS NULL THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id;
    END IF;

    RETURN j_profile;
END;
$$;
```

JSON-returning functions can be useful for APIs, reporting, and internal service boundaries.

## Takeaway

Use `RETURNS TABLE` for query-like functions and `jsonb` when the caller needs a structured payload.

---

# 8. Functions vs Procedures

PostgreSQL supports both functions and procedures.

Use a **function** when you want to return a value and call it from SQL:

```sql
SELECT calculate_discount(100, 'gold');
```

Use a **procedure** when you want to perform an action:

```sql
CALL refresh_customer_rollups();
```

Example procedure:

```sql
CREATE OR REPLACE PROCEDURE refresh_customer_rollups()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM customer_rollups;

    INSERT INTO customer_rollups (customer_id, order_count, total_spend, refreshed_at)
    SELECT
        customer_id,
        COUNT(*),
        SUM(total_amount),
        now()
    FROM orders
    GROUP BY customer_id;
END;
$$;
```

Call it:

```sql
CALL refresh_customer_rollups();
```

## Practical Difference

Functions are often better for reusable calculations, validations, and query integration. Procedures are better for operational actions and command-style workflows.

## Takeaway

Use functions for values. Use procedures for actions.

---

# 9. Triggers: Sharp Tool, Sharp Edges

Triggers run automatically when certain database events occur. They can fire on `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE`.

A common use case is automatically maintaining timestamps.

## Example: `updated_at` Trigger

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
```

Attach it to a table:

```sql
CREATE TRIGGER trg_customers_set_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

Now every update to `customers` refreshes `updated_at`.

## Trigger Variables

Inside trigger functions, PostgreSQL provides special variables:

- `NEW`: the new row for `INSERT` or `UPDATE`
- `OLD`: the old row for `UPDATE` or `DELETE`
- `TG_OP`: operation name such as `INSERT`, `UPDATE`, or `DELETE`
- `TG_TABLE_NAME`: table name
- `TG_SCHEMA_NAME`: schema name

## Audit Trigger Example

```sql
CREATE TABLE customer_audit_log (
    id bigserial PRIMARY KEY,
    customer_id bigint,
    operation text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_at timestamptz NOT NULL DEFAULT now()
);
```

Trigger function:

```sql
CREATE OR REPLACE FUNCTION audit_customers()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO customer_audit_log (customer_id, operation, new_data)
        VALUES (NEW.id, TG_OP, to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO customer_audit_log (customer_id, operation, old_data, new_data)
        VALUES (NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO customer_audit_log (customer_id, operation, old_data)
        VALUES (OLD.id, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;
```

Attach it:

```sql
CREATE TRIGGER trg_customers_audit
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION audit_customers();
```

## Trigger Discipline

Triggers should be:

- Small
- Deterministic
- Documented
- Tested
- Observable
- Rarely surprising

Avoid triggers that silently perform large unrelated work. Hidden side effects are how databases become haunted.

## Takeaway

Triggers are excellent for local invariants and audit trails. They are dangerous when they become invisible business workflows.

---

# 10. Dynamic SQL Done Safely

Dynamic SQL lets you build and run SQL strings at runtime.

Use it when table names, column names, or query structures are not known until execution time.

Basic form:

```sql
EXECUTE 'SELECT count(*) FROM customers';
```

But dynamic SQL becomes risky when values are concatenated directly.

Bad:

```sql
EXECUTE 'SELECT count(*) FROM ' || p_table_name;
```

This can break on weird names and may expose you to SQL injection.

Better:

```sql
EXECUTE format('SELECT count(*) FROM %I', p_table_name);
```

`%I` safely quotes identifiers such as table or column names.

For values, prefer `USING`:

```sql
CREATE OR REPLACE FUNCTION count_rows_matching(
    p_table_name text,
    p_column_name text,
    p_value text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_count bigint;
BEGIN
    EXECUTE format(
        'SELECT count(*) FROM %I WHERE %I = $1',
        p_table_name,
        p_column_name
    )
    INTO v_count
    USING p_value;

    RETURN v_count;
END;
$$;
```

Usage:

```sql
SELECT count_rows_matching('customers', 'status', 'active');
```

## `format()` Cheat Sheet

```text
%I = identifier, such as table or column name
%L = literal value
%s = raw string, use carefully
```

Best practice:

- Use `%I` for identifiers.
- Use `USING` for values.
- Avoid direct concatenation.
- Validate table and column names when possible.

## Safer Dynamic SQL with Whitelisting

```sql
CREATE OR REPLACE FUNCTION safe_customer_sort(p_sort_column text)
RETURNS TABLE (
    id bigint,
    email text,
    full_name text
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_sort_column NOT IN ('id', 'email', 'full_name', 'created_at') THEN
        RAISE EXCEPTION 'Invalid sort column: %', p_sort_column;
    END IF;

    RETURN QUERY EXECUTE format(
        'SELECT id, email, full_name FROM customers ORDER BY %I',
        p_sort_column
    );
END;
$$;
```

This protects the query by allowing only known columns.

## Takeaway

Dynamic SQL is powerful, but never trust raw input. Quote identifiers, bind values, and whitelist options.

---

# 11. Exception Handling

PL/pgSQL supports exception blocks.

```sql
BEGIN
    -- risky work
EXCEPTION
    WHEN unique_violation THEN
        -- recovery logic
END;
```

Example:

```sql
CREATE OR REPLACE FUNCTION create_customer_safe(
    p_email text,
    p_full_name text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id bigint;
BEGIN
    INSERT INTO customers (email, full_name, created_at)
    VALUES (lower(trim(p_email)), trim(p_full_name), now())
    RETURNING id INTO v_customer_id;

    RETURN v_customer_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Customer with email % already exists', p_email;
END;
$$;
```

## Use Exceptions Carefully

Exception blocks are not free. They add complexity and can hide real problems if overused.

Avoid this:

```sql
EXCEPTION
    WHEN others THEN
        RETURN NULL;
```

That is a production support nightmare. It swallows the actual problem and replaces it with mystery.

Better:

```sql
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Failed to create customer %. Original error: %',
            p_email, SQLERRM;
```

## Capturing Diagnostics

For deeper diagnostics:

```sql
CREATE OR REPLACE FUNCTION demo_error_diagnostics()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_state text;
    v_message text;
    v_detail text;
    v_hint text;
    v_context text;
BEGIN
    PERFORM 1 / 0;

EXCEPTION
    WHEN others THEN
        GET STACKED DIAGNOSTICS
            v_state = RETURNED_SQLSTATE,
            v_message = MESSAGE_TEXT,
            v_detail = PG_EXCEPTION_DETAIL,
            v_hint = PG_EXCEPTION_HINT,
            v_context = PG_EXCEPTION_CONTEXT;

        RAISE NOTICE 'state: %', v_state;
        RAISE NOTICE 'message: %', v_message;
        RAISE NOTICE 'detail: %', v_detail;
        RAISE NOTICE 'hint: %', v_hint;
        RAISE NOTICE 'context: %', v_context;
END;
$$;
```

## Takeaway

Handle expected errors. Re-raise unexpected errors with context. Never turn real failures into silent NULLs.

---

# 12. Transaction Behavior

A PL/pgSQL function runs inside the transaction of the statement that called it.

That means a function should usually not be treated as an independent transaction boundary. If it fails, the surrounding transaction may fail too.

Example:

```sql
BEGIN;

SELECT mark_order_paid(42);

COMMIT;
```

If `mark_order_paid(42)` raises an exception, the transaction is affected.

## Exception Blocks and Rollback Scope

Inside an exception block, PostgreSQL can roll back the work done inside that block while allowing the outer function to continue.

Example:

```sql
CREATE OR REPLACE FUNCTION try_insert_customer(p_email text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN
        INSERT INTO customers (email, full_name)
        VALUES (p_email, 'Unknown');

        RETURN 'inserted';

    EXCEPTION
        WHEN unique_violation THEN
            RETURN 'already exists';
    END;
END;
$$;
```

This pattern is useful, but do not overuse it as a substitute for clean conflict handling.

Often, SQL is better:

```sql
INSERT INTO customers (email, full_name)
VALUES ('a@example.com', 'Alice')
ON CONFLICT (email) DO NOTHING;
```

## Takeaway

Understand the transaction context. PL/pgSQL does not magically isolate bad logic from the caller.

---

# 13. Performance: Think Like PostgreSQL

PL/pgSQL performance problems usually come from one of five places:

1. Row-by-row loops over large data sets
2. Missing indexes
3. Repeated queries inside loops
4. Poor dynamic SQL
5. Functions hiding expensive work from reviewers

## Bad Pattern: Query in a Loop

```sql
FOR r_customer IN SELECT id FROM customers LOOP
    SELECT COUNT(*)
    INTO v_count
    FROM orders
    WHERE customer_id = r_customer.id;

    UPDATE customer_stats
    SET order_count = v_count
    WHERE customer_id = r_customer.id;
END LOOP;
```

This may run thousands or millions of queries.

Better:

```sql
INSERT INTO customer_stats (customer_id, order_count)
SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id
ON CONFLICT (customer_id)
DO UPDATE SET order_count = EXCLUDED.order_count;
```

That is set-based and far more scalable.

## Use `EXPLAIN`

You can inspect SQL used inside PL/pgSQL by extracting it and running:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id;
```

Do this before blaming PL/pgSQL. Many function performance issues are plain SQL performance issues wearing a procedural jacket.

## Avoid Volatile Work When Possible

PostgreSQL functions can be marked by volatility:

```sql
IMMUTABLE
STABLE
VOLATILE
```

Example:

```sql
CREATE OR REPLACE FUNCTION cents_to_dollars(p_cents integer)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN p_cents / 100.0;
END;
$$;
```

Use the correct volatility marker:

- `IMMUTABLE`: same input always returns same output
- `STABLE`: same result within a statement
- `VOLATILE`: result can change anytime or function modifies data

Do not lie to the optimizer. Wrong volatility markings can produce incorrect behavior.

## Takeaway

PL/pgSQL is not a performance shortcut by default. The win comes from fewer round trips, better transactional locality, and set-based SQL.

---

# 14. Security: `SECURITY DEFINER` Without Regret

Functions can run with the privileges of the caller or the function owner.

Default behavior is `SECURITY INVOKER`.

```sql
CREATE FUNCTION ...
SECURITY INVOKER
```

Sometimes you want controlled privilege escalation. For example, users should be able to call a function that inserts an audit-safe record, but they should not have direct table access.

```sql
CREATE OR REPLACE FUNCTION app_create_ticket(
    p_title text,
    p_body text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, pg_temp
AS $$
DECLARE
    v_ticket_id bigint;
BEGIN
    INSERT INTO tickets (title, body, created_by, created_at)
    VALUES (p_title, p_body, current_user, now())
    RETURNING id INTO v_ticket_id;

    RETURN v_ticket_id;
END;
$$;
```

Critical detail:

```sql
SET search_path = app, pg_temp
```

Without a controlled `search_path`, a malicious user may be able to influence object resolution in unsafe ways.

## Security Checklist

For `SECURITY DEFINER` functions:

- Set an explicit `search_path`.
- Keep the function small.
- Validate all inputs.
- Avoid unsafe dynamic SQL.
- Own the function with a dedicated role, not a superuser.
- Grant execute permissions intentionally.
- Revoke broad defaults when needed.

Example:

```sql
REVOKE ALL ON FUNCTION app_create_ticket(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_create_ticket(text, text) TO app_user;
```

## Takeaway

`SECURITY DEFINER` is useful, but it must be treated as privileged code. Small mistakes can become access-control bugs.

---

# 15. Debugging PL/pgSQL

The first debugging tool most developers meet is `RAISE NOTICE`.

```sql
RAISE NOTICE 'Processing order %', p_order_id;
```

Other levels include:

```sql
RAISE DEBUG 'Debug details';
RAISE INFO 'Informational message';
RAISE WARNING 'Warning message';
RAISE EXCEPTION 'Fatal error';
```

## Example

```sql
CREATE OR REPLACE FUNCTION debug_order_total(p_order_id bigint)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric;
BEGIN
    RAISE NOTICE 'Loading order %', p_order_id;

    SELECT total_amount
    INTO v_total
    FROM orders
    WHERE id = p_order_id;

    RAISE NOTICE 'Order %, total %', p_order_id, v_total;

    RETURN v_total;
END;
$$;
```

## Professional Debugging Habits

- Log IDs, not full sensitive payloads.
- Use `RAISE NOTICE` during development, not as permanent noise.
- Add targeted diagnostics around risky sections.
- Test functions with known fixtures.
- Inspect query plans for embedded SQL.
- Version functions through migrations.

## Takeaway

Debugging database code is easier when functions are small, inputs are explicit, and side effects are limited.

---

# 16. Testing PL/pgSQL

Database functions need tests like any other code.

At minimum, test:

- Happy paths
- Missing records
- Invalid inputs
- Permission boundaries
- Conflict handling
- Trigger side effects
- Transaction behavior

Simple manual test:

```sql
BEGIN;

SELECT create_customer('test@example.com', 'Test User');
SELECT * FROM customers WHERE email = 'test@example.com';

ROLLBACK;
```

The `ROLLBACK` keeps the test from polluting the database.

## Example Test Script

```sql
BEGIN;

INSERT INTO customers (id, email, full_name)
VALUES (1001, 'alice@example.com', 'Alice Example');

INSERT INTO orders (id, customer_id, total_amount, status)
VALUES (2001, 1001, 50.00, 'pending');

SELECT mark_order_paid(2001);

-- Inspect result
SELECT id, status, paid_at
FROM orders
WHERE id = 2001;

ROLLBACK;
```

For serious projects, consider a database testing framework or migration-driven integration tests in CI.

## Takeaway

If a PL/pgSQL function protects business-critical data, it deserves automated tests.

---

# 17. Deployment and Versioning

PL/pgSQL should be deployed through migrations, not hand-edited in production.

Good migration style:

```sql
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id bigint)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric;
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;

    RETURN v_total;
END;
$$;
```

But be careful: `CREATE OR REPLACE FUNCTION` cannot change everything. If you change argument types or return types, you may need to drop and recreate the function.

## Deployment Checklist

Before shipping a function:

- Does it have a clear owner?
- Is it in the correct schema?
- Are permissions explicit?
- Does it have tests?
- Does it avoid unsafe dynamic SQL?
- Does it use indexes effectively?
- Does it have comments where needed?
- Is rollback planned?

## Add Comments

```sql
COMMENT ON FUNCTION calculate_order_total(bigint)
IS 'Calculates the current total for an order from order_items.';
```

Comments help future engineers understand why a function exists.

## Takeaway

Treat PL/pgSQL as application code. Ship it through review, migration, testing, and rollback discipline.

---

# 18. Common Anti-Patterns

## Anti-Pattern 1: Business Logic Swamp

A little database logic is helpful. Too much hidden database logic is dangerous.

Symptom:

- Nobody knows why rows change.
- Application behavior depends on undocumented triggers.
- Tests pass locally but fail in production.
- Debugging requires reading ten functions and six triggers.

Fix:

- Keep triggers local and narrow.
- Document side effects.
- Move workflow logic back to the application layer when appropriate.

## Anti-Pattern 2: Row-by-Row Everything

Symptom:

```sql
FOR r IN SELECT * FROM big_table LOOP
    UPDATE other_table ...
END LOOP;
```

Fix:

Use set-based SQL.

## Anti-Pattern 3: Swallowing Errors

Symptom:

```sql
EXCEPTION WHEN others THEN
    RETURN NULL;
```

Fix:

Raise meaningful errors.

## Anti-Pattern 4: Unsafe Dynamic SQL

Symptom:

```sql
EXECUTE 'DELETE FROM ' || p_table || ' WHERE id = ' || p_id;
```

Fix:

```sql
EXECUTE format('DELETE FROM %I WHERE id = $1', p_table)
USING p_id;
```

## Anti-Pattern 5: Overusing Triggers

Symptom:

Every table action launches a chain of hidden writes.

Fix:

Use triggers only when automatic behavior is truly required.

## Takeaway

Most PL/pgSQL failures are not syntax failures. They are design failures.

---

# 19. A Realistic End-to-End Example

Let’s build a small workflow for invoices.

Rules:

- An invoice has line items.
- Invoice total is calculated from line items.
- Invoice can be finalized only if it has at least one line item.
- Once finalized, the invoice total is stored.
- Finalized invoices cannot be modified.

## Tables

```sql
CREATE TABLE invoices (
    id bigserial PRIMARY KEY,
    customer_id bigint NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    total_amount numeric NOT NULL DEFAULT 0,
    finalized_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (status IN ('draft', 'finalized', 'void'))
);

CREATE TABLE invoice_items (
    id bigserial PRIMARY KEY,
    invoice_id bigint NOT NULL REFERENCES invoices(id),
    description text NOT NULL,
    quantity numeric NOT NULL CHECK (quantity > 0),
    unit_price numeric NOT NULL CHECK (unit_price >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);
```

## Calculate Invoice Total

```sql
CREATE OR REPLACE FUNCTION calculate_invoice_total(p_invoice_id bigint)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric;
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total
    FROM invoice_items
    WHERE invoice_id = p_invoice_id;

    RETURN v_total;
END;
$$;
```

## Prevent Changes to Finalized Invoices

```sql
CREATE OR REPLACE FUNCTION prevent_finalized_invoice_item_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_status text;
    v_invoice_id bigint;
BEGIN
    v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);

    SELECT status
    INTO v_status
    FROM invoices
    WHERE id = v_invoice_id;

    IF v_status = 'finalized' THEN
        RAISE EXCEPTION 'Cannot modify items for finalized invoice %', v_invoice_id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;
```

Attach trigger:

```sql
CREATE TRIGGER trg_prevent_finalized_invoice_item_changes
BEFORE INSERT OR UPDATE OR DELETE ON invoice_items
FOR EACH ROW
EXECUTE FUNCTION prevent_finalized_invoice_item_changes();
```

## Finalize Invoice

```sql
CREATE OR REPLACE FUNCTION finalize_invoice(p_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_item_count integer;
    v_total numeric;
    v_status text;
BEGIN
    SELECT status
    INTO v_status
    FROM invoices
    WHERE id = p_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invoice % not found', p_invoice_id;
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'Invoice % is not in draft status', p_invoice_id;
    END IF;

    SELECT COUNT(*)
    INTO v_item_count
    FROM invoice_items
    WHERE invoice_id = p_invoice_id;

    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Invoice % cannot be finalized without line items', p_invoice_id;
    END IF;

    v_total := calculate_invoice_total(p_invoice_id);

    UPDATE invoices
    SET status = 'finalized',
        total_amount = v_total,
        finalized_at = now(),
        updated_at = now()
    WHERE id = p_invoice_id;
END;
$$;
```

## Why This Works

This is a good PL/pgSQL use case because the rules are data-centered:

- Protect invoice integrity.
- Prevent edits after finalization.
- Calculate totals inside the database.
- Lock the invoice row during finalization.
- Keep the operation transactional.

The application can call one function:

```sql
SELECT finalize_invoice(123);
```

Instead of orchestrating several fragile steps across the network.

## Takeaway

PL/pgSQL shines when it turns a risky multi-step data workflow into one safe transactional operation.

---

# 20. Professional Style Guide

Use this as a practical style guide for production PL/pgSQL.

## Function Design

- One function, one job.
- Prefer explicit parameters.
- Return meaningful values.
- Avoid hidden side effects unless the function name makes them obvious.
- Keep functions short enough to review.

## SQL Style

- Prefer set-based SQL.
- Use aliases clearly.
- Avoid `SELECT *` in stable interfaces.
- Use `RETURNING` instead of a second lookup.
- Add indexes for function query paths.

## Error Handling

- Validate early.
- Raise specific exceptions.
- Avoid `WHEN others` unless you re-raise or add useful context.
- Do not hide failures.

## Security

- Be careful with `SECURITY DEFINER`.
- Set `search_path` explicitly.
- Grant execute permissions intentionally.
- Validate dynamic inputs.

## Operations

- Deploy through migrations.
- Add comments for important functions.
- Test with realistic data.
- Review execution plans.
- Monitor slow queries.

## Takeaway

Professional PL/pgSQL is boring in the best way: clear, tested, secure, and predictable.

---

# 21. Final Thoughts

PL/pgSQL is one of PostgreSQL’s most underrated professional tools.

It lets you enforce rules where the data lives. It reduces network chatter. It wraps risky multi-step workflows in a single transaction. It gives you triggers, reusable functions, controlled privilege boundaries, and powerful database-side automation.

But the same power can hurt you.

Bad PL/pgSQL hides logic. Bad triggers surprise people. Bad dynamic SQL creates security risks. Bad loops quietly destroy performance. Bad exception handling turns real failures into production folklore.

The professional approach is simple:

- Use PL/pgSQL where the database is the right owner of the logic.
- Keep application logic in the application when that is the cleaner boundary.
- Write functions like code you expect another engineer to debug at 3 a.m.
- Prefer set-based SQL.
- Make side effects obvious.
- Treat security and deployment seriously.

PL/pgSQL is not about being clever. It is about being precise.

And in database engineering, precision is what keeps systems alive.

---

# Quick Reference Summary

## Best Uses

- Data validation
- Auditing
- Trigger functions
- Transactional workflows
- Secure database APIs
- Batch maintenance
- Summary refreshes

## Avoid For

- UI logic
- External API orchestration
- Large hidden workflows
- Complex product rules that change constantly
- Row-by-row processing when set-based SQL works

## Safety Rules

- Validate inputs.
- Use `%I` for identifiers.
- Use `USING` for values in dynamic SQL.
- Avoid swallowing errors.
- Keep triggers small.
- Deploy through migrations.
- Test with real edge cases.


**PL/pgSQL is not where logic goes to hide. It is where data rules go to become enforceable.**


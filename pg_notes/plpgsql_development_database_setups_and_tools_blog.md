# PL/pgSQL Development: Database Setups and Tools with Examples

**Build closer to the data. Ship safer database logic. Debug like a pro.**

# PL/pgSQL Development: Database Setups and Tools with Examples

PL/pgSQL is where PostgreSQL stops being “just a database” and starts acting like a programmable data engine.

Used well, it lets you move business logic closer to the data, reduce application round trips, protect consistency, and automate high-value database behavior. Used poorly, it becomes a hidden maze of slow functions, mysterious triggers, and deployment pain.

The difference is not magic. It is setup, tooling, structure, and discipline.

This guide gives you a practical, blog-ready walkthrough of PL/pgSQL development: how to set up a working database environment, which tools matter, how to write useful functions and procedures, how to debug them, how to test them, and how to ship them without turning your production database into a crime scene.

The goal is simple: make PL/pgSQL development feel less like “database wizardry” and more like normal engineering.

---

## Quick Takeaways

PL/pgSQL is PostgreSQL’s built-in procedural language. It gives you variables, loops, conditions, exception handling, triggers, and stored routines inside the database.

Use PL/pgSQL when the logic belongs near the data: validation, auditing, complex write workflows, batch processing, trigger behavior, security-controlled routines, and consistency-sensitive operations.

Do not use PL/pgSQL as a dumping ground for all application logic. Keep it focused, observable, tested, and version-controlled.

A good PL/pgSQL workflow needs five things: a disposable local database, repeatable schema setup, a strong SQL editor, migration tooling, and a testing/debugging habit.

Docker Compose, `psql`, pgAdmin, SQL migration tools, and extensions like `plpgsql_check` can turn stored procedure work from guesswork into a real development loop.

---

## What Is PL/pgSQL?

PL/pgSQL stands for Procedural Language/PostgreSQL. It is PostgreSQL’s native procedural language for writing database-side functions, procedures, and triggers.

Plain SQL is excellent for describing what data you want. PL/pgSQL is useful when you also need procedural flow:

- Declare variables
- Run conditional logic
- Loop over records
- Raise exceptions
- Catch errors
- Build trigger functions
- Wrap multi-step operations
- Return scalar values, rows, tables, or custom result sets

A tiny example:

```sql
CREATE OR REPLACE FUNCTION add_tax(amount numeric, tax_rate numeric)
RETURNS numeric
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN round(amount + (amount * tax_rate), 2);
END;
$$;
```

Call it like this:

```sql
SELECT add_tax(100, 0.23);
```

Result:

```text
123.00
```

That is the small version. In real systems, PL/pgSQL often powers audit logs, account balance updates, queue processing, tenant isolation rules, data cleanup jobs, and carefully controlled write paths.

---

## Why Developers Use PL/pgSQL

PL/pgSQL is not a replacement for application code. It is a tool for logic that benefits from living inside the database.

The strongest use cases are usually these:

### 1. Reduce Round Trips

Instead of sending five separate SQL statements from an application to the database, you can wrap the workflow in one function call.

Example:

```sql
SELECT create_customer_order(
    p_customer_id := 42,
    p_product_id := 9,
    p_quantity := 3
);
```

The function can validate the customer, check inventory, create the order, create order lines, update stock, and return the new order ID in one controlled transaction.

### 2. Protect Critical Rules

Some rules should not depend on every app developer remembering to enforce them.

For example:

- A balance must never go negative.
- An order cannot be shipped unless it is paid.
- An audit row must be created when sensitive data changes.
- A username must be normalized before insert.

Database-side logic can enforce those rules consistently, no matter which service, script, or admin tool touches the database.

### 3. Improve Performance for Data-Heavy Work

If a task touches thousands or millions of rows, moving that logic to the database can avoid pulling large volumes of data into application memory.

Instead of this pattern:

```text
App reads rows -> app loops -> app updates rows one by one
```

Prefer this:

```text
Database updates the right rows in one set-based operation
```

PL/pgSQL can coordinate that work while still letting SQL do the heavy lifting.

### 4. Build Triggers

Triggers are one of the most common reasons to write PL/pgSQL. A trigger function can run before or after inserts, updates, or deletes.

Common trigger use cases:

- Maintain `updated_at`
- Write audit records
- Validate complex data changes
- Prevent dangerous deletes
- Maintain summary tables

### 5. Create Safer Admin Operations

A well-written function can give operators a safe interface for sensitive database work.

Instead of giving someone broad write access, you can expose a controlled function:

```sql
SELECT deactivate_customer_account(1001, 'fraud review');
```

The function handles checks, logging, and side effects.

---

## When Not to Use PL/pgSQL

PL/pgSQL is powerful, but it is not free.

Avoid it when:

- The logic changes constantly and belongs in application code.
- The function is mostly formatting or UI behavior.
- The code needs external API calls.
- The logic is hard to test inside the database.
- The function hides business rules from the team.
- A simple SQL statement would do the job better.

A good rule: use PL/pgSQL when the database is the natural owner of the logic.

If the logic depends on user interface state, third-party services, or fast-changing product rules, keep it in the application layer.

---

# Part 1: Setting Up a PL/pgSQL Development Environment

A serious PL/pgSQL workflow starts with a repeatable database setup.

Do not develop stored procedures directly in a shared development database if you can avoid it. That creates drift, fear, and debugging noise.

Use a local database that you can destroy and rebuild.

## Option 1: Local PostgreSQL Install

You can install PostgreSQL directly on your machine.

This works well when:

- You want maximum speed.
- You prefer native services.
- You only work on one PostgreSQL version.
- You are comfortable managing local ports and data directories.

Basic check:

```bash
psql --version
```

Connect:

```bash
psql -U postgres -d postgres
```

Create a dev database:

```sql
CREATE DATABASE plpgsql_dev;
```

Connect to it:

```bash
psql -U postgres -d plpgsql_dev
```

This is fine for solo work. For teams, Docker Compose is usually easier to standardize.

---

## Option 2: Docker Compose Setup

Docker Compose gives you a clean, repeatable PostgreSQL environment. You can pin the PostgreSQL version, mount initialization scripts, expose a port, and reset the whole database when needed.

Create this structure:

```text
plpgsql-demo/
  docker-compose.yml
  db/
    init/
      001_schema.sql
      002_seed.sql
```

### docker-compose.yml

```yaml
services:
  postgres:
    image: postgres:18
    container_name: plpgsql-demo-db
    environment:
      POSTGRES_USER: app_user
      POSTGRES_PASSWORD: app_password
      POSTGRES_DB: app_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d

volumes:
  postgres_data:
```

Start it:

```bash
docker compose up -d
```

Connect:

```bash
psql postgresql://app_user:app_password@localhost:5432/app_db
```

Stop it:

```bash
docker compose down
```

Reset everything:

```bash
docker compose down -v
docker compose up -d
```

### Important Docker Init Behavior

Files in `/docker-entrypoint-initdb.d/` run only when the database is initialized for the first time. If the data volume already exists, those scripts will not rerun automatically.

That behavior is good for predictable startup, but it surprises people during development.

If your `001_schema.sql` changes and you expect it to rerun, you must remove the volume:

```bash
docker compose down -v
```

Then start again.

---

## Example Schema for PL/pgSQL Practice

Create `db/init/001_schema.sql`:

```sql
CREATE TABLE customers (
    customer_id bigserial PRIMARY KEY,
    email text NOT NULL UNIQUE,
    full_name text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (status IN ('active', 'inactive', 'blocked'))
);

CREATE TABLE products (
    product_id bigserial PRIMARY KEY,
    sku text NOT NULL UNIQUE,
    name text NOT NULL,
    price numeric(12,2) NOT NULL CHECK (price >= 0),
    stock_quantity integer NOT NULL CHECK (stock_quantity >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    order_id bigserial PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES customers(customer_id),
    status text NOT NULL DEFAULT 'pending',
    total_amount numeric(12,2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (status IN ('pending', 'paid', 'cancelled', 'shipped'))
);

CREATE TABLE order_items (
    order_item_id bigserial PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id bigint NOT NULL REFERENCES products(product_id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    line_total numeric(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE audit_log (
    audit_id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    operation text NOT NULL,
    row_id text NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    changed_by text NOT NULL DEFAULT current_user,
    old_data jsonb,
    new_data jsonb
);
```

Create `db/init/002_seed.sql`:

```sql
INSERT INTO customers (email, full_name)
VALUES
    ('ada@example.com', 'Ada Lovelace'),
    ('grace@example.com', 'Grace Hopper'),
    ('katherine@example.com', 'Katherine Johnson');

INSERT INTO products (sku, name, price, stock_quantity)
VALUES
    ('BOOK-001', 'PostgreSQL Field Guide', 39.99, 50),
    ('COURSE-001', 'Database Performance Course', 199.00, 10),
    ('SUPPORT-001', 'Priority Support Credit', 99.00, 25);
```

Now you have realistic tables for functions, triggers, and stored procedures.

---

# Part 2: Essential PL/pgSQL Tools

You can write PL/pgSQL with a plain text editor, but tooling changes the experience dramatically.

## 1. `psql`: The Command-Line Workhorse

`psql` is the native PostgreSQL command-line client. It is fast, scriptable, and ideal for repeatable workflows.

Connect:

```bash
psql postgresql://app_user:app_password@localhost:5432/app_db
```

Useful commands:

```sql
\dt              -- list tables
\df              -- list functions
\df+ function    -- show function details
\d table_name    -- describe table
\x               -- expanded output
\timing          -- show query timing
\i file.sql      -- run SQL file
\echo message    -- print message
```

Run a script:

```bash
psql postgresql://app_user:app_password@localhost:5432/app_db -f db/functions.sql
```

Stop on first error:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/functions.sql
```

That `ON_ERROR_STOP` flag matters. Without it, a script may continue after an error and leave your database in a half-applied state.

---

## 2. pgAdmin: Visual Management and Debugging

pgAdmin is a popular GUI for PostgreSQL. It gives you object browsing, query execution, explain plans, server management, and debugging support when the right server-side debugger extension is installed.

Use pgAdmin when you want to:

- Browse schemas visually
- Inspect functions
- Run ad hoc queries
- View table data quickly
- Use explain plans interactively
- Debug supported procedural code

It is especially helpful for people who prefer seeing database objects in a tree view instead of memorizing `psql` commands.

---

## 3. SQL Editors and IDEs

Good SQL editors help with completion, formatting, navigation, and result inspection.

Common choices include:

- DataGrip
- DBeaver
- VS Code with PostgreSQL extensions
- pgAdmin Query Tool
- TablePlus
- Beekeeper Studio

Pick one editor for comfort, but keep `psql` in your workflow for automation. GUI tools are great for exploration. Scripts are better for repeatability.

---

## 4. Migration Tools

PL/pgSQL functions should be version-controlled and deployed through migrations, not hand-edited in production.

Common migration tools:

- Flyway
- Liquibase
- Sqitch
- Alembic for Python projects
- Rails migrations
- Django migrations
- Prisma migrations, with care around raw SQL

A migration for a function might look like this:

```sql
-- V004__create_order_function.sql

CREATE OR REPLACE FUNCTION create_order(
    p_customer_id bigint,
    p_product_id bigint,
    p_quantity integer
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id bigint;
    v_unit_price numeric(12,2);
    v_available_stock integer;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT price, stock_quantity
    INTO v_unit_price, v_available_stock
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id;
    END IF;

    IF v_available_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product %. Available: %, requested: %',
            p_product_id, v_available_stock, p_quantity;
    END IF;

    INSERT INTO orders (customer_id, total_amount)
    VALUES (p_customer_id, v_unit_price * p_quantity)
    RETURNING order_id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$;
```

This is deployable, reviewable, and testable.

---

## 5. `plpgsql_check`: Static and Runtime Checks

The `plpgsql_check` extension can catch problems in PL/pgSQL functions that PostgreSQL may not reveal until runtime.

It can help detect issues such as:

- Wrong variable usage
- Suspicious SQL
- Missing relations
- Type problems
- Dead code patterns
- Runtime warnings

Example usage can vary by installation, but the workflow is usually:

```sql
CREATE EXTENSION IF NOT EXISTS plpgsql_check;

SELECT *
FROM plpgsql_check_function('create_order(bigint,bigint,integer)');
```

This kind of check is valuable in CI because database functions often fail only when a specific path runs.

---

# Part 3: PL/pgSQL Basics with Practical Examples

## Function Structure

A PL/pgSQL function usually has this shape:

```sql
CREATE OR REPLACE FUNCTION function_name(parameter_name data_type)
RETURNS return_type
LANGUAGE plpgsql
AS $$
DECLARE
    -- variables go here
BEGIN
    -- logic goes here
    RETURN something;
END;
$$;
```

Example:

```sql
CREATE OR REPLACE FUNCTION get_customer_status(p_customer_id bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_status text;
BEGIN
    SELECT status
    INTO v_status
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id;
    END IF;

    RETURN v_status;
END;
$$;
```

Call it:

```sql
SELECT get_customer_status(1);
```

---

## Variables

Declare variables inside the `DECLARE` section:

```sql
CREATE OR REPLACE FUNCTION calculate_discounted_price(
    p_price numeric,
    p_discount_percent numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_discount_amount numeric;
    v_final_price numeric;
BEGIN
    v_discount_amount := p_price * (p_discount_percent / 100);
    v_final_price := p_price - v_discount_amount;

    RETURN round(v_final_price, 2);
END;
$$;
```

Call it:

```sql
SELECT calculate_discounted_price(100, 15);
```

Result:

```text
85.00
```

---

## Conditional Logic

```sql
CREATE OR REPLACE FUNCTION classify_customer(p_customer_id bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_count integer;
BEGIN
    SELECT count(*)
    INTO v_order_count
    FROM orders
    WHERE customer_id = p_customer_id;

    IF v_order_count = 0 THEN
        RETURN 'new';
    ELSIF v_order_count < 5 THEN
        RETURN 'active';
    ELSE
        RETURN 'loyal';
    END IF;
END;
$$;
```

This works, but be careful: many classification problems can be solved with plain SQL. Use PL/pgSQL when procedural flow improves clarity or safety.

---

## Loops

Loops are available, but they should not be your first instinct. PostgreSQL is strongest when you use set-based SQL.

Still, loops are useful for procedural tasks.

```sql
CREATE OR REPLACE FUNCTION count_down(p_start integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    i integer;
BEGIN
    FOR i IN REVERSE p_start..1 LOOP
        RAISE NOTICE 'Count: %', i;
    END LOOP;
END;
$$;
```

Call it:

```sql
SELECT count_down(5);
```

Output:

```text
NOTICE: Count: 5
NOTICE: Count: 4
NOTICE: Count: 3
NOTICE: Count: 2
NOTICE: Count: 1
```

### The Performance Warning

Avoid row-by-row loops when a single SQL statement can do the job.

Slow pattern:

```sql
FOR r IN SELECT product_id FROM products LOOP
    UPDATE products
    SET updated_at = now()
    WHERE product_id = r.product_id;
END LOOP;
```

Better:

```sql
UPDATE products
SET updated_at = now();
```

In database work, “simple and set-based” usually beats “clever and procedural.”

---

## Returning Tables

PL/pgSQL can return a table-shaped result.

```sql
CREATE OR REPLACE FUNCTION list_low_stock_products(p_threshold integer)
RETURNS TABLE (
    product_id bigint,
    sku text,
    name text,
    stock_quantity integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT p.product_id, p.sku, p.name, p.stock_quantity
    FROM products p
    WHERE p.stock_quantity <= p_threshold
    ORDER BY p.stock_quantity ASC;
END;
$$;
```

Call it:

```sql
SELECT * FROM list_low_stock_products(20);
```

This is useful when you want a stable database API for application code or reports.

---

# Part 4: Stored Procedures vs Functions

PostgreSQL supports both functions and procedures.

A function returns a value and is called with `SELECT`:

```sql
SELECT create_order(1, 2, 3);
```

A procedure is called with `CALL`:

```sql
CALL refresh_reporting_tables();
```

Functions are typically used when you need a return value or want to use the routine inside SQL expressions.

Procedures are better for command-style operations, especially when transaction control is relevant.

Example procedure:

```sql
CREATE OR REPLACE PROCEDURE deactivate_inactive_customers()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE customers
    SET status = 'inactive',
        updated_at = now()
    WHERE customer_id NOT IN (
        SELECT DISTINCT customer_id
        FROM orders
        WHERE created_at >= now() - interval '1 year'
    )
    AND status = 'active';
END;
$$;
```

Call it:

```sql
CALL deactivate_inactive_customers();
```

---

# Part 5: Triggers Without the Headache

Triggers are powerful because they run automatically. That is also what makes them dangerous.

A trigger should be boring, obvious, and documented.

## Example: Automatically Maintain `updated_at`

Create one reusable trigger function:

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

Attach it to tables:

```sql
CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

Test it:

```sql
UPDATE customers
SET full_name = 'Ada King'
WHERE customer_id = 1;

SELECT customer_id, full_name, updated_at
FROM customers
WHERE customer_id = 1;
```

This is a good trigger: small, predictable, and reusable.

---

## Example: Audit Log Trigger

Audit triggers are a common PL/pgSQL use case.

```sql
CREATE OR REPLACE FUNCTION audit_row_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_row_id text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_row_id := COALESCE(NEW.customer_id::text, NEW.product_id::text, NEW.order_id::text);

        INSERT INTO audit_log (table_name, operation, row_id, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, v_row_id, to_jsonb(NEW));

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        v_row_id := COALESCE(NEW.customer_id::text, NEW.product_id::text, NEW.order_id::text);

        INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, v_row_id, to_jsonb(OLD), to_jsonb(NEW));

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        v_row_id := COALESCE(OLD.customer_id::text, OLD.product_id::text, OLD.order_id::text);

        INSERT INTO audit_log (table_name, operation, row_id, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, v_row_id, to_jsonb(OLD));

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;
```

Attach to `customers`:

```sql
CREATE TRIGGER trg_customers_audit
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION audit_row_changes();
```

Test:

```sql
UPDATE customers
SET status = 'blocked'
WHERE customer_id = 2;

SELECT *
FROM audit_log
ORDER BY audit_id DESC
LIMIT 5;
```

### Warning

Audit triggers look simple until they are not.

Be careful with:

- High-write tables
- Sensitive data in JSON snapshots
- Large row payloads
- Recursive side effects
- Compliance retention rules
- Who can read the audit table

A bad audit trigger can become a performance tax on every write.

---

# Part 6: Error Handling and Exceptions

PL/pgSQL lets you raise errors and catch exceptions.

## Raising Exceptions

```sql
CREATE OR REPLACE FUNCTION require_active_customer(p_customer_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_status text;
BEGIN
    SELECT status
    INTO v_status
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % does not exist', p_customer_id;
    END IF;

    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Customer % is not active. Current status: %', p_customer_id, v_status;
    END IF;
END;
$$;
```

Use clear error messages. Future you will thank current you.

---

## Handling Exceptions

```sql
CREATE OR REPLACE FUNCTION safe_create_customer(
    p_email text,
    p_full_name text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id bigint;
BEGIN
    INSERT INTO customers (email, full_name)
    VALUES (lower(trim(p_email)), trim(p_full_name))
    RETURNING customer_id INTO v_customer_id;

    RETURN v_customer_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Customer with email % already exists', p_email;
END;
$$;
```

This improves the caller experience while preserving database integrity.

### Do Not Swallow Errors

Avoid this:

```sql
EXCEPTION
    WHEN others THEN
        RETURN NULL;
```

That turns real failures into silent corruption.

If you catch an exception, either handle it meaningfully or re-raise it.

---

# Part 7: Debugging PL/pgSQL

Debugging database code is different from debugging application code. You need a mix of logging, notices, explain plans, test data, and sometimes debugger support.

## Start with `RAISE NOTICE`

```sql
CREATE OR REPLACE FUNCTION debug_order_total(p_order_id bigint)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric(12,2);
BEGIN
    RAISE NOTICE 'Calculating total for order_id=%', p_order_id;

    SELECT COALESCE(sum(line_total), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;

    RAISE NOTICE 'Calculated total=%', v_total;

    RETURN v_total;
END;
$$;
```

Run:

```sql
SELECT debug_order_total(1);
```

Notices are useful while developing. Remove noisy notices before production, or use appropriate log levels.

---

## Use `ASSERT` for Internal Assumptions

```sql
CREATE OR REPLACE FUNCTION calculate_line_total(
    p_quantity integer,
    p_unit_price numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
BEGIN
    ASSERT p_quantity > 0, 'Quantity must be positive';
    ASSERT p_unit_price >= 0, 'Unit price cannot be negative';

    RETURN p_quantity * p_unit_price;
END;
$$;
```

Assertions are best for developer assumptions, not user-facing validation.

---

## Use `EXPLAIN` for SQL Inside Functions

If a PL/pgSQL function is slow, the slow part is often one SQL statement inside it.

Extract that SQL and run:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT price, stock_quantity
FROM products
WHERE product_id = 2
FOR UPDATE;
```

Look for:

- Sequential scans on large tables
- Missing indexes
- Bad row estimates
- Repeated queries in loops
- Lock waits
- Expensive sorts

Do not treat PL/pgSQL as a black box. Profile the SQL inside it.

---

## Debugger Support

pgAdmin can work with debugger support when the required server-side debugging extension is available and configured. This is useful for stepping through functions, inspecting variables, and understanding control flow.

That said, many teams still rely mostly on:

- Small test fixtures
- `RAISE NOTICE`
- `EXPLAIN ANALYZE`
- Logging
- CI checks
- Code review

A debugger is helpful. A clean design is better.

---

# Part 8: Testing PL/pgSQL

Stored logic deserves tests.

If you do not test database functions, you are trusting your most permanent system layer to hope.

## Simple SQL-Based Test

```sql
BEGIN;

SELECT create_order(1, 1, 2) AS new_order_id;

SELECT stock_quantity
FROM products
WHERE product_id = 1;

ROLLBACK;
```

The transaction lets you test without leaving data behind.

---

## Assertion-Style Tests with `DO` Blocks

```sql
DO $$
DECLARE
    v_result numeric;
BEGIN
    v_result := calculate_discounted_price(100, 15);

    IF v_result <> 85.00 THEN
        RAISE EXCEPTION 'Expected 85.00, got %', v_result;
    END IF;
END;
$$;
```

This is simple and works anywhere.

---

## Test Error Cases

Do not only test happy paths.

```sql
DO $$
BEGIN
    PERFORM create_order(1, 1, -5);
    RAISE EXCEPTION 'Expected function to reject negative quantity';
EXCEPTION
    WHEN others THEN
        IF SQLERRM NOT LIKE '%Quantity must be greater than zero%' THEN
            RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
        END IF;
END;
$$;
```

The best database tests prove that bad data cannot sneak through.

---

## Use a Dedicated Database Test Framework

For larger systems, consider a database testing framework such as pgTAP.

A test might read conceptually like:

```sql
SELECT plan(2);

SELECT is(
    calculate_discounted_price(100, 15),
    85.00,
    '15 percent discount on 100 should be 85.00'
);

SELECT throws_ok(
    $$ SELECT create_order(1, 1, -1); $$,
    NULL,
    'Negative quantity should fail'
);

SELECT * FROM finish();
```

The more database logic you own, the more value you get from proper database tests.

---

# Part 9: Security and Permissions

Security is one of the most important parts of PL/pgSQL development.

Functions can run with either the caller’s permissions or the function owner’s permissions.

## `SECURITY INVOKER`

This is the default. The function runs with the permissions of the user calling it.

```sql
CREATE OR REPLACE FUNCTION get_my_orders()
RETURNS SETOF orders
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM orders;
END;
$$;
```

The caller still needs permission to read `orders`.

---

## `SECURITY DEFINER`

This runs with the permissions of the function owner.

That can be useful, but it is dangerous if handled carelessly.

```sql
CREATE OR REPLACE FUNCTION admin_cancel_order(p_order_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE orders
    SET status = 'cancelled',
        updated_at = now()
    WHERE order_id = p_order_id
      AND status IN ('pending', 'paid');
END;
$$;
```

### Security Definer Checklist

Use this checklist before deploying `SECURITY DEFINER` functions:

- Set a safe `search_path`.
- Keep the function narrow.
- Validate all inputs.
- Avoid dynamic SQL unless necessary.
- Fully qualify objects when practical.
- Own the function with a controlled role.
- Grant execute only to the right roles.
- Review it like privileged application code.

Grant execution:

```sql
REVOKE ALL ON FUNCTION admin_cancel_order(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_cancel_order(bigint) TO support_role;
```

Do not casually ship privileged functions.

---

# Part 10: Dynamic SQL

Dynamic SQL lets you build SQL strings and execute them at runtime.

Use it when object names, filters, or commands must be dynamic.

## Safe Dynamic SQL Example

```sql
CREATE OR REPLACE FUNCTION count_rows_in_table(p_table_name text)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_count bigint;
BEGIN
    EXECUTE format('SELECT count(*) FROM %I', p_table_name)
    INTO v_count;

    RETURN v_count;
END;
$$;
```

Call:

```sql
SELECT count_rows_in_table('customers');
```

The `%I` placeholder safely quotes identifiers.

## Dynamic SQL with Values

Use `USING` for values:

```sql
CREATE OR REPLACE FUNCTION find_customer_by_column(
    p_column_name text,
    p_value text
)
RETURNS SETOF customers
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT * FROM customers WHERE %I = $1',
        p_column_name
    )
    USING p_value;
END;
$$;
```

This separates the identifier from the value and reduces injection risk.

### Bad Dynamic SQL

Avoid string concatenation with user input:

```sql
EXECUTE 'SELECT * FROM customers WHERE email = ''' || p_email || '''';
```

That is fragile and unsafe.

Prefer:

```sql
EXECUTE 'SELECT * FROM customers WHERE email = $1'
USING p_email;
```

---

# Part 11: Performance Rules for PL/pgSQL

The fastest PL/pgSQL code is often the code that lets SQL do the work.

## Rule 1: Prefer Set-Based SQL

Bad:

```sql
FOR r IN SELECT order_id FROM orders WHERE status = 'pending' LOOP
    UPDATE orders
    SET status = 'cancelled'
    WHERE order_id = r.order_id;
END LOOP;
```

Good:

```sql
UPDATE orders
SET status = 'cancelled',
    updated_at = now()
WHERE status = 'pending';
```

---

## Rule 2: Watch Queries Inside Loops

This pattern can become expensive fast:

```sql
FOR r IN SELECT customer_id FROM customers LOOP
    SELECT count(*)
    INTO v_count
    FROM orders
    WHERE customer_id = r.customer_id;
END LOOP;
```

Better:

```sql
SELECT customer_id, count(*)
FROM orders
GROUP BY customer_id;
```

Row-by-row database code is often application slowness wearing a database costume.

---

## Rule 3: Lock Deliberately

The `create_order` function used `FOR UPDATE` when reading the product row.

```sql
SELECT price, stock_quantity
INTO v_unit_price, v_available_stock
FROM products
WHERE product_id = p_product_id
FOR UPDATE;
```

That lock protects inventory from concurrent overselling.

Without it, two transactions might both see stock available and both subtract from it.

Locks are not bad. Accidental locks are bad.

---

## Rule 4: Index for the SQL You Actually Run

If functions query by `customer_id`, `status`, or `created_at`, make sure the indexes match the workload.

Example:

```sql
CREATE INDEX idx_orders_customer_id
ON orders(customer_id);

CREATE INDEX idx_orders_status_created_at
ON orders(status, created_at);
```

Then confirm with:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE status = 'pending'
ORDER BY created_at
LIMIT 50;
```

Never guess about performance when PostgreSQL can show you the plan.

---

# Part 12: A Practical Project Layout

A clean repository layout makes PL/pgSQL easier to review and deploy.

Example:

```text
project/
  docker-compose.yml
  db/
    migrations/
      V001__schema.sql
      V002__seed_data.sql
      V003__updated_at_trigger.sql
      V004__create_order_function.sql
      V005__audit_trigger.sql
    tests/
      test_calculate_discount.sql
      test_create_order.sql
      test_triggers.sql
    scripts/
      reset-db.sh
      run-tests.sh
  README.md
```

### reset-db.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

docker compose down -v
docker compose up -d
sleep 3
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/V001__schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/V002__seed_data.sql
```

### run-tests.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

for file in db/tests/*.sql; do
  echo "Running $file"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done
```

This is not fancy. That is the point.

Repeatability beats cleverness.

---

# Part 13: Deployment Practices

PL/pgSQL deployment should be boring.

That means:

- Use migrations.
- Review SQL changes.
- Run tests before deployment.
- Avoid direct production edits.
- Keep rollback plans realistic.
- Monitor after release.

## Use `CREATE OR REPLACE`, But Know Its Limits

`CREATE OR REPLACE FUNCTION` is convenient, but it cannot change everything. For example, changing return types may require dropping and recreating the function.

This can affect dependencies.

Safer pattern for breaking changes:

1. Create a new function version.
2. Move callers to the new function.
3. Remove the old function later.

Example:

```sql
CREATE OR REPLACE FUNCTION create_order_v2(
    p_customer_id bigint,
    p_product_id bigint,
    p_quantity integer,
    p_source text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
BEGIN
    -- new implementation
    RETURN create_order(p_customer_id, p_product_id, p_quantity);
END;
$$;
```

Function versioning may feel ugly, but it can make production changes safer.

---

## Transactional Migrations

Many PostgreSQL DDL changes can run inside transactions.

Example:

```sql
BEGIN;

CREATE OR REPLACE FUNCTION calculate_discounted_price(
    p_price numeric,
    p_discount_percent numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN round(p_price - (p_price * p_discount_percent / 100), 2);
END;
$$;

COMMIT;
```

If something fails, the change rolls back.

Some operations require special care, such as certain index operations, large table rewrites, or long-running migrations.

---

## Production Safety Checklist

Before deploying PL/pgSQL changes, ask:

- Does this function run on a hot path?
- Does it introduce locks?
- Does it loop over large tables?
- Does it change permissions?
- Does it use dynamic SQL?
- Does it touch trigger behavior?
- Does it have tests?
- Is rollback possible?
- Do we know how to observe failure?

This checklist catches more incidents than optimism does.

---

# Part 14: Order Creation

Let’s bring the pieces together.

## Goal

Create a safe order function that:

- Validates customer status
- Validates product existence
- Locks product inventory
- Rejects invalid quantity
- Prevents overselling
- Creates order and order item
- Updates stock
- Returns the order ID

## Function

```sql
CREATE OR REPLACE FUNCTION create_order(
    p_customer_id bigint,
    p_product_id bigint,
    p_quantity integer
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id bigint;
    v_customer_status text;
    v_unit_price numeric(12,2);
    v_available_stock integer;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT status
    INTO v_customer_status
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id;
    END IF;

    IF v_customer_status <> 'active' THEN
        RAISE EXCEPTION 'Customer % is not active', p_customer_id;
    END IF;

    SELECT price, stock_quantity
    INTO v_unit_price, v_available_stock
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id;
    END IF;

    IF v_available_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Product: %, available: %, requested: %',
            p_product_id, v_available_stock, p_quantity;
    END IF;

    INSERT INTO orders (customer_id, status, total_amount)
    VALUES (p_customer_id, 'pending', v_unit_price * p_quantity)
    RETURNING order_id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$;
```

## Test It

```sql
SELECT create_order(1, 1, 2);
```

Check the order:

```sql
SELECT *
FROM orders
ORDER BY order_id DESC
LIMIT 1;
```

Check the item:

```sql
SELECT *
FROM order_items
ORDER BY order_item_id DESC
LIMIT 1;
```

Check stock:

```sql
SELECT product_id, sku, stock_quantity
FROM products
WHERE product_id = 1;
```

## Failure Tests

```sql
SELECT create_order(1, 1, 0);
```

Expected:

```text
ERROR: Quantity must be greater than zero
```

```sql
SELECT create_order(999, 1, 1);
```

Expected:

```text
ERROR: Customer 999 not found
```

```sql
SELECT create_order(1, 999, 1);
```

Expected:

```text
ERROR: Product 999 not found
```

This is the kind of database function that earns its place. It protects a real business operation and keeps the data consistent.

---

# Part 15: Best Practices

## Keep Functions Small

A 30-line function is easy to review. A 400-line function is a private framework hiding in the database.

Split large routines into smaller functions when it improves clarity.

## Name Parameters Clearly

Use a prefix like `p_` for parameters and `v_` for variables.

Example:

```sql
p_customer_id
v_customer_status
```

This avoids confusion between column names and variable names.

## Avoid Hidden Side Effects

A function named `get_customer_status` should not update customer records.

Names should tell the truth.

## Document Dangerous Functions

If a function locks rows, changes permissions, uses dynamic SQL, or drives triggers, add comments.

```sql
COMMENT ON FUNCTION create_order(bigint,bigint,integer)
IS 'Creates a pending order, locks product inventory, reduces stock, and returns the new order ID.';
```

## Keep Business Logic Visible

If critical rules live in PL/pgSQL, make sure application developers know where they are.

Database logic should be part of the codebase, not tribal knowledge.

---

# Common PL/pgSQL Mistakes

## Mistake 1: Writing Procedural Code Instead of SQL

Bad PL/pgSQL often looks like application code translated line by line into database syntax.

Better PL/pgSQL uses procedural control only where needed and lets SQL handle sets.

## Mistake 2: No Tests

A stored procedure without tests is a production surprise waiting for a calendar invite.

## Mistake 3: Uncontrolled Triggers

Triggers can become invisible behavior. Keep them small and documented.

## Mistake 4: Unsafe Dynamic SQL

Use `format()`, `%I`, `%L`, and `USING`. Do not concatenate raw user input into SQL strings.

## Mistake 5: Ignoring Permissions

Function security matters. Especially with `SECURITY DEFINER`.

## Mistake 6: Debugging Only in Production

Build local fixtures. Reproduce issues. Run scripts. Use transactions. Do not discover function behavior for the first time during an incident.

---

# Finally

PL/pgSQL is not just a stored procedure language. It is a way to make PostgreSQL enforce rules, coordinate data workflows, and protect the integrity of systems where the database is the source of truth.

But the language is only half the story.

The real advantage comes from the development system around it:

- A disposable local PostgreSQL setup
- Version-controlled migrations
- Repeatable scripts
- A good SQL editor
- `psql` fluency
- Debugging habits
- Tests for happy paths and failure paths
- Careful deployment practices

Treat PL/pgSQL like production code because it is production code.

The best database logic is boring in the best possible way: clear, tested, observable, and safe to change.

That is how you move logic closer to the data without moving risk closer to production.

---

## PL/pgSQL Checklist

### Setup

- Use a local or containerized PostgreSQL database.
- Keep schema and function files in version control.
- Make resets easy.
- Seed useful test data.

### Development

- Use `psql` for repeatable scripts.
- Use a GUI for exploration if helpful.
- Keep functions small.
- Prefer set-based SQL.
- Avoid hidden side effects.

### Debugging

- Use `RAISE NOTICE` during development.
- Extract and profile slow SQL with `EXPLAIN`.
- Check locks and indexes.
- Use debugger tooling where available.

### Testing

- Test happy paths.
- Test failure paths.
- Wrap manual tests in transactions.
- Add CI checks when possible.

### Security

- Be careful with `SECURITY DEFINER`.
- Set safe `search_path` values.
- Grant execute permissions intentionally.
- Avoid unsafe dynamic SQL.

### Deployment

- Use migration tools.
- Review function changes.
- Plan rollback.
- Monitor after release.

---



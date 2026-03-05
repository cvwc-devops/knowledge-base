WITH base AS MATERIALIZED (
  SELECT o.user_id, o.total, o.created_at
  FROM orders o
  WHERE o.user_id = $1
    AND o.created_at >= now() - interval '30 days'
),
sum30 AS (
  SELECT user_id, sum(total) AS amt
  FROM base
  GROUP BY user_id
),
last3 AS (
  SELECT user_id, count(*) AS cnt
  FROM base
  WHERE created_at >= now() - interval '3 days'
  GROUP BY user_id
)
SELECT s.amt, l.cnt
FROM sum30 s
LEFT JOIN last3 l USING (user_id);

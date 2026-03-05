create table evt (
  id uuid primary key default uuidv7(),
  doc jsonb not null,
  kind text generated always as (doc->>'type') virtual,
  ts  timestamptz generated always as ((doc->>'ts')::timestamptz) virtual
);

create index on evt (kind, ts);
create index evt_doc_gin on evt using gin (doc);
select id, doc->>'userId' as u
from evt
where kind = 'payment'
  and ts >= now() - interval '7 days'
  and doc @> '{"status":"ok"}';

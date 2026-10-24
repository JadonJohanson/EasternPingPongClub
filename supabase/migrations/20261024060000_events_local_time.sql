-- Simpler event times: store the time exactly as the club would write it on a
-- flyer ("2026-11-04 19:00:00"), with no time zone and no fractions of a second.
--
-- Why this is fine here: the club meets in ONE place (Connecticut), so every
-- event time means "New York wall-clock time". Storing it that way means the
-- dashboard shows what you typed, and nobody has to think about UTC.
-- (System-recorded moments such as created_at stay as full timestamps.)
--
-- Existing rows are converted: a stored UTC moment becomes its New York
-- wall-clock time.
alter table public.events
  alter column starts_at type timestamp(0) without time zone
    using (starts_at at time zone 'America/New_York'),
  alter column ends_at type timestamp(0) without time zone
    using (ends_at at time zone 'America/New_York');

comment on column public.events.starts_at is
  'Start time as New York wall-clock time (no time zone stored).';
comment on column public.events.ends_at is
  'Optional end time as New York wall-clock time (no time zone stored).';

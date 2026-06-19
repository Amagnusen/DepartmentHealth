-- ============================================================================
-- Operators leaderboard: per-tech top step + count, uncapped list.
-- Applied to SK Public Supabase (asdunkqodixbhbohxtuq) on 2026-06-19.
--
-- Why:
--   The DepartmentHealth board's "Operators" card (formerly "Today's Top
--   Operators") showed only each tech's name and total. The team wanted, under
--   each operator, the single step they completed most today plus how many
--   units/pans/cases that step accounts for (e.g. "Final QC - Printed Denture - 45"),
--   and to be able to scroll the full list of operators rather than a top-10 cap.
--
-- This migration replaces public.station_health_get so the `techs` payload also
-- returns, per operator:
--   * top_step    — the Step within the station's mapped steps the tech completed
--                   most today (ties broken alphabetically).
--   * top_step_n  — the count for that step, using the station's count_method
--                   (distinct_pan = pans, distinct_case = cases, sum = units).
-- The per-tech total `n` is computed exactly as before, and the `limit 10` cap is
-- removed so every operator on the selected steps is returned (the board scrolls).
-- All other fields returned by the function are unchanged.
--
-- Applies to every business unit (AOX / CB / REM_AD / REM_PD) since the function
-- is shared and reads each BU's steps from public.station_step_map.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.station_health_get(p_business_unit text, p_station text, p_tz text DEFAULT 'America/Los_Angeles'::text)
 RETURNS json
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  m record;
  result_target numeric;
  hourly_data json;
  hourly_15min json;
  log_data json;
  wip_count int;
  wip_hold_count int;
  hot_list_data json;
  techs_data json;
  miss_log_data json;
  day_local date;
  day_start timestamptz;
  day_end timestamptz;
begin
  select * into m from public.station_step_map
   where business_unit = p_business_unit and station = p_station;
  if not found then raise exception 'No mapping for % / %', p_business_unit, p_station; end if;

  day_local := (now() at time zone p_tz)::date;
  day_start := (day_local::timestamp at time zone 'UTC');
  day_end   := ((day_local + 1)::timestamp at time zone 'UTC');

  result_target := public.dpm_resolve_target(p_business_unit, p_station);

  if m.count_method = 'distinct_pan' then
    select coalesce(json_agg(row_to_json(h) order by hr), '[]'::json) into hourly_data from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr, count(distinct "Pan Number")::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1) h;
    select coalesce(json_agg(row_to_json(q) order by hr, mn), '[]'::json) into hourly_15min from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr,
             (floor(extract(minute from "Finish Date" at time zone 'UTC') / 15) * 15)::int as mn,
             count(distinct "Pan Number")::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1, 2) q;
  elsif m.count_method = 'distinct_case' then
    select coalesce(json_agg(row_to_json(h) order by hr), '[]'::json) into hourly_data from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr, count(distinct "Case Number")::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1) h;
    select coalesce(json_agg(row_to_json(q) order by hr, mn), '[]'::json) into hourly_15min from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr,
             (floor(extract(minute from "Finish Date" at time zone 'UTC') / 15) * 15)::int as mn,
             count(distinct "Case Number")::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1, 2) q;
  else
    select coalesce(json_agg(row_to_json(h) order by hr), '[]'::json) into hourly_data from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr, count(*)::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1) h;
    select coalesce(json_agg(row_to_json(q) order by hr, mn), '[]'::json) into hourly_15min from (
      select extract(hour from "Finish Date" at time zone 'UTC')::int as hr,
             (floor(extract(minute from "Finish Date" at time zone 'UTC') / 15) * 15)::int as mn,
             count(*)::int as n
        from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C' and "Finish Date" >= day_start and "Finish Date" < day_end
       group by 1, 2) q;
  end if;

  -- WIP active: not shipped, not on hold
  select count(*)::int into wip_count
    from public."Cases" c
   where c."Current Step" = any(m.steps)
     and (c."Case Status" is null or c."Case Status" not in ('Shipped','Hold'))
     and (c."Hold Flag" is null or c."Hold Flag" = 0);

  -- WIP hold: parked here but on hold
  select count(*)::int into wip_hold_count
    from public."Cases" c
   where c."Current Step" = any(m.steps)
     and (c."Case Status" = 'Hold' or c."Hold Flag" = 1)
     and (c."Case Status" is null or c."Case Status" <> 'Shipped');

  select row_to_json(l) into log_data from (
    select near_misses, ideas from public.station_health_log
     where station = p_station and business_unit = p_business_unit and entry_date = day_local
     limit 1) l;

  select coalesce(json_agg(row_to_json(h) order by created_at desc), '[]'::json) into hot_list_data from (
    select hl.case_number, hl.reason, hl.note, hl.status, hl.created_at,
           hl.added_by, hl.accepted_by, hl.accepted_at,
           c."Current Step", c."Current Step Consolidated",
           c."Doctor Due Date", c."Required Out Of Lab Date",
           c."Patient First Name", c."Patient Last Name",
           c."Account Number", c."Primary Product",
           c."Hold Flag", c."Hold Reason", c."Hold Days",
           c."Ship Date", c."Tracking Number", c."Carrier",
           c."Hubspot Ticket ID", c."Case Status"
      from public.hot_list_cases hl
      join public."Cases" c on c."Case Number" = hl.case_number
     where hl.status in ('pending','accepted') and c."Current Step" = any(m.steps)
     order by hl.created_at desc limit 20) h;

  -- Operators leaderboard: per-tech total (n, computed exactly as before) plus the
  -- single Step within this station the tech completed most today (top_step) and how
  -- many units/pans/cases that step accounts for (top_step_n). No row cap -- the board
  -- scrolls the full list of operators on the selected steps.
  if m.count_method = 'distinct_case' then
    select coalesce(json_agg(row_to_json(t) order by t.n desc), '[]'::json) into techs_data from (
      with tot as (
        select "Tech Name" as tech_name, count(distinct "Case Number")::int as n
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1),
      per_step as (
        select "Tech Name" as tech_name, "Step" as step, count(distinct "Case Number")::int as sn
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1, 2),
      best as (
        select distinct on (tech_name) tech_name, step, sn
          from per_step order by tech_name, sn desc, step)
      select tot.tech_name, tot.n, best.step as top_step, best.sn as top_step_n
        from tot left join best using (tech_name)
       order by tot.n desc) t;
  elsif m.count_method = 'sum' then
    select coalesce(json_agg(row_to_json(t) order by t.n desc), '[]'::json) into techs_data from (
      with tot as (
        select "Tech Name" as tech_name, count(*)::int as n
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1),
      per_step as (
        select "Tech Name" as tech_name, "Step" as step, count(*)::int as sn
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1, 2),
      best as (
        select distinct on (tech_name) tech_name, step, sn
          from per_step order by tech_name, sn desc, step)
      select tot.tech_name, tot.n, best.step as top_step, best.sn as top_step_n
        from tot left join best using (tech_name)
       order by tot.n desc) t;
  else
    select coalesce(json_agg(row_to_json(t) order by t.n desc), '[]'::json) into techs_data from (
      with tot as (
        select "Tech Name" as tech_name, count(distinct "Pan Number")::int as n
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1),
      per_step as (
        select "Tech Name" as tech_name, "Step" as step, count(distinct "Pan Number")::int as sn
          from public."Case Steps" where "Step" = any(m.steps) and "Status" = 'C'
           and "Finish Date" >= day_start and "Finish Date" < day_end and "Tech Name" is not null
         group by 1, 2),
      best as (
        select distinct on (tech_name) tech_name, step, sn
          from per_step order by tech_name, sn desc, step)
      select tot.tech_name, tot.n, best.step as top_step, best.sn as top_step_n
        from tot left join best using (tech_name)
       order by tot.n desc) t;
  end if;

  select coalesce(json_agg(row_to_json(ml) order by hour, created_at), '[]'::json) into miss_log_data from (
    select id, hour, reason, miss_count, notes, logged_by, created_at
      from public.miss_log
     where business_unit = p_business_unit and station = p_station and entry_date = day_local) ml;

  return json_build_object(
    'station', p_station, 'business_unit', p_business_unit,
    'target', coalesce(result_target, 0),
    'hourly', hourly_data, 'hourly_15min', hourly_15min,
    'log', log_data,
    'wip', wip_count,
    'wip_hold', wip_hold_count,
    'hot_list', hot_list_data, 'techs', techs_data,
    'miss_log', miss_log_data,
    'count_method', m.count_method, 'now_iso', now()
  );
end;
$function$;

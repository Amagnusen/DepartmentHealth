-- ============================================================================
-- AOX (Full Arch) — rebuild board stations to match the 16 AOX_Team operations
-- and route the board target to the AOX_Team Targets screen.
-- Applied to SK Public Supabase (asdunkqodixbhbohxtuq) on 2026-06-10.
--
-- Why:
--   The DepartmentHealth board (BU=AOX) had 9 coarse stations whose names and
--   granularity did not match the 16 Full Arch operations in the AOX_Team site
--   (only Design QC / Final QC matched). And the board read its target from
--   public.targets, which never received the values typed on the AOX_Team
--   Targets screen (those go to public.operation_targets). See
--   DepartmentHealth_Targets_Notes.docx (2026-06-09) for the full investigation.
--
-- This migration:
--   1. Adds 'AOX' -> 'full-arch' to dpm_resolve_target's slug crosswalk, so the
--      board resolves its target from operation_targets (operation = station
--      name) exactly like CB / REM_PD / REM_AD already do. Editing a target on
--      the AOX_Team site now drives the board directly.
--   2. Replaces the 9 AOX station_step_map rows with the 16 AOX_Team operations,
--      naming each station EXACTLY as its operation_targets `operation` so the
--      crosswalk matches. count_method sets each row's basis
--      (distinct_case=cases/day, distinct_pan=pans/day, sum=units/day).
--
-- Open items (count 0 actuals until the team supplies production steps):
--   * Design Changes    — no matching "Step" in public."Case Steps".
--   * Case Coordination  — no matching "Step" in public."Case Steps".
--   * Design Outsource   — best-guess mapping to the core design steps; confirm.
-- ============================================================================

begin;

-- 1) Crosswalk AOX -> 'full-arch'
create or replace function public.dpm_resolve_target(p_business_unit text, p_station text)
 returns numeric
 language plpgsql
 stable
as $function$
declare
  m record;
  v_slug text;
  v_target numeric;
begin
  select * into m from public.station_step_map
   where business_unit = p_business_unit and station = p_station;
  if not found then return null; end if;

  v_slug := case p_business_unit
              when 'AOX'    then 'full-arch'
              when 'CB'     then 'crown-bridge'
              when 'REM_PD' then 'digital-product'
              when 'REM_AD' then 'analog-dentures'
              else null
            end;

  if v_slug is not null then
    select target_value into v_target
      from public.operation_targets
     where business_unit = v_slug and operation = p_station
     limit 1;
  end if;

  if v_target is null then
    select target_value into v_target
      from public.targets
     where board = m.target_board and dept_name = m.target_dept_name
       and metric = m.target_metric
       and (business_unit is null or business_unit = p_business_unit)
     limit 1;
  end if;

  return v_target;
end;
$function$;

-- 2) Replace the 9 AOX stations with the 16 'full-arch' operations.
delete from public.station_step_map where business_unit = 'AOX';

insert into public.station_step_map
  (business_unit, station, steps, count_method, target_board, target_dept_name, display_order, target_metric)
values
  ('AOX','DBTH - Case Entry',
     array['Data Entry - Full Arch'],
     'distinct_case','aox_daily','DBTH - Case Entry',10,'cases_target'),

  ('AOX','DBTH - Case Review',
     array['Case Review - Full Arch','Bite Verification QC - Full Arch','Match/Fit Product - Full Arch','Full Arch Case Evaluation'],
     'distinct_pan','aox_daily','DBTH - Case Review',20,'cases_target'),

  ('AOX','Place Parts',
     array['Place Parts 1 - Full Arch','Place Parts 2 - Full Arch','Place Parts 3 - Full Arch','Place Parts TRI Singles - Full Arch','Place Analog - Full Arch','Insert Sleeves - Full Arch'],
     'distinct_pan','aox_daily','Place Parts',30,'cases_target'),

  ('AOX','Design Outsource',
     array['Design - Full Arch','Design Full Arch','Doctor Design Approval - Full Arch','Prepare Full Arch Digital Files for Design'],
     'distinct_pan','aox_daily','Design Outsource',40,'cases_target'),

  ('AOX','Design QC',
     array['QC Design - Full Arch','QC - Hybrid Design'],
     'distinct_pan','aox_daily','Design QC',50,'cases_target'),

  ('AOX','Design Changes',
     array[]::text[],
     'distinct_pan','aox_daily','Design Changes',60,'cases_target'),

  ('AOX','Design Bar',
     array['Design Bar - Full Arch','Design Bar/Framework','Design Bar/Framework (AIX)'],
     'distinct_pan','aox_daily','Design Bar',70,'cases_target'),

  ('AOX','Milling CAM - Bar',
     array['Mill Bar - Full Arch','Mill Bar/Framework','Mill Bar/Framework (AIX)','Mill Bar/Frame'],
     'distinct_pan','aox_daily','Milling CAM - Bar',80,'cases_target'),

  ('AOX','Milling CAM - Arches',
     array['Mill - Full Arch PMMA','Mill Crown TRI - Full Arch','Mill Zirconia - Full Arch','Mill - Hybrid Arch','Nest - Full Arch','Nest Crown TRI - Full Arch','Nest - Hybrid Arch','Dry Zirconia - Full Arch'],
     'distinct_pan','aox_daily','Milling CAM - Arches',90,'cases_target'),

  ('AOX','Sintering',
     array['Sinter - Full Arch'],
     'sum','aox_daily','Sintering',100,'cases_target'),

  ('AOX','Shape and Colorize',
     array['Shape & Colorize - Full Arch Zirconia','Shape and Colorize Hybrid','Shape and Colorize Hybrid1','Remove Support - Full Arch','Fitting - Full Arch PMMA'],
     'sum','aox_daily','Shape and Colorize',110,'cases_target'),

  ('AOX','Bar Cementing',
     array['Bar Cement - Full Arch PMMA','Bar Fit - Full Arch PMMA','Bar Polish - Full Arch PMMA','Bar Prep - Full Arch PMMA','Cement - Full Arch PMMA','Cement - Full Arch Zirconia','Cement Bar','Cement Hybrid','Finish - Bar','Finish Bar - PMMA'],
     'sum','aox_daily','Bar Cementing',120,'cases_target'),

  ('AOX','Finishing PMMA',
     array['Build Up Composite - Full Arch','Finish - Full Arch PMMA','Finish - Full Arch PMMA 2','Shaping - Full Arch PMMA','Finish Full Arch Hybrid - AXFDash','Finish Full Arch Hybrid1 - AXFDash'],
     'sum','aox_daily','Finishing PMMA',130,'cases_target'),

  ('AOX','Finishing Zirc',
     array['Finish - Full Arch Zirconia','Fitting - Full Arch Zirconia','Pink Tissue - Full Arch Zirconia','Repair - Full Arch Zirconia','Stain & Glaze - Full Arch Zirconia','Stain & Glaze - Hybrid'],
     'sum','aox_daily','Finishing Zirc',140,'cases_target'),

  ('AOX','Final QC',
     array['Final QC - Full Arch PMMA','Final QC - Full Arch Zirconia','QC Hybrid','QC Hybrid 1 (AIX)','QC Hybrid Design (AIX)'],
     'sum','aox_daily','Final QC',150,'cases_target'),

  ('AOX','Case Coordination',
     array[]::text[],
     'distinct_case','aox_daily','Case Coordination',160,'cases_target');

commit;

-- ============================================================================
-- ROLLBACK — restores the prior 9 AOX stations (captured 2026-06-10 pre-change).
-- The dpm_resolve_target crosswalk change is safe to leave in place (AOX simply
-- finds no operation_targets match for the old station names and falls back to
-- public.targets); to fully revert, drop the 'AOX' -> 'full-arch' case too.
-- ============================================================================
-- begin;
-- delete from public.station_step_map where business_unit = 'AOX';
-- insert into public.station_step_map
--   (business_unit, station, steps, count_method, target_board, target_dept_name, display_order, target_metric)
-- values
--   ('AOX','Case Entry',      array['Data Entry - Full Arch'], 'distinct_case','aox_daily','Data Entry',10,'cases_target'),
--   ('AOX','Case Review',     array['Bite Verification QC - Full Arch','Case Review - Full Arch','Match/Fit Product - Full Arch'], 'distinct_pan','aox_daily','Case Review',20,'cases_target'),
--   ('AOX','Design QC',       array['QC Design - Full Arch','QC - Hybrid Design'], 'distinct_pan','aox_daily','Design QC',30,'cases_target'),
--   ('AOX','CAM',             array['Dry Zirconia - Full Arch','Mill - Full Arch PMMA','Mill Bar - Full Arch','Mill Crown TRI - Full Arch','Mill Zirconia - Full Arch','Nest - Full Arch','Nest Crown TRI - Full Arch','Sinter - Full Arch'], 'distinct_pan','aox_daily','CAM',40,'cases_target'),
--   ('AOX','Bars',            array['Bar Cement - Full Arch PMMA','Bar Fit - Full Arch PMMA','Bar Polish - Full Arch PMMA','Bar Prep - Full Arch PMMA','Cement - Full Arch PMMA','Cement - Full Arch Zirconia','Cement Bar','Finish - Bar','Finish Bar - PMMA'], 'sum','aox_daily','Bars',50,'cases_target'),
--   ('AOX','Shape & Colorize',array['Fitting - Full Arch PMMA','Remove Support - Full Arch','Shape & Colorize - Full Arch Zirconia'], 'sum','aox_daily','Shape & Colorize',60,'cases_target'),
--   ('AOX','PMMA',            array['Build Up Composite - Full Arch','Finish - Full Arch PMMA','Finish - Full Arch PMMA 2'], 'sum','aox_daily','PMMA',70,'cases_target'),
--   ('AOX','Zirconia',        array['Finish - Full Arch Zirconia','Fitting - Full Arch Zirconia','Pink Tissue - Full Arch Zirconia','Repair - Full Arch Zirconia','Stain & Glaze - Full Arch Zirconia'], 'sum','aox_daily','Zirconia',80,'cases_target'),
--   ('AOX','Final QC',        array['Final QC - Full Arch PMMA','Final QC - Full Arch Zirconia','QC Hybrid'], 'sum','aox_daily','Final QC',90,'cases_target');
-- commit;

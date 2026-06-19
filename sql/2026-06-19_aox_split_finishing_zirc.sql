-- ============================================================================
-- AOX (Full Arch) — split the bundled "Finishing Zirc" board tile into five
-- per-step tiles: Stain & Glaze, Pink Tissue, Fitting, Cement, Repair.
-- Applied to SK Public Supabase (asdunkqodixbhbohxtuq) on 2026-06-19.
--
-- Why:
--   The DepartmentHealth board (BU=AOX) showed a single "Finishing Zirc" tile
--   that rolled six ABS steps into one number, hiding how operators' completed
--   work splits across the individual finishing steps. The board is fully
--   config-driven by public.station_step_map (station_health_list builds the
--   tile list; station_health_get computes actuals from public."Case Steps"
--   where "Step" = any(steps) and "Status" = 'C'), so splitting the tile is a
--   data-only change — no app/HTML change and no redeploy.
--
-- Decisions (from the requester):
--   * Replace "Finishing Zirc" with: Stain & Glaze, Pink Tissue, Fitting,
--     Cement, Repair.
--   * Stain & Glaze combines the Full Arch Zirconia + Hybrid stain/glaze steps.
--   * Cement = "Cement - Full Arch Zirconia" only. The existing "Bar Cementing"
--     tile is LEFT UNTOUCHED and still contains that step, so Zirconia cement is
--     intentionally counted in BOTH tiles.
--   * "Finish - Full Arch Zirconia" is dropped (no longer mapped to any tile).
--   * Targets and metric owners are seeded as placeholders (target 0, owner
--     'Sam' — the prior Finishing Zirc owner) and will be set in the app.
--
-- Note on uniqueness:
--   station_step_map PK = (business_unit, station).
--   operation_targets / metric_owners UNIQUE (business_unit, operation).
-- ============================================================================

begin;

-- 1) Board tiles: remove the bundled tile, add the five per-step tiles.
delete from public.station_step_map where business_unit = 'AOX' and station = 'Finishing Zirc';

insert into public.station_step_map
  (business_unit, station, steps, count_method, target_board, target_dept_name, display_order, target_metric)
values
  ('AOX','Stain & Glaze',
     array['Stain & Glaze - Full Arch Zirconia','Stain & Glaze - Hybrid'],
     'sum','aox_daily','Stain & Glaze',140,'cases_target'),

  ('AOX','Pink Tissue',
     array['Pink Tissue - Full Arch Zirconia'],
     'sum','aox_daily','Pink Tissue',141,'cases_target'),

  ('AOX','Fitting',
     array['Fitting - Full Arch Zirconia'],
     'sum','aox_daily','Fitting',142,'cases_target'),

  ('AOX','Cement',
     array['Cement - Full Arch Zirconia'],
     'sum','aox_daily','Cement',143,'cases_target'),

  ('AOX','Repair',
     array['Repair - Full Arch Zirconia'],
     'sum','aox_daily','Repair',144,'cases_target');

-- 2) Targets: drop the orphaned bundled operation, seed the five (0 = unset).
delete from public.operation_targets where business_unit = 'full-arch' and operation = 'Finishing Zirc';

insert into public.operation_targets (business_unit, operation, target_value)
values
  ('full-arch','Stain & Glaze',0),
  ('full-arch','Pink Tissue',0),
  ('full-arch','Fitting',0),
  ('full-arch','Cement',0),
  ('full-arch','Repair',0);

-- 3) Metric owners: drop the orphaned bundled owner, seed the five (default 'Sam').
delete from public.metric_owners where business_unit = 'full-arch' and operation = 'Finishing Zirc';

insert into public.metric_owners (business_unit, operation, owner_name)
values
  ('full-arch','Stain & Glaze','Sam'),
  ('full-arch','Pink Tissue','Sam'),
  ('full-arch','Fitting','Sam'),
  ('full-arch','Cement','Sam'),
  ('full-arch','Repair','Sam');

commit;

-- ============================================================================
-- ROLLBACK — restores the single bundled "Finishing Zirc" tile (display_order
-- 140) and its target/owner rows, and removes the five per-step tiles.
-- ============================================================================
-- begin;
-- delete from public.station_step_map where business_unit='AOX'
--   and station in ('Stain & Glaze','Pink Tissue','Fitting','Cement','Repair');
-- insert into public.station_step_map
--   (business_unit, station, steps, count_method, target_board, target_dept_name, display_order, target_metric)
-- values
--   ('AOX','Finishing Zirc',
--      array['Finish - Full Arch Zirconia','Fitting - Full Arch Zirconia','Pink Tissue - Full Arch Zirconia','Repair - Full Arch Zirconia','Stain & Glaze - Full Arch Zirconia','Stain & Glaze - Hybrid'],
--      'sum','aox_daily','Finishing Zirc',140,'cases_target');
-- delete from public.operation_targets where business_unit='full-arch'
--   and operation in ('Stain & Glaze','Pink Tissue','Fitting','Cement','Repair');
-- insert into public.operation_targets (business_unit, operation, target_value)
--   values ('full-arch','Finishing Zirc',37);
-- delete from public.metric_owners where business_unit='full-arch'
--   and operation in ('Stain & Glaze','Pink Tissue','Fitting','Cement','Repair');
-- insert into public.metric_owners (business_unit, operation, owner_name)
--   values ('full-arch','Finishing Zirc','Sam');
-- commit;

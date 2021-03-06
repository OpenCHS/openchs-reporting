drop view if exists operational_program_view cascade;
create view operational_program_view as
  select op.id                     as operational_program_id,
         op.uuid                   as operational_program_uuid,
         coalesce(op.name, p.name) as operational_program_name,
         op.is_voided              as operational_program_is_voided,
         p.id                      as program_id,
         p.uuid                    as program_uuid,
         p.name                    as program_name,
         p.is_voided               as program_is_voided
  from operational_program op
         join program p on op.program_id = p.id;

drop view if exists operational_encounter_type_view cascade;
create view operational_encounter_type_view as
  select oet.id                      as operational_encounter_type_id,
         oet.uuid                    as operational_encounter_type_uuid,
         coalesce(oet.name, et.name) as operational_encounter_type_name,
         oet.is_voided               as operational_encounter_type_is_voided,
         et.id                       as encounter_type_id,
         et.uuid                     as encounter_type_uuid,
         et.name                     as encounter_type_name,
         et.is_voided                as encounter_type_is_voided
  from operational_encounter_type oet
         join encounter_type et on oet.encounter_type_id = et.id;

drop view if exists program_enrolment_view cascade;
create view program_enrolment_view as
  select pe.*,
         op.operational_program_uuid,
         op.operational_program_name,
         op.operational_program_is_voided,
         op.program_uuid,
         op.program_name,
         op.program_is_voided
  from program_enrolment pe
         join operational_program_view op on op.program_id = pe.program_id
  where pe.is_voided is not true; -- it is not same as '= false'

drop view if exists non_exited_program_enrolment_view cascade;
create view non_exited_program_enrolment_view as
  select *
  from program_enrolment_view
  where program_exit_date_time isnull;

drop view if exists program_encounter_view cascade;
create view program_encounter_view as
  select pe.*,
         oet.operational_encounter_type_uuid,
         oet.operational_encounter_type_name,
         oet.operational_encounter_type_is_voided,
         oet.encounter_type_uuid,
         oet.encounter_type_name,
         oet.encounter_type_is_voided
  from program_encounter pe
         join operational_encounter_type_view oet on oet.encounter_type_id = pe.encounter_type_id
  where pe.is_voided is not true;

drop view if exists encountered_program_encounter_view cascade;
drop view if exists completed_program_encounter_view cascade;
create view completed_program_encounter_view as
  select *
  from program_encounter_view
  where encounter_date_time is not null;

drop view if exists unplanned_program_encounter_view cascade;
create view unplanned_program_encounter_view as
  select *
  from program_encounter_view
  where earliest_visit_date_time is null;

drop view if exists scheduled_program_encounter_view cascade;
drop view if exists planned_program_encounter_view cascade;
create view planned_program_encounter_view as
  select *
  from program_encounter_view
  where earliest_visit_date_time is not null;

drop view if exists non_cancelled_scheduled_program_encounter_view cascade;
drop view if exists non_cancelled_planned_program_encounter_view cascade;
create view non_cancelled_planned_program_encounter_view as
  select *
  from program_encounter_view
  where cancel_date_time is null
    and earliest_visit_date_time is not null;

drop view if exists cancelled_scheduled_program_encounter_view cascade;
drop view if exists cancelled_planned_program_encounter_view cascade;
create view cancelled_planned_program_encounter_view as
  select *
  from program_encounter_view
  where cancel_date_time is not null
    and earliest_visit_date_time is not null;

drop view if exists incomplete_planned_program_encounter_view cascade;
create view incomplete_planned_program_encounter_view as
  select *
  from planned_program_encounter_view
  where encounter_date_time is null
    and cancel_date_time is null;

drop view if exists individual_view cascade;
create view individual_view as
  select *, first_name || ' ' || last_name as full_name
  from individual
  where is_voided is not true;

drop view if exists individual_gender_view cascade;
create view individual_gender_view as
  select i.*, g.name as gender
  from individual_view i
         join gender g on g.id = i.gender_id;

drop view if exists individual_gender_address_view cascade;
create view individual_gender_address_view as
  select i.*,
         l.title      as addresslevel_name,
         lt.level     as addresslevel_level,
         l.uuid       as addresslevel_uuid,
         l.is_voided  as addresslevel_is_voided,
         lt.name      as addresslevel_type,
         lt.uuid      as addresslevel_type_uuid,
         lt.is_voided as addresslevel_type_is_voided
  from individual_gender_view i
         join address_level l on i.address_id = l.id
         join address_level_type lt on l.type_id = lt.id;

drop view if exists individual_gender_catchment_view cascade;
create view individual_gender_catchment_view as
  select i.*,
         c.id        as catchment_id,
         c.name      as catchment_name,
         c.uuid      as catchment_uuid,
         c.is_voided as catchment_is_voided
  from individual_gender_address_view i
         join virtual_catchment_address_mapping_table vt on vt.addresslevel_id = i.address_id
         join catchment c on c.id = vt.catchment_id;

drop view if exists all_enrolment_unplanned_encounters_agg_view cascade;
drop view if exists all_enrolment_encountered_encounters_agg_view cascade;
drop view if exists all_enrolment_completed_encounters_agg_view cascade;
create view all_enrolment_completed_encounters_agg_view AS
  WITH agg as (
      SELECT e.individual_id,
             e.program_id,
             jsonb_merge(jsonb_agg(e.observations || jsonb_strip_nulls(pe.observations))) obs
      FROM program_encounter pe
             JOIN program_enrolment e ON pe.program_enrolment_id = e.id
      where e.is_voided is not true
        and pe.is_voided is not true
        and pe.encounter_date_time is not null
      GROUP BY e.individual_id, e.program_id
  )
  select agg.individual_id,
         agg.program_id,
         agg.obs as agg_obs,
         op.operational_program_uuid,
         op.operational_program_name,
         op.operational_program_is_voided,
         op.program_uuid,
         op.program_name,
         op.program_is_voided
  from agg
         join operational_program_view op on op.program_id = agg.program_id;

create or replace view all_enrolment_completed_encounters_agg_view_v2 AS
  SELECT e.individual_id,
         e.id program_enrolment_id,
         e.observations
           || jsonb_merge(jsonb_agg(
                            jsonb_strip_nulls(pe.observations) order by pe.encounter_date_time
                              )) obs
  FROM program_encounter pe
         JOIN program_enrolment e ON pe.program_enrolment_id = e.id
  where e.is_voided is not true
    and pe.is_voided is not true
    and pe.encounter_date_time is not null
  GROUP BY 1, 2;

drop view if exists non_exited_enrolment_completed_encounters_agg_view cascade;
create view non_exited_enrolment_completed_encounters_agg_view AS
  WITH agg as (
      SELECT e.individual_id,
             e.program_id,
             jsonb_merge(jsonb_agg(e.observations || jsonb_strip_nulls(pe.observations))) obs
      FROM program_encounter pe
             JOIN program_enrolment e ON pe.program_enrolment_id = e.id
      where e.is_voided is not true
        and pe.is_voided is not true
        and pe.encounter_date_time is not null
        and e.program_exit_date_time is null
      GROUP BY e.individual_id, e.program_id
  )
  select agg.individual_id,
         agg.program_id,
         agg.obs as agg_obs,
         op.operational_program_uuid,
         op.operational_program_name,
         op.operational_program_is_voided,
         op.program_uuid,
         op.program_name,
         op.program_is_voided
  from agg
         join operational_program_view op on op.program_id = agg.program_id;

drop view if exists all_completed_encounters_per_enrolment_agg_view cascade;
create view all_completed_encounters_per_enrolment_agg_view as
  with
      completed_program_encounters as (
        select program_enrolment_id, encounter_date_time, observations
        from program_encounter
        where is_voided is not true
          and encounter_date_time is not null
    )
  select program_enrolment_id, jsonb_merge(jsonb_agg(jsonb_strip_nulls(observations))) observations
  from completed_program_encounters
  group by program_enrolment_id;

drop view if exists individual_relationship_view cascade;
create view individual_relationship_view as
  select ir.*, irt.uuid as type_uuid, a_is_to_b.name as a_is_to_b, b_is_to_a.name as b_is_to_a
  from individual_relationship ir
         join individual_relationship_type irt on ir.relationship_type_id = irt.id
         join individual_relation a_is_to_b on irt.individual_a_is_to_b_relation_id = a_is_to_b.id
         join individual_relation b_is_to_a on irt.individual_b_is_to_a_relation_id = b_is_to_a.id
  where ir.is_voided is not true;

drop view if exists individual_all_relationships_view cascade;
create view individual_all_relationships_view(a, b, a_is_to_b, b_is_to_a) as
  select individual_a_id, individual_b_id, a_is_to_b, b_is_to_a
  from individual_relationship_view
  union all
  select individual_b_id, individual_a_id, b_is_to_a, a_is_to_b
  from individual_relationship_view;

drop view if exists individual_name_relationship_view cascade;
create view individual_name_relationship_view as
  select irv.*,
         a.uuid       auuid,
         a.first_name afirst_name,
         a.last_name  alast_name,
         a.full_name  afull_name,
         b.uuid       buuid,
         b.first_name bfirst_name,
         b.last_name  blast_name,
         b.full_name  bfull_name
  from individual_relationship_view irv
         join individual_view a on a.id = irv.individual_a_id
         join individual_view b on b.id = irv.individual_b_id;

drop view if exists encounter_view cascade;
create view encounter_view as
  select *
  from encounter
  where is_voided is not true;

drop view if exists checklist_view cascade;
create view checklist_view as
  select cl.*,
         cd.id        list_detail_id,
         cd.uuid      list_detail_uuid,
         cd.name      list_detail_name,
         cd.is_voided list_detail_is_voided
  from checklist cl
         join checklist_detail cd on cl.checklist_detail_id = cd.id
  where cl.is_voided is not true;

drop type if exists status_type cascade;
create type status_type as
(
  "to"           jsonb,
  "from"         jsonb,
  "start"        integer,
  "end"          integer,
  state          varchar,
  "displayOrder" numeric
);

drop view if exists checklist_item_reference cascade;
create or replace view checklist_item_reference as
  with time_mapping as (
      select *
      from (values ('day', 86400),
                   ('days', 86400),
                   ('week', 604800),
                   ('weeks', 604800),
                   ('month', 2592000),
                   ('months', 2592000),
                   ('year', 31556952),
                   ('years', 31556952)) as tm
  ), raw_status as (
      select id,
             (jsonb_each_text((jsonb_populate_recordset(null :: status_type, status)).to)).key     as tokey,
             (jsonb_each_text((jsonb_populate_recordset(null :: status_type, status)).to)).value   as tovalue,
             (jsonb_each_text((jsonb_populate_recordset(null :: status_type, status)).from)).key   as fromkey,
             (jsonb_each_text((jsonb_populate_recordset(null :: status_type, status)).from)).value as fromvalue,
             (jsonb_populate_recordset(null :: status_type, status)).state,
             (jsonb_populate_recordset(null :: status_type, status))."displayOrder"                as display_order,
             (jsonb_populate_recordset(null :: status_type, status)).start,
             (jsonb_populate_recordset(null :: status_type, status)).end
      from checklist_item_detail
  ), status_mapping as (
      select rs.id,
             rs.tovalue :: int * tm1.column2   as to,
             rs.fromvalue :: int * tm2.column2 as from,
             rs.start * 86400                  as start,
             rs.end * 86400                    as end,
             rs.state                          as state,
             rs.display_order
      from raw_status rs
             inner join time_mapping tm1 on tokey = tm1.column1
             inner join time_mapping tm2 on fromkey = tm2.column1
  )
  select cid.id,
         cid.uuid,
         cid.form_id,
         cid.status,
         cid.min_days_from_start_date,
         cid.schedule_on_expiry_of_dependency,
         cid.expires_after,
         cid.min_days_from_dependent,
         c.name,
         sm.to,
         sm.from,
         sm.state,
         sm.display_order,
         sm.start,
         sm.end,
         cid.dependent_on,
         cid.is_voided
  from checklist_item_detail cid
         left outer join status_mapping sm on sm.id = cid.id
         inner join concept c on c.id = cid.concept_id
  where cid.is_voided is not true;

drop view if exists checklist_item_view cascade;
create view checklist_item_view as
  select ci.*,
         cid.uuid          item_detail_uuid,
         cid.form_id       item_detail_form_id,
         cid.name          item_detail_name,
         cid.status        item_detail_status,
         cid.dependent_on  item_detail_dependent_on,
         cid.is_voided     item_detail_is_voided,
         cid.to            item_detail_to,
         cid.from          item_detail_from,
         cid.start         item_detail_start,
         cid.end           item_detail_end,
         cid.state         item_detail_state,
         cid.display_order item_detail_display_order,
         cid.min_days_from_start_date,
         cid.schedule_on_expiry_of_dependency,
         cid.expires_after,
         cid.min_days_from_dependent
  from checklist_item ci
         join checklist_item_reference cid on ci.checklist_item_detail_id = cid.id
  where ci.is_voided is not true;

drop view if exists checklist_item_checklist_view cascade;
create view checklist_item_checklist_view as
  select ci.*,
         clv.uuid list_uuid,
         clv.program_enrolment_id,
         clv.base_date,
         clv.list_detail_id,
         clv.list_detail_uuid,
         clv.list_detail_name,
         clv.list_detail_is_voided
  from checklist_item_view ci
         join checklist_view clv on clv.id = ci.checklist_id;

drop view if exists latest_program_encounter CASCADE;
create view latest_program_encounter as
  with latest_on_top as (
    with encounter as (
        select encounter.*,
               enrolment.individual_id                                             individual_id,
               coalesce(encounter.encounter_date_time, encounter.cancel_date_time) effective_date,
               et.name                                                             encounter_type_name
        from program_encounter encounter
               join encounter_type et on encounter_type_id = et.id
               join program_enrolment enrolment on enrolment.id = encounter.program_enrolment_id
    )
    select encounter.*, row_number() OVER (PARTITION BY individual_id ORDER BY effective_date desc) rank
    from encounter
    where effective_date is not null
  )
  select *
  from latest_on_top
  where rank = 1;

create or replace view location_view as
  select top1.title top1,
         top2.title top2,
         top3.title top3,
         top4.title top4,
         top5.title top5,
         top6.title top6,
         top1.id    top1id,
         top2.id    top2id,
         top3.id    top3id,
         top4.id    top4id,
         top5.id    top5id,
         top6.id    top6id
  from address_level top1
         left join address_level top2 on top2.parent_id = top1.id
         left join address_level top3 on top3.parent_id = top2.id
         left join address_level top4 on top4.parent_id = top3.id
         left join address_level top5 on top5.parent_id = top4.id
         left join address_level top6 on top6.parent_id = top5.id
  where top1.parent_id is null;

drop view if exists concept_concept_answer;
create view concept_concept_answer as (
    select c.name          concept_name,
           ac.name         answer_concept_name,
           ca.is_voided    answer_concept_voided,
           c.is_voided     concept_voided,
           ca.answer_order answer_order,
           ac.uuid         answer_concept_uuid,
           c.uuid          concept_uuid
    from concept c
             join concept_answer ca on c.id = ca.concept_id
             join concept ac on ca.answer_concept_id = ac.id
    where not ca.is_voided
);

drop view if exists member_household_view;
create view member_household_view(member_name, member_id, house_name, house_id, head_of_family_name,
                                           head_of_family_id) as
SELECT concat(member.first_name, ' ', member.last_name) AS member_name,
       member.id                                        AS member_id,
       house.first_name                                 AS house_name,
       house.id                                         AS house_id,
       (SELECT concat(head.first_name, ' ', head.last_name) AS concat
        FROM individual head
        WHERE (head.id = gs2.member_subject_id))        AS head_of_family_name,
       gs2.member_subject_id                            AS head_of_family_id
FROM (((((individual member
    JOIN subject_type ON (((member.subject_type_id = subject_type.id) AND ((subject_type.type)::text = 'Person'::text))))
    LEFT JOIN group_subject gs ON (((gs.member_subject_id = member.id) AND (NOT gs.is_voided))))
    LEFT JOIN individual house ON ((house.id = gs.group_subject_id)))
    LEFT JOIN group_subject gs2 ON ((gs2.group_subject_id = house.id)))
         LEFT JOIN group_role gr ON ((gs2.group_role_id = gr.id)))
WHERE (((NOT gs2.is_voided) AND (gr.role = 'Head of household'::text)) OR (gr.role IS NULL));

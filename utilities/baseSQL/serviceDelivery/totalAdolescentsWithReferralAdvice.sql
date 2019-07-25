WITH individual_program_partitions AS (
  SELECT i.uuid          AS                                                                                   iuuid,
         row_number() OVER (PARTITION BY i.uuid, pe.encounter_type_name ORDER BY pe.encounter_date_time desc) erank,
         pe.uuid         AS                                                                                   euuid,
         pe.observations AS                                                                                   obs,
         pe.encounter_date_time
  FROM completed_program_encounter_view pe
         INNER JOIN non_exited_program_enrolment_view e ON pe.program_enrolment_id = e.id
         INNER JOIN individual_view i ON e.individual_id = i.id
  WHERE e.program_name = 'Adolescent'
    and (pe.encounter_type_name = 'Annual Visit' or pe.encounter_type_name = 'Quarterly Visit')
    [[and pe.encounter_date_time >=(q1 || q4 || quote_literal({{ start_date }}) || q4 || q1  ::DATE)]]
      [[and pe.encounter_date_time <=q1 || q4 || quote_literal({{end_date}}) || q4 || q1 ::DATE]]
), individual_partitions AS (
  select *,
         row_number() OVER (PARTITION BY pe.iuuid ORDER BY pe.encounter_date_time desc) irank
  from individual_program_partitions pe
  where erank = 1
)
SELECT
  ip.iuuid uuid,
  i.gender    gender_name,
  i.addresslevel_type   address_type,
  i.addresslevel_name   address_name
FROM individual_partitions ip
  LEFT OUTER JOIN individual_gender_address_view i ON i.uuid = ip.iuuid
WHERE ip.obs -> '0e620ea5-1a80-499f-9d07-b972a9130d60' IS NOT NULL
  AND irank = 1

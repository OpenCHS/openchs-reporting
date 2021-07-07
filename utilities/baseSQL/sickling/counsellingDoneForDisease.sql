WITH individual_program_partitions AS (
  SELECT i.uuid          AS                                                           iuuid,
         row_number() OVER (PARTITION BY i.uuid ORDER BY pe.encounter_date_time desc) erank,
         pe.uuid         AS                                                           euuid,
         pe.observations AS                                                           obs,
         pe.encounter_date_time
  FROM completed_program_encounter_view pe
         INNER JOIN non_exited_program_enrolment_view e ON pe.program_enrolment_id = e.id
         INNER JOIN individual_view i ON e.individual_id = i.id
  WHERE e.program_name = 'Adolescent' AND pe.observations ->> 'b5daf90d-5b71-4b53-827f-edd4f6539d15'  = '2c343c7a-db14-4531-902a-d7b169300073'
      [[and e.enrolment_date_time >=(q1 || q4 || quote_literal({{ start_date }}) || q4 || q1  ::DATE)]]
      [[and e.enrolment_date_time <=q1 || q4 || quote_literal({{end_date}}) || q4 || q1 ::DATE]]
      [[and i.addresslevel_name = q1 || q4 || quote_literal({{title}}) || q4 || q1]]
),
individual_program_partitions_couselling_done AS (
  SELECT i.uuid          AS                                                           iuuid,
         row_number() OVER (PARTITION BY i.uuid ORDER BY pe.encounter_date_time desc) erank,
         pe.uuid         AS                                                           euuid,
         pe.observations AS                                                           obs,
         pe.encounter_date_time
  FROM completed_program_encounter_view pe
         INNER JOIN non_exited_program_enrolment_view e ON pe.program_enrolment_id = e.id
         INNER JOIN individual_view i ON e.individual_id = i.id
  WHERE e.program_name = 'Adolescent'
   AND pe.observations ->> 'f44951a6-adc2-4983-947f-f8327ce05419' = '04bb1773-c353-44a1-a68c-9b448e07ff70'
   and pe.name = 'Sickle Cell Followup'
)
SELECT distinct i.uuid              as uuid,
       i.gender            as gender_name,
       i.addresslevel_type as address_type,
       i.addresslevel_name as address_name,
       ip.obs -> 'b5daf90d-5b71-4b53-827f-edd4f6539d15' AS TEST_RESULT,
       c.obs ->> 'f44951a6-adc2-4983-947f-f8327ce05419'
FROM individual_program_partitions ip
       JOIN individual_gender_address_view i ON i.uuid = ip.iuuid
       JOIN individual_program_partitions_couselling_done c on c.iuuid = i.uuid
WHERE ip.erank = 1 and c.erank = 1


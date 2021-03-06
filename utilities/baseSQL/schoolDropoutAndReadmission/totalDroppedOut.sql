WITH individual_program_partitions AS (
  SELECT i.uuid          AS                                                                                   iuuid,
         row_number() OVER (PARTITION BY i.uuid ORDER BY pe.encounter_date_time desc) erank,
         pe.uuid         AS                                                                                   euuid,
         pe.observations AS                                                                                   obs,
         pe.encounter_date_time
  FROM completed_program_encounter_view pe
         INNER JOIN non_exited_program_enrolment_view e ON pe.program_enrolment_id = e.id
         INNER JOIN individual_view i ON e.individual_id = i.id
  WHERE e.program_name = 'Adolescent'
    and (pe.encounter_type_name = 'Annual Visit' or pe.encounter_type_name = 'Quarterly Visit')
)
SELECT
  ip.iuuid            uuid,
  i.gender            gender_name,
  i.addresslevel_type address_type,
  i.addresslevel_name address_name
FROM individual_program_partitions ip
       LEFT OUTER JOIN individual_gender_address_view i ON i.uuid = ip.iuuid
WHERE ip.obs @> '{"575a29c3-a070-4c7d-ac96-fe58b6bddca3": "58f789aa-6570-4aea-87a7-1f7651729c5a"}'
  AND erank = 1

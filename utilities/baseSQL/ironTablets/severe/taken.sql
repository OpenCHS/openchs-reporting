set role sewa_rural;
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
    AND pe.encounter_type_name = 'Annual Visit'
    AND pe.observations -> '56358db1-8d55-4fbf-89c5-fde97c819c2c' NOTNULL
    AND pe.observations ->> 'f9ecabbc-2df2-4bfc-a6fa-aa417c50e11b' notnull
    and (e.enrolment_date_time ISNULL OR e.enrolment_date_time between ${start_date} and ${end_date})
)
SELECT i.uuid              as uuid,
       i.gender            as gender_name,
       i.addresslevel_type as address_type,
       i.addresslevel_name as address_name
FROM individual_program_partitions ip
       JOIN individual_gender_address_view i ON i.uuid = ip.iuuid
WHERE cast(ip.obs ->> '56358db1-8d55-4fbf-89c5-fde97c819c2c' AS INT) > 1
  AND cast(ip.obs ->> 'f9ecabbc-2df2-4bfc-a6fa-aa417c50e11b' AS FLOAT) <= 7
  AND erank = 1;
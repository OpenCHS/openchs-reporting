SELECT i.uuid as uuid,
       i.gender as gender_name,
       i.addresslevel_type as address_type,
       i.addresslevel_name as address_name
FROM non_exited_enrolment_completed_encounters_agg_view lpe
      JOIN individual_gender_address_view i ON i.id = lpe.individual_id
      JOIN non_exited_program_enrolment_view e ON e.individual_id = i.id
WHERE lpe.program_name = 'Adolescent'
      AND lpe.agg_obs @> '{"32005c85-c1de-4fc3-9314-6d6a10f34b57":"d7443a73-80b7-4320-9c45-6558595be70a"}'
      [[and e.enrolment_date_time >=(q1 || q4 || quote_literal({{ start_date }}) || q4 || q1  ::DATE)]]
      [[and e.enrolment_date_time <=q1 || q4 || quote_literal({{end_date}}) || q4 || q1 ::DATE]]

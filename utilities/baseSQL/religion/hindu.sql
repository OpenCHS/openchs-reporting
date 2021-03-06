
SELECT
    i.uuid uuid,
    g.name    gender_name,
    a.type    address_type,
    a.title   address_name
FROM individual i
         LEFT OUTER JOIN address_level_type_view a ON i.address_id = a.id
         LEFT OUTER JOIN gender g ON i.gender_id = g.id
         join program_enrolment_view pe on i.id = pe.individual_id
where i.observations @> '{"c922c13c-1fa2-42dd-a7e8-d234b0324870":"5f1f8a86-478b-4e7b-ae5e-ac7b207e65b8"}'
 and pe.enrolment_date_time notnull and pe.program_name='Adolescent'
  and i.is_voided=false
   and pe.program_exit_date_time isnull
and
   pe.enrolment_date_time between 'FILTERS.start_date' and 'FILTERS.end_date'

SELECT i.uuid as uuid,
       i.gender as gender_name,
       i.addresslevel_type as address_type,
       i.addresslevel_name as address_name
FROM non_exited_enrolment_completed_encounters_agg_view lpe
      JOIN individual_gender_address_view i ON i.id = lpe.individual_id
WHERE lpe.program_name = 'Adolescent'
      AND lpe.obs @> '{"9083aae8-0a78-4b5b-9177-dd993e6d088c":"1645d2d8-9dc8-4a6a-ad6c-50b0cca09190"}'
      OR lpe.obs @> '{"9083aae8-0a78-4b5b-9177-dd993e6d088c":"6b384012-b46d-4397-b17e-a0b4fa2e4469"}'

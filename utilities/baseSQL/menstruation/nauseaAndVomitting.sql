SELECT i.uuid as uuid,
       i.gender as gender_name,
       i.addresslevel_type as address_type,
       i.addresslevel_name as address_name
FROM all_enrolment_encountered_encounters_agg_view lpe
      JOIN individual_gender_address_view i ON i.id = lpe.individual_id
WHERE lpe.program_name = 'Adolescent' AND
      lpe.agg_obs -> '0f87eac1-cf6a-4632-8af2-29a935451fe4' IS NOT NULL AND
      lpe.agg_obs -> '0f87eac1-cf6a-4632-8af2-29a935451fe4' ?| ARRAY ['761b7f7a-5db7-4115-aa84-32fcfce5ddfc']

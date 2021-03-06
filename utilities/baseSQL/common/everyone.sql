SELECT
    DISTINCT
    i.uuid  uuid,
    g.name  gender_name,
    a.type  address_type,
    a.title address_name
FROM
    individual i
    LEFT OUTER JOIN gender g ON g.id = i.gender_id
    LEFT OUTER JOIN address_level_type_view a ON i.address_id = a.id
    [[ and i.registration_date >=(q1 || q4 || quote_literal({{ start_date }}) || q4 || q1  ::DATE)]]
    [[and i.registration_date <=q1 || q4 || quote_literal({{end_date}}) || q4 || q1 ::DATE]]
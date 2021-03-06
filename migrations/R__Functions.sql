CREATE OR REPLACE FUNCTION concept_uuid(TEXT)
  RETURNS TEXT
AS 'SELECT uuid
    FROM concept
    WHERE name = $1;'
LANGUAGE SQL
STABLE
RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION coded_obs_answer_uuids(JSONB, TEXT)
  RETURNS TEXT [] AS $$
DECLARE
  answerConceptUUIDs TEXT;
BEGIN
  SELECT translate($1 ->> concept_uuid($2), '[]', '{}')
    INTO answerConceptUUIDs;
  IF answerConceptUUIDs IS NULL
  THEN
    RETURN '{}';
  ELSIF POSITION('{' IN answerConceptUUIDs) = 0
    THEN
      RETURN '{' || answerConceptUUIDs || '}';
  END IF;
  RETURN answerConceptUUIDs;
END;
$$
LANGUAGE plpgsql;

------------------------------------------------------------ GET OBSERVATION DATA ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION text_obs(JSONB, TEXT)
  RETURNS TEXT
AS 'SELECT $1 ->> concept_uuid($2);'
LANGUAGE SQL
STABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE FUNCTION text_obs(ANYELEMENT, TEXT)
  RETURNS TEXT
AS 'SELECT text_obs($1.observations :: JSON, $2);'
LANGUAGE SQL
STABLE
RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION numeric_obs(JSONB, TEXT)
  RETURNS NUMERIC AS $$
DECLARE obs NUMERIC;
BEGIN
  SELECT $1 ->> concept_uuid($2)
    INTO obs;
  RETURN obs;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION numeric_obs(ANYELEMENT, TEXT)
  RETURNS NUMERIC AS $$
DECLARE obs NUMERIC;
BEGIN
  SELECT $1.observations ->> concept_uuid($2)
    INTO obs;
  RETURN obs;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION date_obs(JSONB, TEXT)
  RETURNS TIMESTAMP AS $$
DECLARE obs TIMESTAMP;
BEGIN
  SELECT $1 ->> concept_uuid($2)
    INTO obs;
  RETURN obs;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION date_obs(ANYELEMENT, TEXT)
  RETURNS TIMESTAMP AS $$
DECLARE obs TIMESTAMP;
BEGIN
  SELECT $1.observations ->> concept_uuid($2)
    INTO obs;
  RETURN obs;
END;
$$
LANGUAGE plpgsql;


-- Returns comma separated concept names chosen as answer for the observation
CREATE OR REPLACE FUNCTION coded_obs(JSONB, TEXT)
  RETURNS TEXT AS $$
DECLARE   uuids         TEXT [];
  DECLARE concept_names TEXT;
  DECLARE x             TEXT;
BEGIN
  SELECT translate($1 ->> concept_uuid($2), '[]', '{}')
    INTO uuids;
  IF uuids IS NOT NULL
  THEN
    FOREACH x IN ARRAY uuids
    LOOP
      SELECT name FROM concept WHERE uuid = x
        INTO x;
      concept_names := format('%s, %s', concept_names, x);
    END LOOP;
    -- remove the first space and comma
    RETURN substring(concept_names FROM 3);
  END IF;
  RETURN '';
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION coded_obs(ANYELEMENT, TEXT)
  RETURNS TEXT AS $$
DECLARE observations TEXT;
BEGIN
  SELECT coded_obs($1.observations :: JSON)
    INTO observations;
  RETURN observations;
END;
$$
LANGUAGE plpgsql;

------------------------------------------------------------- QUERY OBSERVATIONS ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION coded_obs_exists(JSONB, TEXT)
  RETURNS BOOLEAN AS $$
DECLARE uuids TEXT [];
BEGIN
  SELECT translate($1 ->> concept_uuid($2), '[]', '{}')
    INTO uuids;
  RETURN uuids IS NOT NULL;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION coded_obs_exists(ANYELEMENT, TEXT)
  RETURNS BOOLEAN AS $$
DECLARE returnValue BOOLEAN;
BEGIN
  SELECT coded_obs_exists($1.observations, $2)
    INTO returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql;


-- Returns whether any of the observation (for concept in second argument), in the entity (first argument) contains the passed answer (third arg)
CREATE OR REPLACE FUNCTION coded_obs_contains(JSONB, TEXT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  answerConceptUUID TEXT;
  exists            BOOLEAN := FALSE;
  answerConceptName TEXT;
BEGIN
  FOREACH answerConceptUUID IN ARRAY coded_obs_answer_uuids($1, $2)
  LOOP
    FOREACH answerConceptName IN ARRAY $3
    LOOP
      SELECT name = answerConceptName FROM concept WHERE uuid = answerConceptUUID
        INTO exists;
      IF exists
      THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  END LOOP;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION coded_obs_contains(ANYELEMENT, TEXT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  returnValue BOOLEAN;
BEGIN
  SELECT coded_obs_contains($1.observations :: JSON, $2, $3)
    INTO returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION coded_obs_contains_any_except(JSONB, TEXT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  answerConceptUUIDs TEXT [];
  answerConceptUUID  TEXT;
  exists             BOOLEAN := FALSE;
  answerConceptName  TEXT;
BEGIN
  SELECT coded_obs_answer_uuids($1, $2)
    INTO answerConceptUUIDs;
  IF array_length(answerConceptUUIDs, 1) > 0
  THEN
    FOREACH answerConceptUUID IN ARRAY answerConceptUUIDs
    LOOP
      FOREACH answerConceptName IN ARRAY $3
      LOOP
        SELECT name = answerConceptName FROM concept WHERE uuid = answerConceptUUID
          INTO exists;
        IF exists
        THEN
          RETURN FALSE;
        END IF;
      END LOOP;
    END LOOP;
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION one_of_coded_obs_contains(JSONB, TEXT [], TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  exists BOOLEAN := FALSE;
  i      INTEGER := 1;
BEGIN
  LOOP
    EXIT WHEN i > array_length($2, 1);
    SELECT coded_obs_contains($1, $2 [ i ], $3)
      INTO exists;
    IF exists
    THEN
      RETURN TRUE;
    END IF;
    i := i + 1;
  END LOOP;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION one_of_coded_obs_contains(ANYELEMENT, TEXT [], TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  returnValue BOOLEAN;
BEGIN
  SELECT one_of_coded_obs_contains($1.observations :: JSON, $2, $3)
    INTO returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql;


-- Returns whether any the observation (for concept in second argument), in the entities (first argument) contains the passed answer (third arg)
CREATE OR REPLACE FUNCTION in_one_entity_coded_obs_contains(JSONB, JSONB, TEXT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  exists BOOLEAN := FALSE;
BEGIN
  SELECT coded_obs_contains($1, $3, $4) OR coded_obs_contains($2, $3, $4)
    INTO exists;
  RETURN exists;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION in_one_entity_coded_obs_contains(PROGRAM_ENROLMENT, PROGRAM_ENCOUNTER, TEXT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  returnValue BOOLEAN;
BEGIN
  SELECT in_one_entity_coded_obs_contains($1.observations :: JSON, $2.observations :: JSON, $3, $4)
    INTO returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION one_of_coded_obs_exists(JSONB, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  exists BOOLEAN := FALSE;
  i      INTEGER := 1;
BEGIN
  LOOP
    EXIT WHEN i > array_length($2, 1);
    SELECT coded_obs_exists($1, $2 [ i ])
      INTO exists;
    IF exists
    THEN
      RETURN TRUE;
    END IF;
    i := i + 1;
  END LOOP;
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION one_of_coded_obs_exists(ANYELEMENT, TEXT [])
  RETURNS BOOLEAN AS $$
DECLARE
  returnValue BOOLEAN;
BEGIN
  SELECT one_of_coded_obs_exists($1.observations :: JSON, $2)
    INTO returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql;

-------------------------------- VISIT RELATED --------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_overdue_visit(PROGRAM_ENCOUNTER)
  RETURNS NUMERIC AS $$
BEGIN
  IF $1.earliest_visit_date_time IS NULL
  THEN
    RETURN 0;
  ELSEIF $1.earliest_visit_date_time > current_timestamp AND $1.encounter_date_time IS NULL
    THEN
      RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END;
$$
LANGUAGE plpgsql;

--------------------------------- REPORTING FUNCTIONS ----------------------------------------------------------------
DROP FUNCTION IF EXISTS frequency_and_percentage(TEXT);
DROP FUNCTION IF EXISTS frequency_and_percentage(TEXT, TEXT);

CREATE OR REPLACE FUNCTION frequency_and_percentage(frequency_query TEXT)
  RETURNS TABLE
  (
    total        BIGINT,
    percentage   FLOAT,
    gender       VARCHAR,
    address_type VARCHAR
  )
AS
$$
BEGIN
  RETURN QUERY EXECUTE FORMAT('WITH query_output as ( %s ),' ||
                              'aggregates_all as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     alt.name        address_type
                                                   FROM query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided and not g.is_voided
                                                   GROUP BY g.name, alt.name),' ||
                              'aggregates_alt as (SELECT
                                                     count(qo.uuid)  total,
                                                     ''Total''::varchar       gender,
                                                     alt.name        address_type
                                                   FROM query_output qo
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided
                                                   GROUP BY alt.name),' ||
                              'aggregates_gender as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     ''All''::varchar         address_type
                                                   FROM query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                   WHERE not g.is_voided
                                                   GROUP BY g.name),' ||
                              'aggregates_none as (SELECT
                                                     count(qo.uuid)    total,
                                                     ''Total''::varchar         gender,
                                                     ''All''::varchar           address_type
                                                   FROM query_output qo),' ||
                              'aggregates as (select * from aggregates_all
                                              union all select * from aggregates_alt
                                              union all select * from aggregates_gender
                                              union all select * from aggregates_none),' ||
                              'aggregates_percentage as (select *,
                                                          coalesce(round(((ag1.total / nullif((SELECT sum(ag2.total)
                                               FROM aggregates ag2
                                               WHERE (ag2.address_type = ag1.address_type AND ag2.gender != ''Total''::varchar)),0))
                                 * 100), 2), 100) as percentage from aggregates ag1),' ||
                              'all_data as (select total, percentage, address_type, gender from aggregates_percentage
                                           union all
                                           SELECT 0, 0::float, atname, gname from (
                                                   SELECT DISTINCT type atname,
                                                   name gname
                                                 FROM address_level_type_view, gender
                                                 UNION ALL
                                                 SELECT
                                                   ''All''::varchar atname,
                                                   name gname
                                                 FROM gender
                                                 UNION ALL
                                                 SELECT DISTINCT
                                                   type atname,
                                                   ''Total''::varchar gname
                                                 FROM address_level_type_view
                                                 UNION ALL
                                                 SELECT
                                                   ''All''::varchar atname,
                                                   ''Total''::varchar gname) as agt where (atname, gname) not in (select address_type, gender from aggregates))' ||
                              'select total, percentage, gender, address_type from all_data order by address_type, gender',
                              replace(frequency_query, ';', ''));
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION frequency_and_percentage_oneline(frequency_query TEXT, denominator_query TEXT)
  RETURNS TABLE(value JSONB) AS
$$
BEGIN
  return query select jsonb_merge(
                        jsonb_agg(
                          jsonb_build_object(
                            address_type || ' ' || gender,
                            total :: TEXT || ' (' || percentage :: VARCHAR(5) || '%)'
                            ))) as value
               from frequency_and_percentage(frequency_query, denominator_query);
END
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION frequency_and_percentage(frequency_query TEXT, denominator_query TEXT)
  RETURNS TABLE
  (
    total        BIGINT,
    percentage   FLOAT,
    gender       VARCHAR,
    address_type VARCHAR
  )
AS
$$
DECLARE
BEGIN
  RETURN QUERY EXECUTE FORMAT('WITH query_output as ( %s ),' ||
                              'denominator_query_output as ( %s ),' ||
                              'aggregates_all as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     alt.name        address_type
                                                   FROM query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided and not g.is_voided
                                                   GROUP BY g.name, alt.name),' ||
                              'denominator_aggregates_all as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     alt.name        address_type
                                                   FROM denominator_query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided and not g.is_voided
                                                   GROUP BY g.name, alt.name),' ||
                              'aggregates_alt as (SELECT
                                                     count(qo.uuid)  total,
                                                     ''Total''::varchar       gender,
                                                     alt.name        address_type
                                                   FROM query_output qo
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided
                                                   GROUP BY alt.name),' ||
                              'denominator_aggregates_alt as (SELECT
                                                     count(qo.uuid)  total,
                                                     ''Total''::varchar       gender,
                                                     alt.name        address_type
                                                   FROM denominator_query_output qo
                                                     right join address_level_type alt on alt.name = qo.address_type
                                                   WHERE not alt.is_voided
                                                   GROUP BY alt.name),' ||
                              'aggregates_gender as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     ''All''::varchar         address_type
                                                   FROM query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                   WHERE not g.is_voided
                                                   GROUP BY g.name),' ||
                              'denominator_aggregates_gender as (SELECT
                                                     count(qo.uuid)  total,
                                                     g.name          gender,
                                                     ''All''::varchar         address_type
                                                   FROM denominator_query_output qo
                                                     right join gender g on g.name = qo.gender_name
                                                   WHERE not g.is_voided
                                                   GROUP BY g.name),' ||
                              'aggregates_none as (SELECT
                                                     count(qo.uuid)    total,
                                                     ''Total''::varchar         gender,
                                                     ''All''::varchar           address_type
                                                   FROM query_output qo),' ||
                              'denominator_aggregates_none as (SELECT
                                                     count(qo.uuid)    total,
                                                     ''Total''::varchar         gender,
                                                     ''All''::varchar           address_type
                                                   FROM denominator_query_output qo),' ||
                              'aggregates as (select * from aggregates_all
                                              union all select * from aggregates_alt
                                              union all select * from aggregates_gender
                                              union all select * from aggregates_none),' ||
                              'denominator_aggregates as (select * from denominator_aggregates_all
                                                          union all select * from denominator_aggregates_alt
                                                          union all select * from denominator_aggregates_gender
                                                          union all select * from denominator_aggregates_none),' ||
                              'aggregates_percentage as (select *,
                                                          (SELECT coalesce(round((( ag2.total :: FLOAT / (CASE dag1.total when 0 then null else dag1.total end) ) * 100) :: NUMERIC, 2), 100)
                                                           FROM aggregates ag2
                                                             INNER JOIN denominator_aggregates dag1
                                                               ON ag2.address_type = dag1.address_type AND ag2.gender = dag1.gender
                                                           WHERE ag2.address_type = ag1.address_type AND ag2.gender = ag1.gender
                                                           LIMIT 1) as percentage from aggregates ag1),' ||
                              'all_data as (select total, percentage, address_type, gender from aggregates_percentage
                                           union all
                                           SELECT 0, 0::float, atname, gname from (
                                                   SELECT DISTINCT type atname,
                                                   name gname
                                                 FROM address_level_type_view, gender
                                                 UNION ALL
                                                 SELECT
                                                   ''All''::varchar atname,
                                                   name gname
                                                 FROM gender
                                                 UNION ALL
                                                 SELECT DISTINCT
                                                   type atname,
                                                   ''Total''::varchar gname
                                                 FROM address_level_type_view
                                                 UNION ALL
                                                 SELECT
                                                   ''All''::varchar atname,
                                                   ''Total''::varchar gname) as agt where (atname, gname) not in (select address_type, gender from aggregates))' ||
                              'select total, percentage, gender, address_type from all_data order by address_type, gender',
                              replace(frequency_query, ';', ''),
                              replace(denominator_query, ';', ''));
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION multi_select_coded(obs JSONB)
  RETURNS VARCHAR LANGUAGE plpgsql
AS $$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    IF JSONB_TYPEOF(obs) = 'array'
    THEN
      SELECT STRING_AGG(C.NAME, ' ,') FROM JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID)
                                             JOIN CONCEPT C ON C.UUID = OB.UUID
        INTO RESULT;
    ELSE
      SELECT SINGLE_SELECT_CODED(obs) INTO RESULT;
    END IF;
    RETURN RESULT;
    EXCEPTION WHEN OTHERS
    THEN
      RAISE NOTICE 'Failed while processing multi_select_coded(''%'')', obs :: TEXT;
      RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  END;
END $$;

CREATE OR REPLACE FUNCTION single_select_coded(obs TEXT)
  RETURNS VARCHAR LANGUAGE plpgsql
AS $$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    SELECT name FROM concept WHERE uuid = obs
      INTO result;
    RETURN result;
  END;
END $$
STABLE;

CREATE OR REPLACE FUNCTION single_select_coded(obs JSONB)
  RETURNS VARCHAR LANGUAGE plpgsql
AS $$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    IF JSONB_TYPEOF(obs) = 'array'
    THEN
      SELECT name FROM concept WHERE (obs->>0) = uuid INTO result;
    ELSEIF JSONB_TYPEOF(obs) = 'string'
      THEN
        select name from concept where (array_to_json(array[obs])->>0) = uuid into result;
    END IF;
    RETURN result;
  END;
END $$
STABLE;

create or replace function single_select_coded(obs jsonb, concept_name text)
  returns varchar
AS 'select single_select_coded($1->>concept_uuid($2));'
LANGUAGE sql
STABLE;

drop function if exists checklist_itemstatus_starting(status jsonb);
CREATE OR REPLACE FUNCTION checklist_itemstatus_starting(status jsonb)
  RETURNS INTERVAL AS $$
DECLARE
  returnValue INTERVAL;
BEGIN
  select (CASE
            WHEN status#>>'{from,day}' NOTNULL
                    THEN status#>>'{from,day}' || ' day'
            WHEN status#>>'{from,week}' NOTNULL
                    THEN status#>>'{from,week}' || ' week'
            WHEN status#>>'{from,month}' NOTNULL
                    THEN status#>>'{from,month}' || ' month'
            WHEN status#>>'{from,year}' NOTNULL
                    THEN status#>>'{from,year}' || ' year' END) :: INTERVAL
    into returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

drop function if exists checklist_itemstatus_ending(status jsonb);
CREATE OR REPLACE FUNCTION checklist_itemstatus_ending(status jsonb)
  RETURNS INTERVAL AS $$
DECLARE
  returnValue INTERVAL;
BEGIN
  select (CASE
            WHEN status#>>'{to,day}' NOTNULL
                    THEN status#>>'{to,day}' || ' day'
            WHEN status#>>'{to,week}' NOTNULL
                    THEN status#>>'{to,week}' || ' week'
            WHEN status#>>'{to,month}' NOTNULL
                    THEN status#>>'{to,month}' || ' month'
            WHEN status#>>'{to,year}' NOTNULL
                    THEN status#>>'{to,year}' || ' year' END) :: INTERVAL
    into returnValue;
  RETURN returnValue;
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

DROP FUNCTION IF EXISTS jsonb_merge(JSONB) CASCADE;

CREATE OR REPLACE FUNCTION jsonb_merge(arr JSONB)
  RETURNS JSONB AS $$
DECLARE merged_jsonb JSONB;
BEGIN
  merged_jsonb := '{}' :: JSONB;
  FOR i IN 0..(jsonb_array_length(arr) - 1)
  LOOP
    merged_jsonb := (merged_jsonb || ((arr ->> i) :: JSONB));
  END LOOP;
  RETURN merged_jsonb;
END
$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS grant_all_on_common_views(text [], text);
CREATE OR REPLACE FUNCTION grant_all_on_common_views(view_names text [], role text)
  RETURNS text AS
$body$
DECLARE
  view_names_string text;
  each              record;
BEGIN
  view_names_string := array_to_string(view_names, ',');
  EXECUTE 'GRANT ALL ON ' || view_names_string || ' TO ' || quote_ident(role) || '';
  RETURN 'ALL PERMISSION GRANTED ON specified views TO ' || quote_ident(role) || '';
END;
$body$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION boolean_txt(BOOLEAN)
  RETURNS TEXT
AS 'SELECT CASE $1 WHEN TRUE THEN ''Yes'' WHEN FALSE THEN ''No'' ELSE NULL END;'
LANGUAGE sql
IMMUTABLE;


create or replace function translated_value(lang text, string text)
  returns character varying
stable
language plpgsql
as
$$
DECLARE
  result varchar;
BEGIN
  select coalesce(translation_json ->> string, string) from translation where language = lang
    into result;
  return result;
END;
$$;


create or replace function translated_single_select_coded(lang text, obs text)
  returns character varying
stable
language plpgsql
as
$$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    SELECT translated_value(lang, name :: text) FROM concept WHERE uuid = obs
      INTO result;
    RETURN result;
  END;
END
$$;

create or replace function translated_single_select_coded(lang text, obs jsonb)
  returns character varying
stable
language plpgsql
as
$$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    IF JSONB_TYPEOF(obs) = 'array'
    THEN
      SELECT translated_value(lang, name :: text) FROM concept WHERE (obs->>0) = uuid INTO result;
    ELSEIF JSONB_TYPEOF(obs) = 'string'
      THEN
        select translated_value(lang, name :: text) from concept where (array_to_json(array[obs])->>0) = uuid into result;
    END IF;
    RETURN result;
  END;
END
$$;

create or replace function translated_multi_select_coded(lang text, obs jsonb)
  returns character varying
language plpgsql
as
$$
DECLARE result VARCHAR;
BEGIN
  BEGIN
    IF JSONB_TYPEOF(obs) = 'array'
    THEN
      SELECT STRING_AGG(translated_value(lang, C.NAME :: text), ' ,')
      FROM JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID)
             JOIN CONCEPT C ON C.UUID = OB.UUID
        INTO RESULT;
    ELSE
      SELECT translated_single_select_coded(lang, obs) INTO RESULT;
    END IF;
    RETURN RESULT;
    EXCEPTION WHEN OTHERS
    THEN
      RAISE NOTICE 'Failed while processing translated_multi_select_coded(''%'')', obs :: TEXT;
      RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  END;
END
$$;

-- Create a concept map which can be used as a cache
create or replace function get_concept_map(concepts text [])
  returns hstore
language plpgsql
stable
as
$$
DECLARE
  result hstore;
BEGIN
  BEGIN
    SELECT hstore((array_agg(c2.uuid)) :: text [], (array_agg(c2.name)) :: text []) AS map into result
    FROM concept
           join concept_answer a on concept.id = a.concept_id
           join concept c2 on a.answer_concept_id = c2.id
    where concept.uuid = any(concepts);
    return result;
    EXCEPTION
    WHEN OTHERS
      THEN
        RAISE NOTICE 'Failed while processing get_concept_map(''%'')', concepts :: TEXT;
        RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  END;
END
$$;

-- Create a translated concept map which can be used as a cache
create or replace function get_translated_concept_map(concepts text [], lang text)
  returns hstore
language plpgsql
stable
as
$$
DECLARE
  result hstore;
BEGIN
  BEGIN
    SELECT hstore((array_agg(c2.uuid)) :: text [], (array_agg(coalesce(translation_json ->> c2.name, c2.name))) :: text []) AS map into result
    FROM concept
           join concept_answer a on concept.id = a.concept_id
           join concept c2 on a.answer_concept_id = c2.id
           join translation on 1 = 1
    where concept.uuid = any(concepts)
      and translation.language = lang;
    return result;
    EXCEPTION
    WHEN OTHERS
      THEN
        RAISE NOTICE 'Failed while processing get_concept_map(''%'')', concepts :: TEXT;
        RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  END;
END
$$;

-- Can be used for translation as well by passing the output of get_translated_concept_map
-- Replaces multi_select_coded, single_select_coded. Also old functions which take concept name, like coded_obs, instead of concept uuid should not be used because they are likely to break if concept name changes - so these replace those as well
-- Utility functions like coded_obs_exists should be handled in the report itself
create or replace function get_coded_string_value(obs jsonb, obs_store hstore)
  returns character varying
language plpgsql
stable
as
$$
DECLARE
  result VARCHAR;
BEGIN
  BEGIN
    IF JSONB_TYPEOF(obs) = 'array'
    THEN
      select STRING_AGG(obs_store -> OB.UUID, ', ') from JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID)
        INTO RESULT;
    ELSE
      SELECT obs_store -> (obs ->> 0) INTO RESULT;
    END IF;
    RETURN RESULT;
    EXCEPTION
    WHEN OTHERS
      THEN
        RAISE NOTICE 'Failed while processing get_coded_string_value(''%'')', obs :: TEXT;
        RAISE NOTICE '% %', SQLERRM, SQLSTATE;
  END;
END
$$;

-- Checks for presence of ANY of the answers. Replacement for coded_obs_contains and one_of_coded_obs_contains. If one_of_coded_obs_contains is really commonly used then we can create a function for it too.
CREATE OR REPLACE FUNCTION does_coded_obs_contains(obs jsonb, obs_store hstore, answers_to_check text [])
  RETURNS BOOLEAN AS $$
DECLARE
  answers         text [];
  answer_to_check text;
  answer          text;
  exists          BOOLEAN := FALSE;
BEGIN
  if JSONB_TYPEOF(obs) = 'array'
  then
    answers := array(select obs_store -> OB.UUID from JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID));
  else
    answers := array(SELECT obs_store -> (obs ->> 0));
  end if;

  foreach answer_to_check IN ARRAY answers_to_check
  loop
    foreach answer IN ARRAY answers
    loop
      if answer = answer_to_check
      then
        return true;
      end if;
    end loop;
  end loop;
  return false;
END;
$$
LANGUAGE plpgsql;

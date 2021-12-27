--Step 22.3.1 of refresh
--Make backup of the concept_relationship_manual table and concept_manual table
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT CURRENT_DATE
        INTO update
        FROM vocabulary
        WHERE vocabulary_id = 'LOINC'
        LIMIT 1;
        EXECUTE format('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update );

    END
$body$;

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT CURRENT_DATE
        INTO update
        FROM vocabulary
        WHERE vocabulary_id = 'LOINC'
        LIMIT 1;
        EXECUTE format('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update );

    END
$body$;

--Drop old backup
--DROP TABLE dev_loinc.concept_relationship_manual_backup_20211130;


--Step 22.3.2 of refresh
--Create loinc_to_map table (source table for refresh)
--Flags show different reasons for refresh
--DROP TABLE loinc_to_map;
CREATE TABLE loinc_to_map AS (
with previous_mappings AS
    (SELECT concept_id_1, c.standard_concept, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS old_maps_to
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1, standard_concept
        ),

     current_mapping AS
         (
        SELECT concept_id_1, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS new_maps_to
        FROM dev_loinc.concept_relationship cr
        JOIN dev_loinc.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1
         )


SELECT DISTINCT
                replace (c.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
                c.concept_name AS       source_concept_name,
                c.concept_code AS       source_concept_code,
                c.concept_class_id AS   source_concept_class_id,
                c.invalid_reason AS     source_invalid_reason,
                c.domain_id AS          source_domain_id,

                NULL::varchar AS relationship_id,

                CASE WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept = 'S'
                    THEN 'Was Standard and don''t have mapping now'

                    WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept != 'S'
                    THEN 'Was non-Standard but mapped and don''t have mapping now'

                WHEN previous_mappings.concept_id_1 IN
                    (SELECT cc.concept_id FROM dev_loinc.concept_relationship_manual crm
                    JOIN devv5.concept c
                    ON crm.concept_code_2 = c.concept_code AND crm.vocabulary_id_2 = c.vocabulary_id
                    JOIN devv5.concept cc
                    ON cc.concept_code = crm.concept_code_1 AND cc.vocabulary_id = 'LOINC'
                    WHERE c.standard_concept IS NULL) THEN 'Mapping changed according to changes in other vocabs'

                --mapping changed
                WHEN previous_mappings.old_maps_to != current_mapping.new_maps_to THEN 'Mapping changed'

                WHEN c.concept_code NOT IN (SELECT concept_code FROM devv5.concept WHERE vocabulary_id = 'LOINC')
                                THEN 'New and not-mapped'
                                ELSE 'Not mapped' END AS flag,
                NULL::int AS target_concept_id,
                NULL::varchar AS target_concept_code,
                NULL::varchar AS target_concept_name,
                NULL::varchar AS target_concept_class_id,
                NULL::varchar AS target_standard_concept,
                NULL::varchar AS target_invalid_reason,
                NULL::varchar AS target_domain_id,
                NULL::varchar AS target_vocabulary_id

FROM dev_loinc.concept c
         LEFT JOIN previous_mappings
                   ON c.concept_id = previous_mappings.concept_id_1
         LEFT JOIN current_mapping
                   ON c.concept_id = current_mapping.concept_id_1
    --new concept_relationship
         LEFT JOIN dev_loinc.concept_relationship cr
                   ON c.concept_id = cr.concept_id_1
                       AND cr.relationship_id IN ('Maps to', 'Maps to value')
                       AND cr.invalid_reason IS NULL

WHERE c.concept_code NOT IN (SELECT source_code
                             FROM loinc_mapped)


--Conditions show options for specific concept classes refreshes
  and cr.concept_id_2 IS NULL
  AND (c.standard_concept IS NULL OR c.invalid_reason = 'D')
  AND c.vocabulary_id = 'LOINC'
  AND c.concept_class_id IN ('Lab Test'
    --,'Survey', 'Answer', 'Clinical Observation' --TODO: postponed for now
    )
--AND c.invalid_reason != 'U'

ORDER BY replace(c.concept_name, 'Deprecated ', ''), c.concept_code)
;

--Step 22.3.4. of refresh
--New and COVID concepts lacking hierarchy (need to be taken to the concept_relationship_manual table)
SELECT * FROM (
SELECT DISTINCT
       replace (long_common_name, 'Deprecated ', '') AS source_concept_name_clean,
       long_common_name AS source_concept_name,
	   loinc AS source_concept_code,
	   'Lab Test' AS source_concept_class_id,
	   NULL as source_invalid_reason,
	'Measurement' AS source_domain_id
FROM vocabulary_pack.GetLoincPrerelease() s

UNION

SELECT DISTINCT
        replace (cs.concept_name, 'Deprecated ', '') AS source_concept_name_clean,
        cs.concept_name AS       source_concept_name,
        cs.concept_code AS       source_concept_code,
        cs.concept_class_id AS   source_concept_class_id,
        cs.invalid_reason AS     source_invalid_reason,
        cs.domain_id AS          source_domain_id

FROM dev_loinc.concept_stage cs
WHERE cs.vocabulary_id = 'LOINC'
    AND cs.concept_name ~* 'SARS-CoV-2|COVID|SARS2|SARS-2'
    AND cs.concept_class_id IN ('Clinical Observation', 'Lab Test')
) as s


WHERE NOT EXISTS (
SELECT
FROM dev_loinc.concept_relationship_manual crm
WHERE s.source_concept_code = crm.concept_code_1
    AND crm.relationship_id = 'Is a'
    AND crm.invalid_reason IS NULL
)
AND NOT EXISTS (SELECT
                FROM dev_loinc.loinc_mapped lm
                WHERE s.source_concept_code = lm.source_code
                AND lm.to_value = 'Is a'
                AND target_concept_id = '0')

ORDER BY replace (s.source_concept_name, 'Deprecated ', ''), s.source_concept_code
;

--restore CRM
--TRUNCATE TABLE dev_loinc.concept_relationship_manual;
--INSERT INTO dev_loinc.concept_relationship_manual;
--SELECT * FROM dev_loinc.concept_relationship_manual_backup_20211130;

--Step 22.3.7. of refresh
--Make backup of loinc_mapped table
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT CURRENT_DATE
        INTO update
        FROM vocabulary
        WHERE vocabulary_id = 'LOINC'
        LIMIT 1;
        EXECUTE format('create table %I as select * from concept_relationship_manual',
                       'loinc_mapped_backup_' || update );

    END
$body$;
--DROP TABLE dev_loinc.loinc_mapped_20211028;

--Step 22.3.8. of refresh
--TRUNCATE TABLE dev_loinc.loinc_mapped;
CREATE TABLE dev_loinc.loinc_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    to_value varchar(50),
    source varchar(50),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);


--Step 22.3.9 of refresh
--Deprecate all mappings that differ from the new version
UPDATE dev_loinc.concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = current_date
WHERE (concept_code_1, concept_code_2, relationship_id, vocabulary_id_2) IN
      (SELECT concept_code_1, concept_code_2, relationship_id, vocabulary_id_2
       FROM concept_relationship_manual crm_old

       WHERE NOT exists(SELECT source_code,
                               target_concept_code,
                               'LOINC',
                               target_vocabulary_id,
                               CASE
                                   WHEN to_value ~* 'value' THEN 'Maps to value'
                                   WHEN to_value ~* 'Is a' THEN 'Is a'
                                   WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                                   ELSE 'Maps to' END
                        FROM dev_loinc.loinc_mapped crm_new
                        WHERE source_code = crm_old.concept_code_1
                          AND target_concept_code = crm_old.concept_code_2
                          AND target_vocabulary_id = crm_old.vocabulary_id_2
                          AND CASE
                                  WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END = crm_old.relationship_id

    )
    AND invalid_reason IS NULL
    )
;

--Step 22.3.10. of refresh
--Insert new mappings + corrected mappings
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'LOINC' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_loinc.loinc_mapped
        WHERE target_concept_id != 0
    )


INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
    (SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_loinc.concept_relationship_manual)
    )
;

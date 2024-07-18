/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Maria Rogozhkina,
* Aliaksei Katyshou, Vlad Korsik,
* Alexander Davydov, Oleg Zhuk,
* Date: 2024
**************************************************************************/

--Update latest_update field to new date
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                pVocabularyName => 'EORTC QLQ',
                pVocabularyDate => (SELECT TO_DATE(TO_CHAR(qs.updatedate, 'YYYY-MM-DD'), 'YYYY-MM-DD')
                                    FROM dev_eortc.eortc_questionnaires qs
                                    WHERE qs.name = 'Core'
                                    ORDER BY TO_DATE(TO_CHAR(qs.updatedate, 'YYYY-MM-DD'), 'YYYY-MM-DD') DESC
                                    LIMIT 1),
                pVocabularyVersion => (SELECT 'EORTC QLQ defined by ' || qs.name || ' version ' ||
                                              TO_CHAR(qs.updatedate, 'YYYY_MM')
                                       FROM dev_eortc.eortc_questionnaires qs
                                       WHERE qs.name = 'Core'
                                       ORDER BY TO_DATE(TO_CHAR(qs.updatedate, 'YYYY-MM-DD'), 'YYYY-MM-DD') DESC
                                       LIMIT 1),
                pVocabularyDevSchema => 'DEV_EORTC'
            );
    END
$_$;

--Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;


--1. CONCEPT_STAGE POPULATION for Questionnaires
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
                domain_id,
                vocabulary_id,
                conept_class_id,
                standard_concept,
                code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT CASE
                          WHEN LENGTH(COALESCE(qs.description, '')) = 0 THEN qs.name
                          ELSE COALESCE(TRIM(REGEXP_REPLACE(qs.description, ' ', ' ',
                                                            'gi')),
                                        TRIM(
                                                REGEXP_REPLACE(
                                                        SPLIT_PART(qs.additionalinfo, '</h3>', 1),
                                                        ' |<h3>', ' ',
                                                        'gi')
                                            )
                              ) END                                                                     AS concept_name,
                      'Measurement'                                                                     AS domain_id,
                      'EORTC QLQ'                                                                       AS vocabulary_id,
                     CASE WHEN qs.type = 'catshort' then 'CAT SHORT' else UPPER(qs.type)    end as     conept_class_id,
                  NULL                                                                              AS standard_concept,
                    qs.id || '-' ||  qs.code                                                         AS code,
                      TO_DATE(TO_CHAR(LEAST(qs.createdate, qs.updatedate), 'YYYY-MM-DD'),
                              'YYYY-MM-DD')                                                             AS valid_start_date,
                      TO_DATE('2099-12-31', 'YYYY-MM-DD')                                               AS valid_end_date,
                      NULL                                                                              AS invalid_reason
      FROM dev_eortc.eortc_questionnaires qs
      where qs.state is NULL -- to prevent Drafts ingestion
      ) AS tab;

--CONCEPT_SYNONYM POPULATION for Questionnaires
INSERT INTO concept_synonym_stage (synonym_name,
                                   synonym_concept_code,
                                   synonym_vocabulary_id,
                                   language_concept_id)
SELECT DISTINCT vocabulary_pack.CutConceptSynonymName(synonym_name) AS synonym_name,
                code,
                vocabulary_id,
                language_concept_id
FROM (SELECT DISTINCT CASE
                          WHEN LENGTH(COALESCE(qs.description, '')) = 0 THEN NULL
                          ELSE qs.name END       AS synonym_name,
                    qs.id || '-' ||  qs.code  AS code,
                      'EORTC QLQ'                AS vocabulary_id,
                      4180186                    AS language_concept_id -- English
      FROM dev_eortc.eortc_questionnaires qs
      where qs.state is NULL
      ) AS TAB
WHERE synonym_name IS NOT NULL
;

--CONCEPT POPULATION with Questions per se
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)

SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT TO_DATE(TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')      AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
             REGEXP_REPLACE(q.wording, '\t', '', 'gi')                                            AS concept_name,

             q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position                      AS concept_code,
             initcap(qi.type)                                                                   AS concept_class_id,
             'EORTC QLQ'                                                                          AS vocabulary_id,
             'Measurement'                                                                        AS domain_id,
             NULL                                                                                 AS standard_concept,
             NULL                                                                                 AS invalid_reason,
             ROW_NUMBER()
             OVER (PARTITION BY wording, q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position ORDER BY TO_DATE(
                     TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;

--CONCEPT POPULATION with Questions classifiers
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)

SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT TO_DATE(TO_CHAR(LEAST(qi.createdate, qi.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')    AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
             qi.description                                                                       AS concept_name,
             qi.code                                                                              AS concept_code,
             initcap(qi.type)                                                                       AS concept_class_id,
             'EORTC QLQ'                                                                          AS vocabulary_id,
             'Measurement'                                                                        AS domain_id,
             'C'                                                                                  AS standard_concept,
             NULL                                                                                 AS invalid_reason,
             ROW_NUMBER() OVER (PARTITION BY qi.description, qi.code ORDER BY TO_DATE(
                     TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;

--CONCEPT POPULATION with Direction
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)

SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT TO_DATE(TO_CHAR(LEAST(qi.createdate, qi.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')      AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                    AS valid_end_date,
             INITCAP(qi.direction)                                                             AS concept_name,
             lower(qi.direction)                                                                    AS concept_code,
             'DIRECTION'                                                                            AS concept_class_id,
             'EORTC QLQ'                                                                            AS vocabulary_id,
             'Meas Value'                                                                           AS domain_id,
             NULL                                                                                   AS standard_concept,
             NULL                                                                                   AS invalid_reason,
             ROW_NUMBER() OVER (PARTITION BY qi.direction ORDER BY TO_DATE(
                     TO_CHAR(LEAST(qi.createdate, qi.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;


--CONCEPT POPULATION with Issue
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name) AS concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT TO_DATE(TO_CHAR(LEAST(qi.createdate, qi.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')      AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                    AS valid_end_date,
             qi.underlyingissue                                                                     AS concept_name,
             'ISS_' || (regexp_match(qi.code,'\d+'))[1]::varchar                                                             AS concept_code,
             'ISSUE'                                                                                AS concept_class_id,
             'EORTC QLQ'                                                                            AS vocabulary_id,
             'Observation'                                                                          AS domain_id,
             NULL                                                                                   AS standard_concept,
             NULL                                                                                   AS invalid_reason,
             ROW_NUMBER() OVER (PARTITION BY qi.underlyingissue, (regexp_match(qi.code,'\d+'))[1]::varchar   ORDER BY TO_DATE(
                     TO_CHAR(LEAST(qi.createdate, qi.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section
      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;


--CONCEPT POPULATION Scales per se
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name_1) AS concept_name,
                domain_id_1,
                vocabulary_id_1,
                concept_class_id_1,
                standard_concept_1,
                concept_code_1,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT TO_DATE(TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'),
                              'YYYY-MM-DD')                                                                AS valid_start_date,
                      NULL                                                                                 AS invalid_reason,
                      TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
                      qi.id || '-' || qs.code || '_' || qi.code                                         AS concept_code_1, -- NB!!!! itemid is used to minimize the N of unnecessary codes
                      q.wording                                                                            AS concept_name_1,
                      NULL                                                                                 AS standard_concept_1,
                      qi.code                                                                              AS concept_code_2,
                      qi.description                                                                       AS concept_name_2,
                      'Is a'                                                                               AS relationship_id,
                      'EORTC QLQ'                                                                          AS vocabulary_id_2,
                      'EORTC QLQ'                                                                          AS vocabulary_id_1,
                      CASE
                          WHEN qi.type = 'symptomScale' THEN 'Measurement'
                          ELSE 'Meas Value' END                                                            AS domain_id_1,
                      CASE
                          WHEN qi.type = 'responseScale'
                              THEN 'RESPONSE SCALE'
                          WHEN qi.type = 'symptomScale'
                              THEN 'SYMPTOM SCALE'
                          WHEN qi.type = 'timeScale'
                              THEN 'TIME SCALE'
                          END                                                                              AS concept_class_id_1,
                      CASE
                          WHEN qi.type = 'symptomScale' THEN 'Measurement'
                          ELSE 'Meas Value' END                                                            AS domain_id_2,
                      qi.type                                                                              AS concept_class_id_2,
                      'C'                                                                                  AS standard_concept_2,
                      ROW_NUMBER() OVER (PARTITION BY qi.id ORDER BY TO_DATE(
                              TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'),
                              'YYYY-MM-DD') ASC)                                                           AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type LIKE '%Scale'
      and qs.state is NULL
      ) AS tab
WHERE rating_in_section = 1
;

--CONCEPT POPULATION Scales Classifiers
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name_2) AS concept_name,
                domain_id_2,
                vocabulary_id_2,
                concept_class_id_2,
                standard_concept_2,
                concept_code_2,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT TO_DATE(TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'),
                              'YYYY-MM-DD')                                                                AS valid_start_date,
                      NULL                                                                                 AS invalid_reason,
                      TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
                      qi.id || '-' || qs.code || '_' || qi.code                                         AS concept_code_1, -- NB!!!! itemid is used to minimize the N of unnecessary codes
                      q.wording                                                                            AS concept_name_1,
                      'C'                                                                                  AS standard_concept_1,
                      qi.code                                                                              AS concept_code_2,
                      qi.description                                                                       AS concept_name_2,
                      'Is a'                                                                               AS relationship_id,
                      'EORTC QLQ'                                                                          AS vocabulary_id_2,
                      'EORTC QLQ'                                                                          AS vocabulary_id_1,
                      CASE
                          WHEN qi.type = 'symptomScale' THEN 'Measurement'
                          ELSE 'Meas Value' END                                                            AS domain_id_1,
                      CASE
                          WHEN qi.type = 'responseScale'
                              THEN 'RESPONSE SCALE'
                          WHEN qi.type = 'symptomScale'
                              THEN 'SYMPTOM SCALE'
                          WHEN qi.type = 'timeScale'
                              THEN 'TIME SCALE'
                          END                                                                              AS concept_class_id_1,
                      CASE
                          WHEN qi.type = 'symptomScale' THEN 'Measurement'
                          ELSE 'Meas Value' END                                                            AS domain_id_2,
                      CASE
                          WHEN qi.type = 'responseScale'
                              THEN 'RESPONSE SCALE'
                          WHEN qi.type = 'symptomScale'
                              THEN 'SYMPTOM SCALE'
                          WHEN qi.type = 'timeScale'
                              THEN 'TIME SCALE'
                          END                                                                              AS concept_class_id_2,
                      'C'                                                                                  AS standard_concept_2,
                      ROW_NUMBER() OVER (PARTITION BY qi.code ORDER BY TO_DATE(
                              TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'),
                              'YYYY-MM-DD') ASC)                                                           AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type LIKE '%Scale') AS tab
WHERE rating_in_section = 1
;

--CONCEPT POPULATION Answer
INSERT INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)

SELECT DISTINCT vocabulary_pack.CutConceptName(concept_name)                            AS concept_name,
                'Meas Value'                                                            AS domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                ans_code_part1 || '_v' || rating_in_section || '-' || answ_pos::varchar AS concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT SPLIT_PART(cs.concept_code, '_', 2)                                                                        AS ans_code_part1,
                      cs.concept_code,
                      NULL                                                                                                                                     AS invalid_reason,
                      CURRENT_DATE                                                                                                                             AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd')                                                                                                          AS valid_end_date,
                      cs.standard_concept,
                      UNNEST(STRING_TO_ARRAY(cs.concept_name, ', '))                                                                                              concept_name,
                      (array_positions(STRING_TO_ARRAY(cs.concept_name, ', '),
                                       UNNEST(STRING_TO_ARRAY(cs.concept_name, ', '))))[1]                                                                     AS answ_pos,
                      'Answer'                                                                                                                                 AS concept_class_id,
                      vocabulary_id,
                      DENSE_RANK()
OVER (PARTITION BY SPLIT_PART(cs.concept_code, '_', 2) ORDER BY LENGTH(cs.concept_name) ASC ,cs.concept_name ASC) AS rating_in_section
      FROM concept_stage cs
      WHERE concept_class_id = 'RESPONSE SCALE'
        AND standard_concept IS NULL) AS table_answ
;

--CONCEPT_RELATIONSHIP POPULATION
--Questions- to Q-classifiers
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT TO_DATE(TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')      AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
             q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position                      AS concept_code_1,

             q.wording                                                                            AS concept_name_1,
             qi.code                                                                              AS concept_code_2,
             qi.description                                                                       AS concept_name_2,
             'Is a'                                                                               AS relationship_id,
             'EORTC QLQ'                                                                          AS vocabulary_id_1,
             'EORTC QLQ'                                                                          AS vocabulary_id_2,
             NULL                                                                                 AS invalid_reason,
             ROW_NUMBER()
             OVER (PARTITION BY wording, q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position ORDER BY TO_DATE(
                     TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;

--CONCEPT_SYNONYM POPULATION
--Questions- as synonyms for Q-classifiers
INSERT INTO concept_synonym_stage       (synonym_concept_code,synonym_name,synonym_vocabulary_id,language_concept_id)

SELECT DISTINCT concept_code_2,
                concept_name_1 as synonym_name,
                vocabulary_id_1,
             4180186 AS language_concept_id -- English
FROM (SELECT TO_DATE(TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD')      AS valid_start_date,
             TO_DATE('2099-12-31', 'YYYY-MM-DD')                                                  AS valid_end_date,
             q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position                      AS concept_code_1,

             q.wording                                                                            AS concept_name_1,
             qi.code                                                                              AS concept_code_2,
             qi.description                                                                       AS concept_name_2,
             'Is a'                                                                               AS relationship_id,
             'EORTC QLQ'                                                                          AS vocabulary_id_1,
             'EORTC QLQ'                                                                          AS vocabulary_id_2,
             NULL                                                                                 AS invalid_reason,
             ROW_NUMBER()
             OVER (PARTITION BY wording, q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position ORDER BY TO_DATE(
                     TO_CHAR(LEAST(q.createdate, q.updatedate), 'YYYY-MM-DD'), 'YYYY-MM-DD') ASC) AS rating_in_section

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
      and qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
WHERE rating_in_section = 1
;

--CONCEPT_RELATIONSHIP POPULATION
--Scale- to Scale-classifiers
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

WITH tab AS (SELECT cs.concept_code                 AS concept_code_1,
                    cs.concept_name                 AS concept_name_1,
                    cs.vocabulary_id                AS vocabulary_id_1,
                    'Is a'                          AS relationship_id,
                    NULL                            AS invalid_reason,
                    CURRENT_DATE                    AS valid_start_date,
                    TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                    cs2.concept_code                AS concept_code_2,
                    cs2.concept_name                AS concept_name_2,
                    cs2.vocabulary_id               AS vocabulary_id_2

             FROM concept_stage cs
                      JOIN concept_stage cs2
                           ON SPLIT_PART(cs.concept_code, '_', 2) = cs2.concept_code
             WHERE cs.concept_class_id LIKE '%SCALE'
               AND cs.standard_concept IS NULL

               AND cs2.concept_class_id LIKE '%SCALE'
               AND cs2.standard_concept = 'C')
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM tab
ORDER BY concept_code_2, relationship_id, concept_code_1
;

--CONCEPT_RELATIONSHIP POPULATION
--RespScale + Answer
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT concept_code                                                            AS concept_code_1,
                      concept_name_1,
                      vocabulary_id                                                           AS vocabulary_id_1,
                      'Has Answer'                                                            AS relationship_id,
                      NULL                                                                    AS invalid_reason,
                      CURRENT_DATE                                                            AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd')                                         AS valid_end_date,
                      vocabulary_pack.CutConceptName(concept_name)                            AS concept_name_2,
                      vocabulary_id                                                           AS vocabulary_id_2,
                      ans_code_part1 || '_v' || rating_in_section || '-' || answ_pos::varchar AS concept_code_2
      FROM (SELECT SPLIT_PART(cs.concept_code, '_', 2)                                                                         AS ans_code_part1,
                   cs.concept_code,
                   cs.concept_name                                                                                                                          AS concept_name_1,
                   cs.valid_start_date,
                   cs.valid_end_date,
                   cs.invalid_reason,
                   cs.standard_concept,
                   UNNEST(STRING_TO_ARRAY(cs.concept_name, ', '))                                                                                           AS concept_name,
                   (array_positions(STRING_TO_ARRAY(cs.concept_name, ', '),
                                    UNNEST(STRING_TO_ARRAY(cs.concept_name, ', '))))[1]                                                                     AS answ_pos,
                   'Answer'                                                                                                                                 AS concept_class_id,
                   vocabulary_id,
                   DENSE_RANK()
                  OVER (PARTITION BY SPLIT_PART(cs.concept_code, '_', 2) ORDER BY LENGTH(cs.concept_name) ASC ,cs.concept_name ASC)  AS rating_in_section

            FROM concept_stage cs
            WHERE concept_class_id = 'RESPONSE SCALE'
              AND standard_concept IS NULL) AS table_answ) AS responses_rel_tab
;

--CONCEPT_RELATIONSHIP POPULATION
--questionnaire to its scale
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT cs.concept_name                 AS concept_name_1,
             cs.concept_code                 AS concept_code_1,
             cs.vocabulary_id                AS vocabulary_id_1,
          CASE WHEN lower(qi.type) = 'symptomscale' then 'Subsumes' else 'Has Scale'       end              AS relationship_id,
             NULL                            AS invalid_reason,
             CURRENT_DATE                    AS valid_start_date,
             TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
             cs1.concept_name                AS concept_name_2,
             cs1.concept_code                AS concept_code_2,
             cs1.vocabulary_id               AS vocabulary_id_2
      FROM concept_stage cs
               JOIN dev_eortc.eortc_questionnaires qs
                    ON qs.id = SPLIT_PART(cs.concept_code, '-', 1)::int

               JOIN dev_eortc.eortc_questions q ON
          qs.id = q.questionnaire_id
               JOIN dev_eortc.eortc_question_items qi ON q.id = qi.question_id
          AND qi.type LIKE '%Scale'
               LEFT JOIN concept_stage cs1
                         ON cs1.concept_code = qi.id || '-' || qs.code || '_' || qi.code::varchar
                             AND SPLIT_PART(cs.concept_code, '-', 2) = qs.code
      WHERE cs1.concept_class_id LIKE '%SCALE'
        and qs.state is NULL
        AND cs.concept_class_id IN (
                                    'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CAT SHORT',
                                    'PREVIOUS')) --filer questionnaire
         AS q_to_sc_tab
;

--CONCEPT_RELATIONSHIP POPULATION
--Qr to tru-Q
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

WITH tab AS (SELECT cs.concept_name            AS concept_name_1,
                    cs.concept_code            AS concept_code_1,
                    cs.vocabulary_id           AS vocabulary_id_1,
                    cs1.concept_name           AS concept_name_2,
                    cs1.concept_code           AS concept_code_2,
                    cs1.vocabulary_id          AS vocabulary_id_2,
                    'Subsumes'                                                            AS relationship_id,
                      NULL                                                                    AS invalid_reason,
                      CURRENT_DATE                                                            AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd')                                         AS valid_end_date
             FROM concept_stage cs
                      JOIN dev_eortc.eortc_questionnaires qs
                           ON qs.id = SPLIT_PART(cs.concept_code, '-', 1)::int

                      JOIN dev_eortc.eortc_questions q ON
                 qs.id = q.questionnaire_id
                      JOIN dev_eortc.eortc_question_items qi ON q.id = qi.question_id
                      JOIN concept_stage cs1 ON q.id  || '-'|| qs.code  || '_' || qi.codeprefix || q.position     = cs1.concept_code
            WHERE qs.state is NULL
               AND cs.concept_class_id IN (
                                           'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CAT SHORT',
                                           'PREVIOUS') --filer questionnaire
)
SELECT DISTINCT concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason
FROM tab
;


--CONCEPT_RELATIONSHIP POPULATION
--question to SymScale
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

WITH tab AS (SELECT cs.concept_name            AS concept_name_qr,
                    cs.concept_code            AS concept_code_qr,
                    cs.vocabulary_id           AS vocabulary_id_qr,
                    cs1.concept_name           AS concept_name_2,
                    cs1.concept_code           AS concept_code_2,
                    cs1.vocabulary_id          AS vocabulary_id_2,
                    UNNEST(q.relatedquestions) AS r_qn_id
             FROM concept_stage cs
                      JOIN dev_eortc.eortc_questionnaires qs
                           ON qs.id = SPLIT_PART(cs.concept_code, '-', 1)::int

                      JOIN dev_eortc.eortc_questions q ON
                 qs.id = q.questionnaire_id
                      JOIN dev_eortc.eortc_question_items qi ON q.id = qi.question_id
                 AND qi.type ILIKE 'symptomscale'
                      LEFT JOIN concept_stage cs1
                                ON cs1.concept_code = qi.id || '-' || qs.code || '_' || qi.code::varchar
                                    AND SPLIT_PART(cs.concept_code, '-', 2) = qs.code
             WHERE cs1.concept_class_id = 'SYMPTOM SCALE'
               AND qs.state is NULL
               AND cs.concept_class_id IN (
                                           'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CAT SHORT',
                                           'PREVIOUS') --filer questionnaire
)
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT cs2.concept_name                AS concept_name_1,
             cs2.concept_code                AS concept_code_1,
             cs2.vocabulary_id               AS vocabulary_id_1,
             'Is a'                          AS relationship_id,
             NULL                            AS invalid_reason,
             CURRENT_DATE                    AS valid_start_date,
             TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
             concept_name_2,
             concept_code_2,
             vocabulary_id_2
      FROM tab a
      JOIN concept_stage cs2
                    ON SPLIT_PART(cs2.concept_code, '-', 1)::int = r_qn_id
                        AND cs2.concept_class_id = 'Question'
                        AND cs2.standard_concept IS NULL
       AND  SPLIT_PART(SPLIT_PART(cs2.concept_code, '-', 2), '_', 1) = SPLIT_PART(SPLIT_PART(a.concept_code_2, '-', 2), '_', 1)
      )AS q_to_ss
;




--CONCEPT_RELATIONSHIP POPULATION
--question to Other Scales
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

WITH tab AS (SELECT cs.concept_name            AS concept_name_qr,
                    cs.concept_code            AS concept_code_qr,
                    cs.vocabulary_id           AS vocabulary_id_qr,
                    cs1.concept_name           AS concept_name_2,
                    cs1.concept_code           AS concept_code_2,
                    cs1.vocabulary_id          AS vocabulary_id_2,
                    UNNEST(q.relatedquestions) AS r_qn_id
             FROM concept_stage cs
                      JOIN dev_eortc.eortc_questionnaires qs
                           ON qs.id = SPLIT_PART(cs.concept_code, '-', 1)::int

                      JOIN dev_eortc.eortc_questions q ON
                 qs.id = q.questionnaire_id
                      JOIN dev_eortc.eortc_question_items qi ON q.id = qi.question_id
                 AND qi.type NOT ILIKE 'symptomscale'
                      LEFT JOIN concept_stage cs1
                                ON cs1.concept_code = qi.id || '-' || qs.code || '_' || qi.code::varchar
                                    AND SPLIT_PART(cs.concept_code, '-', 2) = qs.code
             WHERE cs1.concept_class_id != 'SYMPTOM SCALE'
               AND  qs.state is NULL
               AND cs.concept_class_id IN (
                                           'CORE', 'MODULE', 'STANDALONE', 'CAT', 'CAT SHORT',
                                           'PREVIOUS') --filer questionnaire
)
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT cs2.concept_name                AS concept_name_1,
             cs2.concept_code                AS concept_code_1,
             cs2.vocabulary_id               AS vocabulary_id_1,
             'Has Scale'                     AS relationship_id,
             NULL                            AS invalid_reason,
             CURRENT_DATE                    AS valid_start_date,
             TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
             concept_name_2,
             concept_code_2,
             vocabulary_id_2
      FROM tab a
               JOIN concept_stage cs2
                    ON SPLIT_PART(cs2.concept_code, '-', 1)::int = r_qn_id
                        AND cs2.concept_class_id = 'Question'
                        AND cs2.standard_concept IS NULL
                         AND  SPLIT_PART(SPLIT_PART(cs2.concept_code, '-', 2), '_', 1) = SPLIT_PART(SPLIT_PART(a.concept_code_2, '-', 2), '_', 1)
      ) AS q_to_otherSc
;

--CONCEPT_RELATIONSHIP POPULATION
--Question to Answer
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT cs.concept_name                 AS concept_name_1,
                      cs.vocabulary_id                AS vocabulary_id_1,
                      cs.concept_code                 AS concept_code_1,
                      'Has Answer'                    AS relationship_id,
                      NULL                            AS invalid_reason,
                      CURRENT_DATE                    AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                      cs2.concept_name                AS concept_name_2,
                      cs2.vocabulary_id               AS vocabulary_id_2,
                      cs2.concept_code                AS concept_code_2
      FROM concept_stage cs
               JOIN concept_relationship_stage crs
                    ON cs.concept_code = crs.concept_code_1
                        AND cs.vocabulary_id = crs.vocabulary_id_1
                        AND cs.concept_class_id = 'Question'
               JOIN concept_stage csi
                    ON csi.concept_code = crs.concept_code_2
                        AND csi.vocabulary_id = crs.vocabulary_id_2
                        AND csi.concept_class_id = 'RESPONSE SCALE'
               JOIN concept_relationship_stage crsi
                    ON crsi.concept_code_1 = csi.concept_code
                        AND csi.vocabulary_id = crsi.vocabulary_id_1

               JOIN concept_stage cs2
                    ON crsi.concept_code_2 = cs2.concept_code
                        AND cs2.vocabulary_id = crsi.vocabulary_id_2
                        AND cs2.concept_class_id = 'Answer'
      ) AS q_to_answer
;


--CONCEPT RELATIONSHIP POPULATION
-- Issue to class-Q
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (
SELECT DISTINCT concept_name_1,
                concept_code_1,
                'Issue of' as relationship_id,
                concept_code_2,
                concept_name_2,
                vocabulary_id AS vocabulary_id_1,
                vocabulary_id AS vocabulary_id_2,
                NULL                                                                                                                                     AS invalid_reason,
                      CURRENT_DATE                                                                                                                             AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd')                                                                                                          AS valid_end_date
FROM (SELECT DISTINCT
             qi.underlyingissue                                                                     AS concept_name_1,
             'ISS_' || (regexp_match(qi.code,'\d+'))[1]::varchar                                    AS concept_code_1,
               qi.code                                                                              AS concept_code_2,
              qi.description                                                                        AS concept_name_2,
             'EORTC QLQ'                                                                            AS vocabulary_id
      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
              AND  qs.state is NULL
) AS tab) as cq_to_is
;

--CONCEPT RELATIONSHIP POPULATION
-- Issue to true-Q
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,

                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT cs2.concept_name                AS concept_name_1,
                      cs2.vocabulary_id               AS vocabulary_id_1,
                      cs2.concept_code                AS concept_code_1,
                      'Issue of'                    AS relationship_id,
                      NULL                            AS invalid_reason,
                      CURRENT_DATE                    AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,


                      cs.concept_name                 AS concept_name_2,
                      cs.vocabulary_id                AS vocabulary_id_2,
                      cs.concept_code                 AS concept_code_2
      FROM concept_stage cs
               JOIN concept_relationship_stage crs
                    ON cs.concept_code = crs.concept_code_1
                        AND cs.vocabulary_id = crs.vocabulary_id_1
                        AND cs.concept_class_id = 'Question'
                        AND cs.standard_concept is null
               JOIN concept_stage csi
                    ON csi.concept_code = crs.concept_code_2
                        AND csi.vocabulary_id = crs.vocabulary_id_2
                        AND csi.concept_class_id = 'Question'
              and csi.standard_concept ='C'
               JOIN concept_relationship_stage crsi
                    ON crsi.concept_code_2 = csi.concept_code
                        AND csi.vocabulary_id = crsi.vocabulary_id_1

               JOIN concept_stage cs2
                    ON crsi.concept_code_1 = cs2.concept_code
                        AND cs2.vocabulary_id = crsi.vocabulary_id_2
                        AND cs2.concept_class_id = 'ISSUE'
      ) AS q_to_issue
;


--CONCEPT_RELATIONSHIP POPULATION
--Direction- to Q-classifiers
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (      SELECT
           lower(qi.direction)                      AS concept_code_1,
             qi.direction                                                                                      AS concept_name_1,
             qi.code                                                                              AS concept_code_2,
             qi.description                                                                       AS concept_name_2,
             'Direction of'                                                                               AS relationship_id,
             NULL                            AS invalid_reason,
                      CURRENT_DATE                    AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                      'EORTC QLQ' as vocabulary_id_1,
                      'EORTC QLQ' as vocabulary_id_2

      FROM dev_eortc.eortc_questionnaires qs
               LEFT JOIN dev_eortc.eortc_questions q
                         ON qs.id = q.questionnaire_id
               LEFT JOIN dev_eortc.eortc_question_items qi
                         ON q.id = qi.question_id
      WHERE qi.type = 'question'
              AND  qs.state is NULL
      ORDER BY qs.code, qi.codeprefix, q.position::int) AS tab
;


--Direction- to true-Q
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)

SELECT DISTINCT concept_code_1,
                concept_code_2,
                vocabulary_id_1,
                vocabulary_id_2,
                relationship_id,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM (SELECT DISTINCT cs2.concept_name                AS concept_name_1,
                      cs2.vocabulary_id               AS vocabulary_id_1,
                      cs2.concept_code                AS concept_code_1,
                      'Direction of'                    AS relationship_id,
                      NULL                            AS invalid_reason,
                      CURRENT_DATE                    AS valid_start_date,
                      TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,


                      cs.concept_name                 AS concept_name_2,
                      cs.vocabulary_id                AS vocabulary_id_2,
                      cs.concept_code                 AS concept_code_2
      FROM concept_stage cs
               JOIN concept_relationship_stage crs
                    ON cs.concept_code = crs.concept_code_1
                        AND cs.vocabulary_id = crs.vocabulary_id_1
                        AND cs.concept_class_id = 'Question'
                        AND cs.standard_concept is null
               JOIN concept_stage csi
                    ON csi.concept_code = crs.concept_code_2
                        AND csi.vocabulary_id = crs.vocabulary_id_2
                        AND csi.concept_class_id = 'Question'
              and csi.standard_concept ='C'
               JOIN concept_relationship_stage crsi
                    ON crsi.concept_code_2 = csi.concept_code
                        AND csi.vocabulary_id = crsi.vocabulary_id_1

               JOIN concept_stage cs2
                    ON crsi.concept_code_1 = cs2.concept_code
                        AND cs2.vocabulary_id = crsi.vocabulary_id_2
                        AND cs2.concept_class_id = 'DIRECTION'
      ) AS q_to_issue
;

--Stages should be OK
SELECT *
FROM qa_tests.check_stage_tables();
--Stages are OK


-- Working with concept_manual table
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.ProcessManualConcepts();
    END
$_$;

--Working with replacement mappings
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.CheckReplacementMappings();
    END
$_$;

--Add mapping from deprecated to fresh concepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
    END
$_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
    END
$_$;

--Add mapping from deprecated to fresh concepts for 'Maps to value'
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
    END
$_$;


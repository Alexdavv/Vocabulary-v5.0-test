--СDE source insertion
DROP TABLE dev_icd10.icd_cde_source;
TRUNCATE TABLE dev_icd10.icd_cde_source;
CREATE TABLE dev_icd10.icd_cde_source
(
    source_code             TEXT NOT NULL,
    source_code_description varchar(255),
    source_vocabulary_id    varchar(20),
    group_name              varchar(255),
    group_id                INT4 GENERATED BY DEFAULT AS IDENTITY (SEQUENCE NAME seq_icd_cde_source),
    --group_code              varchar, -- group code is dynamic and is assembled after grouping just before insertion data into the google sheet
    medium_group_id         integer,
    --medium_group_code       varchar,
    broad_group_id          integer,
    --broad_group_code        varchar,
    relationship_id         varchar(20),
    target_concept_id       integer,
    target_concept_code     varchar(50),
    target_concept_name     varchar (255),
    target_concept_class_id varchar(20),
    target_standard_concept varchar(1),
    target_invalid_reason   varchar(1),
    target_domain_id        varchar(20),
    target_vocabulary_id    varchar(20),
    mappings_origin         varchar
);

-- Run load_stage for every Vocabulary to be included into the CDE
-- Insert the whole source with existing mappings into the CDE. We want to preserve mappings to non-S or non valid concepts at this stage.
-- Concepts, that are not supposed to have mappings are not included
-- If there are several mapping sources all the versions should be included, excluding duplicates within one vocabulary. --Ask Mikita
-- Mapping duplicates between vocabularies are preserved

--ICD10 with mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            medium_group_id,
                            broad_group_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
-- Check Select before insertion --18046 S valid, 34947 non-S valid, --35397 non-S not valid
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD10'             as source_vocabulary_id,
       null                as group_name,
       null                as medium_group_id,
       null                as broad_group_id,
       crs.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crs.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id,
       CASE WHEN c.concept_id is not null THEN 'crs' ELSE null END as mappings_origin
FROM dev_icd10.concept_stage cs
LEFT JOIN dev_icd10.concept_relationship_stage crs
    on cs.concept_code = crs.concept_code_1
    and crs.relationship_id in ('Maps to', 'Maps to value')
    --and crs.invalid_reason is null -- we want to have D relationships in the CDE
LEFT JOIN concept c
    on crs.concept_code_2 = c.concept_code
    and crs.vocabulary_id_2 = c.vocabulary_id
    --and c.standard_concept = 'S' -- to preserve mappings to non-S, not valid concepts
    --and c.invalid_reason is null
where cs.concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy')
;

--ICD10CM with mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            medium_group_id,
                            broad_group_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
-- Check Select before insertion --135145 S valid, 263603 non-S valid, 266773 non-S not-valid
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD10CM'           as source_vocabulary_id,
       null                as group_name,
       null                as medium_group_id,
       null                as broad_group_id,
       crs.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crs.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id,
       CASE WHEN c.concept_id is not null THEN 'crs' ELSE null END as mappings_origin
FROM dev_icd10cm.concept_stage cs
LEFT JOIN dev_icd10cm.concept_relationship_stage crs
    on cs.concept_code = crs.concept_code_1
    and relationship_id in ('Maps to', 'Maps to value')
    -- and crs.invalid_reason is null -- we want to have D relationships in the CDE
LEFT JOIN concept c
    on crs.concept_code_2 = c.concept_code
    and crs.vocabulary_id_2 = c.vocabulary_id
    --and c.standard_concept = 'S'
    --and c.invalid_reason is null
    ;

--check all the inserted rows --152026
SELECT * FROM icd_cde_source
ORDER BY source_code;

--Check for null values in source_code, source_code_description, source_vocabulary_id fields
SELECT * FROM icd_cde_source
    WHERE source_code is null
    OR source_code_description is null
    or source_vocabulary_id is null;

--potential replacement mapping insertion for concepts, which do not have standard target
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
with mis_map as
(SELECT DISTINCT * FROM icd_cde_source
WHERE target_concept_id is not null
AND target_standard_concept is null) -- 3534
       SELECT DISTINCT m.source_code,
              m.source_code_description,
              m.source_vocabulary_id,
              cr.relationship_id,
              c.concept_id as target_concept_id,
              c.concept_code as target_concept_code,
              c.concept_name as target_concept_name,
              c.concept_class_id as target_concept_class_id,
              c.standard_concept as target_standard_concept,
              c.invalid_reason as target_invalid_reason,
              c.domain_id as target_domain_id,
              c.vocabulary_id as target_vocabulary_id,
              'replaced through relationships' as mapping_origin
       FROM mis_map m JOIN concept_relationship cr
       ON m.target_concept_id = cr.concept_id_1
       JOIN concept c
       ON cr.concept_id_2 = c.concept_id
       AND cr.relationship_id in ('Maps to', 'Maps to value', 'Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
       AND c.standard_concept = 'S'
       AND c.invalid_reason is null
       AND (m.source_code, c.concept_id) NOT IN (SELECT source_code, target_concept_id FROM icd_cde_source) ;

-- to review all soure_codes with mappings, including potential replacement mappings
SELECT * FROM icd_cde_source
ORDER BY source_code;

--strict group (identical source_code_description and same codes with identical mappings)
DROP TABLE grouped;
CREATE TABLE grouped as (
SELECT DISTINCT
       c1.source_code as source_code,
       c1.source_code_description as source_code_description,
       c1.source_vocabulary_id as source_vocabulary_id,
       c.source_code as source_code_1,
       c.source_code_description as source_code_description_1,
       c.source_vocabulary_id as source_vocabulary_id_1
FROM dev_icd10.icd_cde_source c
    JOIN dev_icd10.icd_cde_source c1
    ON c.source_code_description = c1.source_code_description
    and c1.source_vocabulary_id = 'ICD10');

--Deduplication
DELETE FROM grouped WHERE (source_code, source_vocabulary_id) = (source_code_1, source_vocabulary_id_1);
SELECT * FROM grouped;
--Remove "cross-links"
--! These records should be processed very accurately
--Only one entry per entity is allowed
DROP TABLE IF EXISTS excluded_records;
CREATE TABLE excluded_records AS
SELECT * FROM grouped g
    WHERE exists(
        select 1 from grouped g1
                 where (g1.source_code_1, g1.source_vocabulary_id_1) = (g.source_code, g.source_vocabulary_id)
                 and (g1.source_code, g1.source_vocabulary_id) = (g1.source_code, g1.source_vocabulary_id)
    );

DELETE FROM grouped g
    WHERE exists(
        SELECT 1 FROM grouped g1
                 WHERE (g1.source_code_1, g1.source_vocabulary_id_1) = (g.source_code, g.source_vocabulary_id)
                 AND (g1.source_code, g1.source_vocabulary_id) = (g1.source_code, g1.source_vocabulary_id)
    );

--Source table must be in this format (may contain extra fields) according to the documentation
DROP TABLE IF EXISTS cde_manual_group;
CREATE TABLE cde_manual_group (
	source_code TEXT NOT NULL,
	source_code_description TEXT,
	source_vocabulary_id TEXT NOT NULL,
	group_id INT4 GENERATED BY DEFAULT AS IDENTITY (SEQUENCE NAME seq_cde_manual_group),
	group_name TEXT NOT NULL,
	target_concept_id INT4
);

CREATE UNIQUE INDEX idx_pk_cde_manual_group ON cde_manual_group ((source_code || ':' || source_vocabulary_id));
CREATE INDEX idx_cde_manual_group_gid ON cde_manual_group (group_id);

INSERT INTO cde_manual_group (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT source_code, source_code_description, source_vocabulary_id, source_code_description
    FROM grouped;

INSERT INTO cde_manual_group (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT source_code_1, source_code_description_1, source_vocabulary_id_1, source_code_description_1
    FROM grouped
WHERE (source_code_1, source_vocabulary_id_1) NOT IN (SELECT source_code, source_vocabulary_id FROM cde_manual_group)
;

DO $$
DECLARE
r RECORD;
BEGIN
FOR r IN SELECT DISTINCT source_code, source_vocabulary_id, source_code_1, source_vocabulary_id_1 FROM grouped  LOOP
PERFORM cde_groups.MergeSeparateConcepts('cde_manual_group', ARRAY[concat(r.source_code, ':', r.source_vocabulary_id), concat(r.source_code_1, ':', r.source_vocabulary_id_1)]);
END LOOP;
END $$;

--Result
SELECT * FROM cde_manual_group
WHERE group_id IN
(SELECT group_id
FROM cde_manual_group
GROUP BY group_id
HAVING count(source_code) > 1)
ORDER BY group_id
;


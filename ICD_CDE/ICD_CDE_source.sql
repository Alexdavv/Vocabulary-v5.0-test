--СDE source insertion
DROP TABLE dev_icd10.icd_cde_source;
TRUNCATE TABLE dev_icd10.icd_cde_source;
CREATE TABLE dev_icd10.icd_cde_source
(
    source_code             varchar(50),
    source_code_description varchar(255),
    source_vocabulary_id    varchar(20),
    group_name              varchar(255),
    group_id                SERIAL PRIMARY KEY ,
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
                            target_vocabulary_id)
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
       crs.vocabulary_id_2 as target_vocabulary_id
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
                            target_vocabulary_id)
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
       crs.vocabulary_id_2 as target_vocabulary_id
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

--potential replacement mapping insertion
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
(SELECT * FROM icd_cde_source
WHERE target_concept_id is not null
AND target_standard_concept is null) -- 3719
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
       AND cr.relationship_id in ('Maps to', 'Maps to value', 'Concept replaced by') -- add other rel_id
       AND c.standard_concept = 'S'
       AND c.invalid_reason is null;

--strict group (identical source_code_description and same codes with identical mappings)
DROP TABLE grouped;
CREATE TABLE grouped as (
SELECT c.source_code as source_code_1,
       c.source_code_description as source_code_description_1,
       c.source_vocabulary_id as source_vocabulary_1,
       c.group_id as group_id_1,
       c1.source_code as source_code,
       c1.source_code_description as source_code_description,
       c1.source_vocabulary_id as source_vocabulary_id,
       c1.group_id as group_id,
       c1.source_code_description as group_name
FROM dev_icd10.icd_cde_source c
    JOIN dev_icd10.icd_cde_source c1
    ON c.source_code_description = c1.source_code_description
    and c.source_vocabulary_id = 'ICD10');

SELECT * FROM grouped;

do $$
declare
r record;
begin
for r in select source_code, source_code_description, source_vocabulary_id, group_id, group_id_1, group_name from grouped where group_id_1 != group_id loop
perform cde_groups.MergeGroupsByGroupID ('grouped', r.group_id_1::int, r.group_id ::int);
end loop;
end $$;




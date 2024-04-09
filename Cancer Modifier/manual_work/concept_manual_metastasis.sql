--The file emulates stage tables creation only and used to populate the Manual tables

--TRUNCATE STAGE TABLES
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
--TRUNCATE STAGE TABLES
TRUNCATE TABLE concept_manual;
TRUNCATE TABLE concept_relationship_manual;

--3.0.2 CS Insert of 'S' CM Metastasis
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
SELECT distinct
                c.concept_id,
                c.concept_name,
                c.domain_id,
                c.vocabulary_id,
                c.concept_class_id,
                c.standard_concept,
                c.concept_code,
                c.valid_start_date,
                c.valid_end_date,
                c.invalid_reason
FROM concept c
where vocabulary_id='Cancer Modifier'
and  concept_class_id = 'Metastasis'
and standard_concept='S'
and (concept_code,vocabulary_id) NOT IN (SELECT concept_code,vocabulary_id from concept_stage)

UNION ALL
--New concepts
SELECT distinct
       null::int as         concept_id,
    'Metastasis to meninges'   as        concept_name,
          'Measurement'   as   domain_id,
            'Cancer Modifier'    as vocabulary_id,
            'Metastasis'   as  concept_class_id,
                'S' as standard_concept,
       'OMOP5117515'         concept_code,
             CURRENT_DATE as    valid_start_date,
            TO_DATE('20991231', 'yyyymmdd')  as    valid_end_date,
            null as    invalid_reason

UNION ALL

SELECT distinct
       null::int as         concept_id,
    'Metastasis to abdomen'   as        concept_name,
          'Measurement'   as   domain_id,
            'Cancer Modifier'    as vocabulary_id,
            'Metastasis'   as  concept_class_id,
                'S' as standard_concept,
       'OMOP5117516'         concept_code,
             CURRENT_DATE as    valid_start_date,
            TO_DATE('20991231', 'yyyymmdd')  as    valid_end_date,
            null as    invalid_reason
;



--4.1.1 Update of validity,valid_end_date,Stadardness of Non-cancerous concepts
UPDATE concept_stage
    SET invalid_reason ='D',
            standard_concept = NULL,
            valid_end_date = CURRENT_DATE
    where concept_id IN (
                         36769170, --Non-Malignant Ascites Maps to 200528	389026000	Ascites
                         36769789, --	Non-malignant Pleural Effusion Maps to 254061	60046008	Pleural effusion
                         36769415, --Pleural Effusion Maps to 254061	60046008	Pleural effusion
                         36768514, -- 	Suspicious Ascites Maps to 200528	389026000	Ascites
                         36768818--	Ascites Maps to 200528	389026000	Ascites
        );


--4.3.1 Update of validity,valid_end_date,Stadardness of Updated CM concepts
UPDATE concept_stage
    SET invalid_reason ='U',
            standard_concept = NULL,
            valid_end_date = CURRENT_DATE
    where concept_id IN (
      35225652, --Metastasis to the Mammary Gland maps to 35225556 Metastasis to the Breast
                                          36768964,--	Distant Metastasis Maps TO 36769180 Metastasis
                                          35226153,	--  Metastasis to the Genital Organs Maps to 35226152	Metastasis to the Genital Organs
                                          35226309--Metastasis to the Unknown Site Maps TO 36769180 Metastasis
        );


--4.5 Update of names
UPDATE concept_stage
SET concept_name =     substr(upper(regexp_replace(concept_name,'Metastasis to the','Metastasis to','gi')),1,1)|| substr(lower(regexp_replace(concept_name,'Metastasis to the','Metastasis to','gi')),2)
where standard_concept='S';


--manual fix of lung lobes
     UPDATE concept_stage
       SET concept_name = 'Metastasis to contralateral lobe of lung',
       standard_concept = 'S',
       valid_end_date = to_DATE ('2099-12-31', 'yyyy-MM-dd'),
       invalid_reason = NULL
WHERE vocabulary_id = 'Cancer Modifier'
AND   concept_code = 'OMOP4999769';

--manual fix of lung lobes
UPDATE concept_stage
   SET concept_name = 'Metastasis to same lobe of lung'
WHERE vocabulary_id = 'Cancer Modifier'
AND   concept_code = 'OMOP4997758';

--manual fix of lung lobes
UPDATE concept_stage
   SET concept_name = 'Metastasis to a different ipsilateral lobe of lung'
WHERE vocabulary_id = 'Cancer Modifier'
AND   concept_code = 'OMOP4997846';



--5.1 CRS insert of Anatomic Sites
INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)
SELECT distinct
                cs.concept_id as concept_id_1,
                cs.concept_code as concept_concept_code_1,
                cs.vocabulary_id as concept_vocabulary_id_1,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2,
                 'Has finding site' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM concept_stage cs
JOIN concept_relationship cr on cs.concept_id = cr.concept_id_1
JOIN concept c
on cr.concept_id_2=c.concept_id
and c.vocabulary_id='SNOMED'
JOIN concept_relationship cr2 on c.concept_id = cr2.concept_id_1
JOIN concept c2
on c2.concept_id=cr2.concept_id_2
and c2.concept_class_id= 'Body Structure'
and cr2.invalid_reason is null
AND    (                            cs.concept_code,
                                        cs.vocabulary_id ,
                                         c2.concept_code ,
                                         c2.vocabulary_id,
                                         'Has finding site' ) NOT IN
       (SELECT concept_code_1,vocabulary_id_1,concept_code_2, vocabulary_id_2,concept_relationship_stage.relationship_id from concept_relationship_stage

        )
AND c2.standard_concept='S'

;


--5.2.1 FUNCTION USED TO order the elements of array
CREATE OR REPLACE FUNCTION array_sort_unique (ANYARRAY) RETURNS ANYARRAY
LANGUAGE SQL
AS $body$
  SELECT ARRAY(
    SELECT DISTINCT $1[s.i]
    FROM generate_series(array_lower($1,1), array_upper($1,1)) AS s(i)
    ORDER BY 1
  );
$body$;

--5.2.2 Manual Topography resuscitation
with snomed_bs as (
    SELECT
           array_sort_unique(string_to_array( lower(tab.concept_name)||' structure of'|| ' part of',' ')) as array_name_snomed,
           concept_id,
           concept_name,
           domain_id,
           vocabulary_id,
           concept_class_id,
           standard_concept,
           concept_code,
           valid_start_date,
           valid_end_date,
           invalid_reason
    FROM (SELECT  concept_id,
           concept_name,
           domain_id,
           vocabulary_id,
           concept_class_id,
           standard_concept,
           concept_code,
           valid_start_date,
           valid_end_date,
           invalid_reason
    FROM concept c
    where c.vocabulary_id='SNOMED'
    and c.concept_class_id='Body Structure'
        UNION ALL
        SELECT  cc.concept_id,
           concept_synonym_name,
           domain_id,
           vocabulary_id,
           concept_class_id,
           standard_concept,
           concept_code,
           valid_start_date,
           valid_end_date,
           invalid_reason
    FROM concept_synonym cs
    JOIN concept cc
    on cs.concept_id=cc.concept_id
    where cc.vocabulary_id='SNOMED'
    and cc.concept_class_id='Body Structure'
) as tab)
,
     cs as (select
                   array_sort_unique (string_to_array(lower(regexp_replace(cs.concept_name,'Metastasis to a different ipsilateral |Metastasis to same |Metastasis to contralateral |Metastasis to |Metastasis to other |Metastasis to Other Parts |Metastasis to Same |Metastasis to a Different Ipsilateral Lobe of the |Metastasis to Same Lobe of the |Metastasis to a Different Ipsilateral |Metastasis to Ipsilateral |Metastasis to connective tissue and other soft tissues of ','','gi')||' structure of' || ' part of'),' ')) as array_name_cs,
                   concept_id,
                   concept_name,
                   domain_id,
                   vocabulary_id,
                   concept_class_id,
                   standard_concept,
                   concept_code,
                   valid_start_date,
                   valid_end_date,
                   invalid_reason
            from concept_stage cs where  (cs.concept_code,'Has finding site')  NOT IN (SELECT concept_code_1,relationship_id FROM concept_relationship_stage )
and coalesce(cs.concept_id,1) NOT IN ( -- to add ne codes coalesce was applied
                                          35225652, --Metastasis to the Mammary Gland maps to 35225556 Metastasis to the Breast
                                          36768964,--	Distant Metastasis Maps TO 36769180 Metastasis
                                          35226153,	--  Metastasis to the Genital Organs Maps to 35226152	Metastasis to the Genital Organs
                                          36769170,	--Non-Malignant Ascites Maps to 200528	389026000	Ascites
                                          36769789, --	Non-malignant Pleural Effusion Maps to 254061	60046008	Pleural effusion
                                          36769415,	--Pleural Effusion Maps to 254061	60046008	Pleural effusion
                                          36768514, -- 	Suspicious Ascites Maps to 200528	389026000	Ascites
                                          36768818, --	Ascites Maps to 200528	389026000	Ascites
                                          35226309--Metastasis to the Unknown Site


    )
and cs.standard_concept ='S')
,
     auto_bodysites as (
         SELECT distinct cs.concept_id
                       , cs.concept_name
                       , cs.domain_id
                       , cs.vocabulary_id
                       , cs.concept_class_id
                       , cs.standard_concept
                       , cs.concept_code
                       , cs.valid_start_date
                       , cs.valid_end_date
                       , cs.invalid_reason
                       , c3.concept_id                                                                        as bs_id
                       , c3.concept_name                                                                      as bs_name
                       , c3.vocabulary_id                                                                     as bs_vocabulary
                       , c3.standard_concept                                                                  as bs_standard
                       , c3.concept_code                                                                      as bs_code
                       , row_number()
                         OVER (PARTITION BY cs.concept_id ORDER BY length(c3.concept_name) DESC)              AS rating_in_section
         FROM cs
                  left join snomed_bs bs
                            on array_name_cs = array_name_snomed
                  left JOIN concept_relationship cr
                            ON bs.concept_id = cr.concept_id_1
                                and cr.relationship_id = 'Maps to'
                  LEFT JOIN concept c3
                            on c3.concept_id = cr.concept_id_2
         where c3.concept_id is not null
     )
,
     bodystructeradded1 as (
         SELECT concept_id,
                concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason,
                bs_id,
                bs_name,
                bs_vocabulary,
                bs_standard,
                bs_code
         FROM auto_bodysites
         where CASE WHEN concept_id = 35225613 then rating_in_section = 3 else rating_in_section = 1 end

         UNION ALL

         SELECT distinct cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         cc2.concept_id,
                         cc2.concept_name,
                         cc2.vocabulary_id,
                         cc2.standard_concept,
                         cc2.concept_code
         FROM cs cs
                  LEFT JOIN concept c
                            ON lower(c.concept_name) = lower(regexp_replace(cs.concept_name, 'Metastasis to ',
                                                                            'Secondary malignant neoplasm of ', 'gi'))
                                and c.vocabulary_id <> 'Cancer Modifier'
                                and c.domain_id = 'Condition'
                                and c.vocabulary_id IN ('ICD10', 'Nebraska Lexicon', 'SNOMED'
                                    )
                  JOIN concept_relationship r
                       on c.concept_id = r.concept_id_1
                           AND r.invalid_reason is null
                           and relationship_id = 'Maps to'
                  JOIN concept cc
                       on cc.concept_id = r.concept_id_2
                           and cc.standard_concept = 'S'
                  JOIN concept_relationship r2
                       on cc.concept_id = r2.concept_id_1
                           AND r2.invalid_reason is null
                  JOIN concept cc2
                       on cc2.concept_id = r2.concept_id_2
                           and cc2.standard_concept = 'S'
                           and cc2.concept_class_id = 'Body Structure'
         WHERE cs.concept_id
             NOT IN (SELECT concept_id from auto_bodysites where rating_in_section = 1)
           and cc.vocabulary_id <> 'Cancer Modifier'
     )

INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)

SELECT distinct concept_id,
                       concept_code,
                       vocabulary_id,
      -- concept_name,
      -- domain_id,
     --  concept_class_id,
      -- standard_concept,
  --     valid_start_date,
      -- valid_end_date,
      -- invalid_reason,
       bs_id,
      bs_code,
    --   bs_name,
       bs_vocabulary,
 --      bs_standard,
                     'Has finding site' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM (
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id=4004823	--	Structure of abdomen, peritoneum and retroperitoneum (combined site)
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Retroperitoneum Or Peritoneum%'
UNION ALL

SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id=37017947	-- 714324006	Entire organ in respiratory system
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Respiratory Organs%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id=4033554	--	Structure of large intestine
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Large Intestine%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id = 4191382	--	Brain and spinal cord structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Brain Or Spinal Cord%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id = 4172281	--	Digestive organ structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Other Digestive Organs%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id = 4004004	--	Kidney and renal pelvis, CS
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Kidney And Renal%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id = 4150673	--	Pleural structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Pleural%' -- 4150673	--	Pleural structure

UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id = 4009105	--	Liver structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Liver%' -- 4009105	--	Liver structure

UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id =4099608	--	Omentum structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike'%Omentum%'
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id =4216845	--	Genital structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Genital%' -- 4009105	--	Liver structure
UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id =4146765	--	Structure of small intestine
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Small Intestin%'

UNION ALL

SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id =4048507	--	Meninges structure
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Metastasis to meninges%'

UNION ALL
SELECT cs.concept_id,
                         cs.concept_name,
                         cs.domain_id,
                         cs.vocabulary_id,
                         cs.concept_class_id,
                         cs.standard_concept,
                         cs.concept_code,
                         cs.valid_start_date,
                         cs.valid_end_date,
                         cs.invalid_reason,
                         c.concept_id as bs_id,
                         c.concept_name as  bs_name,
                         c.vocabulary_id as bs_vocabulary,
                         c.standard_concept as bs_standard,
                         c.concept_code as bs_code
FROM cs cs
JOIN concept c ON c.concept_id =37303867	--	Abdomen
where cs.concept_code not in (select concept_code from bodystructeradded1 )
and cs.concept_name ilike '%Metastasis to abdomen%'

UNION ALL

select concept_id,
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       bs_id,
       bs_name,
       bs_vocabulary,
       bs_standard,
       bs_code
from bodystructeradded1) as result -- table with checked links to Body Structures
WHERE (concept_code, 'Has finding site',bs_code) NOT IN (SELECT concept_code_1,relationship_id,concept_code_2 from concept_relationship_stage)
;


--6 Update of some ambiguous CM codes
--Maps to relationships inside the Metastasis Class of CM vocabulary
INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)
SELECT distinct
                c.concept_id as concept_id_1,
                c.concept_code as concept_concept_code_1,
                c.vocabulary_id as concept_vocabulary_id_1,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2,
                 'Maps to' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM concept c
JOIN concept c2
ON c2.concept_id=
      CASE WHEN c.concept_id =   35225652  then      35225556
                     WHEN c.concept_id =   36768964  then      36769180
                      WHEN c.concept_id =   35226153  then      35226152
        WHEN   c.concept_id =  35226309 then      36769180
          end
WHERE c.concept_id  IN (
                                          35225652, --Metastasis to the Mammary Gland maps to 35225556 Metastasis to the Breast
                                          36768964,--	Distant Metastasis Maps TO 36769180 Metastasis
                                          35226153,	--  Metastasis to the Genital Organs Maps to 35226152	Metastasis to the Genital Organs
                                          35226309--Metastasis to the Unknown Site Maps TO 36769180 Metastasis


    )

UNION ALL

SELECT distinct
                c.concept_id as concept_id_1,
                c.concept_code as concept_concept_code_1,
                c.vocabulary_id as concept_vocabulary_id_1,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2,
                 'Concept replaced by' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM concept c
JOIN concept c2
ON c2.concept_id=
      CASE WHEN c.concept_id =   35225652  then      35225556
                     WHEN c.concept_id =   36768964  then      36769180
                      WHEN c.concept_id =   35226153  then      35226152
        WHEN   c.concept_id =  35226309 then      36769180
          end
WHERE c.concept_id  IN (
                                          35225652, --Metastasis to the Mammary Gland maps to 35225556 Metastasis to the Breast
                                          36768964,--	Distant Metastasis Maps TO 36769180 Metastasis
                                          35226153,	--  Metastasis to the Genital Organs Maps to 35226152	Metastasis to the Genital Organs
                                          35226309--Metastasis to the Unknown Site Maps TO 36769180 Metastasis


    )
;


-- 7 obvious SNOMED codes to be used as Metastasis
--Maps to insertion
with obviuos_snomed_mts as (
    SELECT distinct
                    c2.concept_name as site_name,
                    c2.concept_id as site_id,
                    cc.concept_id,
                    cc.concept_name,
                    cc.domain_id,
                    cc.vocabulary_id,
                    cc.concept_class_id,
                    cc.standard_concept,
                    cc.concept_code,
                    cc.valid_start_date,
                    cc.valid_end_date,
                    cc.invalid_reason
    FROM concept cc
             JOIN concept_relationship cr
                  on cc.concept_id = cr.concept_id_1
                      and cc.vocabulary_id = 'SNOMED'
             JOIN concept c
                  on c.concept_id = cr.concept_id_2
                      and c.concept_id = 4032806 -- Neoplasm, metastatic
             JOIN concept_relationship cr1
                  on cr1.concept_id_1 = cc.concept_id
             JOIN concept c2
                  on cr1.concept_id_2 = c2.concept_id
                      and cr1.invalid_reason is null
                      AND c2.concept_class_id = 'Body Structure'
    WHERE cc.concept_id NOT IN
          (
              SELECT distinct cc.concept_id
              FROM concept c
                       JOIN concept_relationship cr
                            ON concept_id = cr.concept_id_1
                                AND vocabulary_id = 'Cancer Modifier'
                                and concept_class_id = 'Metastasis'
                       JOIN concept cc
                            on cr.concept_id_2 = cc.concept_id
                                and cc.vocabulary_id = 'SNOMED'
          )
      and cc.domain_id = 'Condition'
      and cc.standard_concept = 'S'
      AND cc.concept_id NOT IN
          (
              SELECT distinct cc.concept_id
              FROM concept cc
                       JOIN concept_relationship cr
                            on cc.concept_id = cr.concept_id_1
                                and cc.vocabulary_id = 'SNOMED'
                       JOIN concept c
                            on c.concept_id = cr.concept_id_2
                                and c.concept_id = 4032806 -- Neoplasm, metastatic
                       JOIN concept_relationship cr1
                            on cr1.concept_id_1 = cc.concept_id
                       JOIN concept c2
                            on cr1.concept_id_2 = c2.concept_id
                                and cr1.invalid_reason is null
                                AND c2.concept_class_id = 'Body Structure'
              WHERE (cc.concept_id, 'Has asso morph') NOT IN -- TO exclude codes with definitve information about both primary+spread site
                    (
                        SELECT distinct cc.concept_id,
                                        cr.relationship_id
                        FROM concept c
                                 JOIN concept_relationship cr
                                      ON concept_id = cr.concept_id_1
                                          AND vocabulary_id = 'Cancer Modifier'
                                          and concept_class_id = 'Metastasis'
                                 JOIN concept cc
                                      on cr.concept_id_2 = cc.concept_id
                                          and cc.vocabulary_id = 'SNOMED'
                    )
                and cc.domain_id = 'Condition'
                and cc.standard_concept = 'S'
                and cr.relationship_id = 'Has asso morph'
              group by 1
              having count(*) > 1
          )
      AND cc.concept_name not ilike '%Metastatic%' -- as they are Both describes Primary Site and Site of Spread (SNOMED treats it with LOGIC GROUPS)
      AND cc.concept_name not ilike '%lymph node%' -- they have to be LN Concept Class
      and c2.concept_name not ilike '%lymph node%' -- they have to be LN Concept Class)
      AND cc.concept_name not ilike '%Leukemic%'   -- likely Primaries Neither than Metastasis
      AND cc.concept_name not ilike '%Lymphoma%'   -- likely Primaries Neither than Metastasis
      AND cc.concept_name not ilike '%by direct%'  -- the are Invasions more likely
      AND cc.concept_name not ilike '%underlying%' -- the are Invasions more likely
)
,
crs as
    (
        SELECT distinct
                cs.concept_id as concept_id_1,
                cs.concept_code as concept_concept_code_1,
                cs.concept_name as concept_concept_name_1,
                cs.vocabulary_id as concept_vocabulary_id_1,
                'Has finding site' as relationship_id,
                NULL as invalid_reason,
                c2.concept_id  as concept_concept_id_2,
                c2.concept_name  as concept_concept_name_2,
                c2.concept_code as concept_concept_code_2,
                c2.vocabulary_id as concept_vocabulary_id_2
FROM concept_stage cs
JOIN concept_relationship cr on cs.concept_id = cr.concept_id_1
JOIN concept c
on cr.concept_id_2=c.concept_id
and c.vocabulary_id='SNOMED'
JOIN concept_relationship cr2 on c.concept_id = cr2.concept_id_1
JOIN concept c2
on c2.concept_id=cr2.concept_id_2
and c2.concept_class_id= 'Body Structure'
and cr2.invalid_reason is null
    )
    ,
similarity as (
SELECT
       devv5.similarity(concept_name,concept_concept_name_1) as similarity,
    concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    concept_id_1 as concept_id_2,
    concept_concept_code_1 as concept_concept_code_2,
    concept_concept_name_1 as concept_concept_name_2,
    concept_vocabulary_id_1  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is not null)

, similarity_result as (
SELECT     row_number() OVER (PARTITION BY concept_concept_id_1 ORDER BY similarity DESC)  AS rating_in_section,

       concept_concept_id_1,
       concept_code_1,
       concept_concept_name_1,
       concept_vocabulary_id_1,
       invalid_reason,
       relationship_id,
       concept_id_2,
       concept_concept_code_2,
       concept_concept_name_2,
       concept_vocabulary_id_2
FROM similarity)
--INSERT
INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)
SELECT distinct
concept_concept_id_1 as concept_id_1 ,
                                        concept_code_1,
                                        concept_vocabulary_id_1,
                                        concept_id_2,
                                        concept_concept_code_2 ,
                                        concept_vocabulary_id_2,
                                        relationship_id,
                CURRENT_DATE,
                CURRENT_DATE,
                'D' as invalid_reason
FROM (
         SELECT rating_in_section,
                concept_concept_id_1,
                concept_code_1,
                concept_concept_name_1,
                concept_vocabulary_id_1,
                invalid_reason,
                relationship_id,
                concept_id_2,
                concept_concept_code_2,
                concept_concept_name_2,
                concept_vocabulary_id_2
         FROM similarity_result
         where CASE WHEN concept_code_1 = '285634003' then rating_in_section = 3 else rating_in_section = 1 end

         UNION ALL

         SELECT 0                        as rating_in_section,
                concept_id               as concept_concept_id_1,
                concept_code             as concept_code_1,
                concept_name             as concept_concept_name_1,
                vocabulary_id            as concept_vocabulary_id_1,
                null                     as invalid_reason,
                'Maps to'                as relationship_id,
                36768130                 as concept_id_2,
                'OMOP4997805'            as concept_concept_code_2,
                'Generalized Metastases' as concept_concept_name_2,
                'Cancer Modifier'        as concept_vocabulary_id_2
         FROM obviuos_snomed_mts osm
                  LEFT JOIN crs crs
                            ON osm.site_id = crs.concept_concept_id_2
         where crs.concept_id_1 is null
           and (concept_name ilike '%Carcinomatosis%'
             or concept_name ilike '%Disseminated%')

    UNION ALL

    SELECT
           0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36768082 as concept_id_2,
    'OMOP4997757' as concept_concept_code_2,
    'Metastasis to Kidney' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%kidney%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36770283 as concept_id_2,
    'OMOP4999962' as concept_concept_code_2,
    'Metastasis to Lung' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%lung%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36768630 as concept_id_2,
    'OMOP4998307' as concept_concept_code_2,
    'Metastasis to Spleen' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%spleen%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    35225594 as concept_id_2,
    'OMOP5032003' as concept_concept_code_2,
    'Metastasis to Vertebral Column' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%vertebral%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36769301 as concept_id_2,
    'OMOP4998978' as concept_concept_code_2,
    'Metastasis to Bone' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%bone%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36769301 as concept_id_2,
    'OMOP4998978' as concept_concept_code_2,
    'Metastasis to Bone' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%bone%'

UNION ALL

SELECT
       0                        as rating_in_section,
     concept_id as concept_concept_id_1,
    concept_code as concept_code_1,
    concept_name as concept_concept_name_1,
    vocabulary_id as concept_vocabulary_id_1,
    null as invalid_reason,
    'Maps to' as relationship_id,
    36770040 as concept_id_2,
    'OMOP4999718' as concept_concept_code_2,
    'Metastasis to Gastrointestinal Tract' as concept_concept_name_2,
    'Cancer Modifier'  as concept_vocabulary_id_2
FROM obviuos_snomed_mts osm
LEFT JOIN crs crs
ON osm.site_id=crs.concept_concept_id_2
where crs.concept_id_1 is  null
and (concept_name not ilike '%Carcinomatosis%'
and concept_name not ilike '%Disseminated%')
and concept_name ILIKE '%gastrointestinal%'
     ) as table_insert
;


-- 8 ICD10s  Maps To resuscitation
--Maps to insertion
INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)
SELECT distinct
concept_id_1 as concept_id_1 ,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                   'Maps to'     relationship_id,
                CURRENT_DATE as valid_start_date,
                    TO_DATE('20991231', 'yyyymmdd')  as valid_end_date,
          NULL as invalid_reason
FROM  (

    SELECT c.concept_id AS concept_id_1,
           c.concept_name,
           c.domain_id ,
           c.vocabulary_id as vocabulary_id_1,
           c.concept_class_id,
           c.standard_concept,
           c.concept_code as concept_code_1,
           c.valid_start_date,
           c.valid_end_date,
           c.invalid_reason,
           cs.concept_id as concept_id_2,
           cs.vocabulary_id as vocabulary_id_2,
           cs.concept_class_id,
           cs.standard_concept,
           cs.concept_code as concept_code_2,
           cs.valid_start_date,
           cs.valid_end_date,
           cs.invalid_reason
    FROM  concept c ,concept_stage cs
    WHERE cs.concept_id = 35226152
    and c.concept_id in (42485173,--KCD7 Secondary malignant neoplasm of genital organs
                         45600528,-- ICD10CM Secondary malignant neoplasm of genital organs
                         37081414 --Secondary malignant neoplasm of the genital organs ICD10GM
        )

                        UNION ALL

                            SELECT c.concept_id AS concept_id_1,
           c.concept_name,
           c.domain_id ,
           c.vocabulary_id as vocabulary_id_1,
           c.concept_class_id,
           c.standard_concept,
           c.concept_code as concept_code_1,
           c.valid_start_date,
           c.valid_end_date,
           c.invalid_reason,
           cs.concept_id as concept_id_2,
           cs.vocabulary_id as vocabulary_id_2,
           cs.concept_class_id,
           cs.standard_concept,
           cs.concept_code as concept_code_2,
           cs.valid_start_date,
           cs.valid_end_date,
           cs.invalid_reason
    FROM  concept c ,concept_stage cs
    WHERE cs.concept_id = 35225556
    and c.concept_id in ( 37081413 --ICD10GM Secondary malignant neoplasm of the mammary gland

        )
          ) AS TAB
;


--Manual Table Preparation
TRUNCATE TABLE concept_manual;

--CONCEPT MANUAL (Metastasis)
INSERT INTO concept_manual
(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_stage
    ;
    


--TRUNCATE STAGE TABLES
TRUNCATE TABLE concept_stage;

--CONCEPT MANUAL ENTIRE VOCABULARY (1st iteration)
DROP TABLE concept_manual_metastasis;
CREATE TABLE concept_manual_metastasis as
 SELECT distinct
                 concept_name,
                 domain_id,
                 vocabulary_id,
                 concept_class_id,
                 standard_concept,
                 concept_code,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_manual
;
--Manual Table Preparation
TRUNCATE TABLE concept_relationship_manual;

INSERT INTO concept_relationship_manual
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT
       concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_stage
    ;
--CONCEPT RELATIONSHIP MANUAL ENTIRE VOCABULARY (1st iteration)
DROP TABLE concept_relationship_manual_metastasis;
CREATE TABLE concept_relationship_manual_metastasis as
 SELECT distinct
                 concept_code_1,
                 concept_code_2,
                 vocabulary_id_1,
                 vocabulary_id_2,
                 relationship_id,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_relationship_manual
;
--TRUNCATE STAGE TABLES
TRUNCATE TABLE concept_relationship_stage;

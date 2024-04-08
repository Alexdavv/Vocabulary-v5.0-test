-- 1. insert previous Mental Health and Well-Being Module concepts and their relationships to deprecate and add branching logic from manual files

-- 2. insert new concepts into concept_manual
--insert module bhp
INSERT INTO concept_manual
SELECT DISTINCT
'Behavioral Health and Personality' AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Module' AS concept_class_id,
'S' AS source_standard_concept,
'bhp' AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason;

-- insert questions bhp
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM bhp_pr
WHERE flag = 'q';

--insert answers bhp
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
'S' AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM bhp_pr
WHERE flag = 'a'
AND concept_code NOT IN ('pmi_prefernottoanswer', 'pmi_dontknow', 'pmi_none', 'pmi_doesnotapplytome'); --concepts will be reused

--insert module ehh
INSERT INTO concept_manual
SELECT DISTINCT
'Emotional Health History and Well-Being' AS concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Module' AS concept_class_id,
'S' AS source_standard_concept,
'ehhwb' AS concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason;

-- insert questions ehh
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Question' AS concept_class_id,
'S' AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_pr
WHERE flag = 'q';

--insert answers ehh
INSERT INTO concept_manual
SELECT DISTINCT
concept_name,
'Observation' AS domain_id,
'PPI' AS vocabulary_id,
'Answer' AS concept_class_id,
'S' AS source_standard_concept,
concept_code,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_pr
WHERE flag = 'a'
AND concept_code NOT IN ('pmi_prefernottoanswer', 'pmi_dontknow', 'pmi_none', 'pmi_doesnotapplytome'); --concepts will be reused

-- 3. insert new relationships
--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
'bhp' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM bhp_pr
WHERE flag = 'q'
AND concept_code != 'bhp';

--to add hierarchy 'Has PPI parent code' from Questions to Module
INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
'ehhwb' AS concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_pr
WHERE flag = 'q'
AND concept_code != 'ehh';

--to add hierarchy 'Has PPI parent code' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code as concept_code_1,
question_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM bhp_qa
WHERE answer_code NOT IN ('PMI_PreferNotToAnswer', 'PMI_DontKnow', 'PMI_None', 'PMI_DoesNotApplyToMe');

--to add hierarchy 'Has answer (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code as concept_code_1,
answer_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has answer (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM bhp_qa
WHERE answer_code NOT IN ('PMI_PreferNotToAnswer', 'PMI_DontKnow', 'PMI_None', 'PMI_DoesNotApplyToMe');

--to add hierarchy 'Has PPI parent code' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
answer_code as concept_code_1,
question_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has PPI parent code' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_qa
WHERE answer_code NOT IN ('PMI_PreferNotToAnswer', 'PMI_DontKnow', 'PMI_None', 'PMI_DoesNotApplyToMe');

--to add hierarchy 'Has answer (PPI)' from Answers to Questions
INSERT INTO concept_relationship_manual
SELECT DISTINCT
question_code as concept_code_1,
answer_code as concept_code_2,
'PPI' AS vocabulary_id_1,
'PPI' AS vocabulary_id_2,
'Has answer (PPI)' AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ehh_qa
WHERE answer_code NOT IN ('PMI_PreferNotToAnswer', 'PMI_DontKnow', 'PMI_None', 'PMI_DoesNotApplyToMe');

-- add mappings
--DROP TABLE ppi_mapped;
--TRUNCATE TABLE ppi_mapped;
CREATE TABLE ppi_mapped
(concept_code varchar,
concept_name varchar,
relationship_id varchar,
target_concept_id int,
target_concept_code varchar,
target_concept_name varchar,
target_concept_class varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
target_domain_id varchar,
target_vocabulary_id varchar);


INSERT INTO concept_relationship_manual
SELECT DISTINCT
concept_code AS concept_code_1,
target_concept_code AS concept_code_2,
'PPI' AS vocabulary_id_1,
target_vocabulary_id AS vocabulary_id_2,
relationship_id AS relationship_id,
CURRENT_DATE AS valid_start_date,
TO_DATE('20991231','yyyymmdd') AS valid_end_date,
NULL AS invalid_reason
FROM ppi_mapped
WHERE target_concept_id IS NOT NULL
and concept_code NOT IN ('pmi_none', 'pmi_doesnotapplytome');

--Destandartization of concepts, which have maps to S
UPDATE concept_manual
SET standard_concept = NULL
WHERE concept_code IN (SELECT concept_code_1 FROM concept_relationship_manual WHERE relationship_id = 'Maps to');

--Update domain for all the concepts
UPDATE concept_manual
SET domain_id = 'Observation';

-- 4. insert concept synonyms from manual file
SELECT * FROM concept_manual;
SELECT * FROM concept_relationship_manual;
SELECT * FROM concept_synonym_manual;

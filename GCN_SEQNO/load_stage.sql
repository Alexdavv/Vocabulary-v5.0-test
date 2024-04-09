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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'GCN_SEQNO',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.nddf_product_info LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.nddf_product_info LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_GCNSEQNO'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add GCN_SEQNO to concept_stage from rxnconso
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT SUBSTR(c.str, 1, 255) AS concept_name,
	'Drug' AS domain_id,
	'GCN_SEQNO' AS vocabulary_id,
	'GCN_SEQNO' AS concept_class_id,
	NULL AS standard_concept,
	c.code AS concept_code,
	(
		SELECT v.latest_update
		FROM vocabulary v
		WHERE v.vocabulary_id = 'GCN_SEQNO'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.rxnconso c
WHERE c.sab = 'NDDF'
	AND c.tty = 'CDC';

--4. Load into concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT gcn.code AS concept_code_1,
	rxn.code AS concept_code_2,
	'GCN_SEQNO' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT v.latest_update
		FROM vocabulary v
		WHERE v.vocabulary_id = 'GCN_SEQNO'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.rxnconso gcn
JOIN SOURCES.rxnconso rxn ON rxn.rxcui = gcn.rxcui
	AND rxn.sab = 'RXNORM'
WHERE gcn.sab = 'NDDF'
	AND gcn.tty = 'CDC';

--5. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
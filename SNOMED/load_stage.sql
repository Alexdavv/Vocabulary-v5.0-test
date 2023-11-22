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
* Authors: Eduard Korchmar, Alexander Davydov, Timur Vakhitov,
* Christian Reich, Oleg Zhuk, Masha Khitrun
* Date: 2023
**************************************************************************/

--1. Extract each component (International, UK & US) versions to properly date the combined source in next step
CREATE OR REPLACE VIEW module_date AS
WITH a as (
SELECT DISTINCT ON (m.id) m.moduleid,
		TO_CHAR(m.sourceeffectivetime, 'yyyy-mm-dd') AS local_version,
		TO_CHAR(m.targeteffectivetime, 'yyyy-mm-dd') AS int_version
FROM sources.der2_ssrefset_moduledependency_merged m
WHERE m.active = 1
	AND m.referencedcomponentid = 900000000000012004
	AND --Model component module; Synthetic target, contains source version in each row
	m.moduleid IN (
		900000000000207008, --Core (international) module
		999000011000000103, --UK edition
		731000124108 --US edition
		)
ORDER BY m.id,
	m.effectivetime DESC)

SELECT moduleid,
		CASE WHEN moduleid = 900000000000207008
			THEN (SELECT MIN(int_version)
				FROM a)
			ELSE local_version
		END AS version
FROM a;

--2. Update latest_update field to new date
--Use the latest of the release dates of all source versions. Usually, the UK is the latest.
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SNOMED',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.sct2_concept_full_merged LIMIT 1),
	pVocabularyVersion		=>
		(SELECT version FROM module_date where moduleid = 900000000000207008) || ' SNOMED CT International Edition; ' ||
		(SELECT version FROM module_date where moduleid = 731000124108) || ' SNOMED CT US Edition; ' ||
		(SELECT version FROM module_date where moduleid = 999000011000000103) || ' SNOMED CT UK Edition',
	pVocabularyDevSchema	=> 'DEV_SNOMED'
);
END $_$;

--3. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--4. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT sct2.concept_name,
	'SNOMED' AS vocabulary_id,
	sct2.concept_code,
	TO_DATE(effectivestart, 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT vocabulary_pack.CutConceptName(d.term) AS concept_name,
		d.conceptid::TEXT AS concept_code,
		c.active,
		FIRST_VALUE(c.effectivetime) OVER (
			PARTITION BY c.id ORDER BY c.active DESC, c.effectivetime --if there ever were active versions of the concept, take the earliest one
			) AS effectivestart,
		ROW_NUMBER() OVER (
			PARTITION BY d.conceptid
			-- Order of preference:
			-- Active descriptions first, characterised as Preferred Synonym, prefer SNOMED Int, then US, then UK, then take the latest term
			ORDER BY c.active DESC,
				d.active DESC,
				l.active DESC,
				CASE l.acceptabilityid
					WHEN 900000000000548007
						THEN 1 --Preferred
					WHEN 900000000000549004
						THEN 2 --Acceptable
					ELSE 99
					END ASC,
				CASE d.typeid
					WHEN 900000000000013009
						THEN 1 --Synonym (PT)
					WHEN 900000000000003001
						THEN 2 --Fully specified name
					ELSE 99
					END ASC,
				CASE l.refsetid
					WHEN 900000000000509007
						THEN 1 --US English language reference set
					WHEN 900000000000508004
						THEN 2 --UK English language reference set
					ELSE 99 -- Various UK specific refsets
					END,
				CASE l.source_file_id
					WHEN 'INT'
						THEN 1 -- International release
					WHEN 'US'
						THEN 2 -- SNOMED US
					--WHEN 'GB_DE'
					--	THEN 3 -- SNOMED UK Drug extension, updated more often
					WHEN 'UK'
						THEN 4 -- SNOMED UK
					ELSE 99
					END ASC,
				l.effectivetime DESC,
				d.term
			) AS rn
	FROM sources.sct2_concept_full_merged c
	JOIN sources.sct2_desc_full_merged d ON d.conceptid = c.id
	JOIN sources.der2_crefset_language_merged l ON l.referencedcomponentid = d.id
        WHERE
            c.moduleid NOT IN (
                999000011000001104, --UK Drug extension
                999000021000001108  --UK Drug extension reference set module
            )
        ) sct2
WHERE
    sct2.rn = 1
;
ANALYSE concept_stage;
;
--4.1 For concepts with latest entry in sct2_concept having active = 0, preserve invalid_reason and valid_end date
WITH inactive
AS (
	SELECT c.id,
		MAX(c.effectivetime) AS effectiveend
	FROM sources.sct2_concept_full_merged c
	LEFT JOIN sources.sct2_concept_full_merged c2 ON --ignore all entries before latest one with active = 1
		c2.active = 1
		AND c.id = c2.id
		AND c.effectivetime < c2.effectivetime
	WHERE
	    c2.id IS NULL
    AND c.active = 0
    AND c.moduleid NOT IN (
       999000011000001104, --UK Drug extension
       999000021000001108  --UK Drug extension reference set module
    )
    GROUP BY c.id)
UPDATE concept_stage cs
SET invalid_reason = 'D',
	valid_end_date = TO_DATE(i.effectiveend, 'yyyymmdd')
FROM inactive i
WHERE
        i.id::TEXT = cs.concept_code
    AND cs.vocabulary_id = 'SNOMED'
;
--4.2 Fix concept names: change vitamin B>12< deficiency to vitamin B-12 deficiency; NAD(P)^+^ to NAD(P)+
UPDATE concept_stage
SET concept_name = vocabulary_pack.CutConceptName(TRANSLATE(concept_name, '>,<,^', '-'))
WHERE (
		(
			concept_name LIKE '%>%'
			AND concept_name LIKE '%<%'
			)
		OR (concept_name LIKE '%^%^%')
		)
	AND LENGTH(concept_name) > 5;

--5. Update concept_class_id from extracted hierarchy tag information and terms ordered by description table precedence
UPDATE concept_stage cs
SET concept_class_id = i.concept_class_id
FROM (
	WITH tmp_concept_class AS (
			SELECT *
			FROM (
				SELECT concept_code,
					f7, -- SNOMED hierarchy tag
					ROW_NUMBER() OVER (
						PARTITION BY concept_code
						-- order of precedence: active, by class relevance
						-- Might be redundant, as normally concepts will never have more than 1 hierarchy tag, but we
                        -- have concurrent sources, so this may prevent problems and breaks nothing
						ORDER BY active DESC,
							rnb,
							CASE f7
								WHEN 'disorder'
									THEN 1
								WHEN 'finding'
									THEN 2
								WHEN 'procedure'
									THEN 3
								WHEN 'regime/therapy'
									THEN 4
								WHEN 'qualifier value'
									THEN 5
								WHEN 'contextual qualifier'
									THEN 6
								WHEN 'body structure'
									THEN 7
								WHEN 'cell'
									THEN 8
								WHEN 'cell structure'
									THEN 9
								WHEN 'external anatomical feature'
									THEN 10
								WHEN 'organ component'
									THEN 11
								WHEN 'organism'
									THEN 12
								WHEN 'living organism'
									THEN 13
								WHEN 'physical object'
									THEN 14
								WHEN 'physical device'
									THEN 15
								WHEN 'physical force'
									THEN 16
								WHEN 'occupation'
									THEN 17
								WHEN 'person'
									THEN 18
								WHEN 'ethnic group'
									THEN 19
								WHEN 'religion/philosophy'
									THEN 20
								WHEN 'life style'
									THEN 21
								WHEN 'social concept'
									THEN 22
								WHEN 'racial group'
									THEN 23
								WHEN 'event'
									THEN 24
								WHEN 'life event - finding'
									THEN 25
								WHEN 'product'
									THEN 26
								WHEN 'substance'
									THEN 27
								WHEN 'assessment scale'
									THEN 28
								WHEN 'tumor staging'
									THEN 29
								WHEN 'staging scale'
									THEN 30
								WHEN 'specimen'
									THEN 31
								WHEN 'special concept'
									THEN 32
								WHEN 'observable entity'
									THEN 33
								WHEN 'namespace concept'
									THEN 34
								WHEN 'morphologic abnormality'
									THEN 35
								WHEN 'foundation metadata concept'
									THEN 36
								WHEN 'core metadata concept'
									THEN 37
								WHEN 'metadata'
									THEN 38
								WHEN 'environment'
									THEN 39
								WHEN 'geographic location'
									THEN 40
								WHEN 'situation'
									THEN 41
								WHEN 'situation'
									THEN 42
								WHEN 'context-dependent category'
									THEN 43
								WHEN 'biological function'
									THEN 44
								WHEN 'attribute'
									THEN 45
								WHEN 'administrative concept'
									THEN 46
								WHEN 'record artifact'
									THEN 47
								WHEN 'navigational concept'
									THEN 48
								WHEN 'inactive concept'
									THEN 49
								WHEN 'linkage concept'
									THEN 50
								WHEN 'link assertion'
									THEN 51
								WHEN 'environment / location'
									THEN 52
								ELSE 99
								END
						) AS rnc
				FROM (
					SELECT concept_code,
						active,
						SUBSTRING(term, '\(([^(]+)\)$') AS f7,
						rna AS rnb -- row number in sct2_desc_full_merged
					FROM (
						SELECT c.concept_code,
							d.term,
							d.active,
							ROW_NUMBER() OVER (
								PARTITION BY c.concept_code ORDER
								BY
									d.active DESC, -- active ones
									d.effectivetime DESC -- latest active ones
								) rna -- row number in sct2_desc_full_merged
						FROM concept_stage c
						JOIN sources.sct2_desc_full_merged d ON d.conceptid::TEXT = c.concept_code
						WHERE
							    c.vocabulary_id = 'SNOMED'
							AND d.typeid = 900000000000003001 -- only Fully Specified Names
						    AND d.moduleid NOT IN (
                                999000011000001104, --UK Drug extension
                                999000021000001108  --UK Drug extension reference set module
                            )
                        ) AS s0
					) AS s1
				) AS s2
			WHERE rnc = 1
			)
	SELECT concept_code,
		CASE
			WHEN F7 = 'disorder'
				THEN 'Disorder'
			WHEN F7 = 'procedure'
				THEN 'Procedure'
			WHEN F7 = 'finding'
				THEN 'Clinical Finding'
			WHEN F7 = 'organism'
				THEN 'Organism'
			WHEN F7 = 'body structure'
				THEN 'Body Structure'
			WHEN F7 = 'substance'
				THEN 'Substance'
			WHEN F7 = 'product'
				THEN 'Pharma/Biol Product'
			WHEN F7 = 'event'
				THEN 'Event'
			WHEN F7 = 'qualifier value'
				THEN 'Qualifier Value'
			WHEN F7 = 'observable entity'
				THEN 'Observable Entity'
			WHEN F7 = 'situation'
				THEN 'Context-dependent'
			WHEN F7 = 'occupation'
				THEN 'Social Context'
			WHEN F7 = 'regime/therapy'
				THEN 'Procedure'
			WHEN F7 = 'morphologic abnormality'
				THEN 'Morph Abnormality'
			WHEN F7 = 'physical object'
				THEN 'Physical Object'
			WHEN F7 = 'specimen'
				THEN 'Specimen'
			WHEN F7 = 'environment'
				THEN 'Location'
			WHEN F7 = 'environment / location'
				THEN 'Location'
			WHEN F7 = 'context-dependent category'
				THEN 'Context-dependent'
			WHEN F7 = 'attribute'
				THEN 'Attribute'
			WHEN F7 = 'linkage concept'
				THEN 'Linkage Concept'
			WHEN F7 = 'assessment scale'
				THEN 'Staging / Scales'
			WHEN F7 = 'person'
				THEN 'Social Context'
			WHEN F7 = 'cell'
				THEN 'Body Structure'
			WHEN F7 = 'geographic location'
				THEN 'Location'
			WHEN F7 = 'cell structure'
				THEN 'Body Structure'
			WHEN F7 = 'ethnic group'
				THEN 'Social Context'
			WHEN F7 = 'tumor staging'
				THEN 'Staging / Scales'
			WHEN F7 = 'religion/philosophy'
				THEN 'Social Context'
			WHEN F7 = 'record artifact'
				THEN 'Record Artifact'
			WHEN F7 = 'physical force'
				THEN 'Physical Force'
			WHEN F7 = 'foundation metadata concept'
				THEN 'Model Comp'
			WHEN F7 = 'namespace concept'
				THEN 'Namespace Concept'
			WHEN F7 = 'administrative concept'
				THEN 'Admin Concept'
			WHEN F7 = 'biological function'
				THEN 'Biological Function'
			WHEN F7 = 'living organism'
				THEN 'Organism'
			WHEN F7 = 'life style'
				THEN 'Social Context'
			WHEN F7 = 'contextual qualifier'
				THEN 'Qualifier Value'
			WHEN F7 = 'staging scale'
				THEN 'Staging / Scales'
			WHEN F7 = 'life event - finding'
				THEN 'Event'
			WHEN F7 = 'social concept'
				THEN 'Social Context'
			WHEN F7 = 'core metadata concept'
				THEN 'Model Comp'
			WHEN F7 = 'special concept'
				THEN 'Special Concept'
			WHEN F7 = 'racial group'
				THEN 'Social Context'
			WHEN F7 = 'therapy'
				THEN 'Procedure'
			WHEN F7 = 'external anatomical feature'
				THEN 'Body Structure'
			WHEN F7 = 'organ component'
				THEN 'Body Structure'
			WHEN F7 = 'physical device'
				THEN 'Physical Object'
			WHEN F7 = 'linkage concept'
				THEN 'Linkage Concept'
			WHEN F7 = 'link assertion'
				THEN 'Linkage Assertion'
			WHEN F7 = 'metadata'
				THEN 'Model Comp'
			WHEN F7 = 'navigational concept'
				THEN 'Navi Concept'
			WHEN F7 = 'inactive concept'
				THEN 'Inactive Concept'
					--added 20190109 (AVOF-1369)
			WHEN F7 = 'administration method'
				THEN 'Qualifier Value'
			WHEN F7 = 'basic dose form'
				THEN 'Dose Form'
			WHEN F7 = 'clinical drug'
				THEN 'Clinical Drug'
			WHEN F7 = 'disposition'
				THEN 'Disposition'
			WHEN F7 = 'dose form'
				THEN 'Dose Form'
			WHEN F7 = 'intended site'
				THEN 'Qualifier Value'
			WHEN F7 = 'medicinal product'
				THEN 'Pharma/Biol Product'
			WHEN F7 = 'medicinal product form'
				THEN 'Clinical Drug Form'
			WHEN F7 = 'number'
				THEN 'Qualifier Value'
			WHEN F7 = 'release characteristic'
				THEN 'Qualifier Value'
			WHEN F7 = 'role'
				THEN 'Qualifier Value'
			WHEN F7 = 'state of matter'
				THEN 'Qualifier Value'
			WHEN F7 = 'transformation'
				THEN 'Qualifier Value'
			WHEN F7 = 'unit of presentation'
				THEN 'Qualifier Value'
					--Metadata concepts
			WHEN F7 = 'OWL metadata concept'
				THEN 'Model Comp'
					--Specific drug qualifiers
			WHEN F7 = 'supplier'
				THEN 'Qualifier Value'
			WHEN F7 = 'product name'
				THEN 'Qualifier Value'
			ELSE 'Undefined'
			END AS concept_class_id
	FROM tmp_concept_class
	) i
WHERE
        i.concept_code = cs.concept_code
    AND cs.vocabulary_id = 'SNOMED'
;

--Assign top SNOMED concept
UPDATE concept_stage
SET concept_class_id = 'Model Comp'
WHERE concept_code = '138875005'
	AND vocabulary_id = 'SNOMED';

--Deprecated Concepts with broken fully specified name
UPDATE concept_stage
SET concept_class_id = 'Procedure'
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		'712611000000106', --Assessment using childhood health assessment questionnaire
		'193371000000106' --Fluoroscopic angioplasty of carotid artery
		);

UPDATE concept_stage
SET concept_class_id = 'Staging / Scales'
WHERE
        vocabulary_id = 'SNOMED'
    AND concept_code in (
		'821611000000108',
		'821551000000108',
		'821591000000100',
		'821561000000106',
		'821581000000102',
		'1090511000000109'
		);

--6. --Some old deprecated concepts from UK drug extension module never have had correct FSN, so we can't get explicit hierarchy tag and keep them as Context-dependent class
-- SNOMED CT UK drug extension module is retired from OMOP starting 2024 release.
/*
WITH sub AS (
       SELECT conceptid::TEXT AS concept_code,
              SUBSTRING(term, '-(([^-]+).*)$') AS tag
       FROM sources.sct2_desc_full_merged m
)
UPDATE concept_stage c
 SET concept_class_id = (
        CASE WHEN sub.tag = ' product'
        		THEN 'Pharma/Biol Product'
        ELSE 'Context-dependent' END
        )
FROM sub
WHERE sub.concept_code = c.concept_code
	AND c.concept_class_id = 'Undefined'
	AND c.invalid_reason IS NOT NULL
	AND --Make sure we only affect old concepts and not mask new classes additions
	EXISTS (
		SELECT 1
		FROM sources.sct2_concept_full_merged m
		WHERE m.id::TEXT = c.concept_code
			AND m.moduleid = 999000011000001104 --SNOMED CT United Kingdom drug extension module
		);*/

--7. Get all the synonyms from UMLS ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT m.code,
	'SNOMED',
	vocabulary_pack.CutConceptSynonymName(m.str),
	4180186 -- English
FROM sources.mrconso m
JOIN concept_stage s ON s.concept_code = m.code
WHERE m.sab = 'SNOMEDCT_US'
	AND m.tty IN (
		'PT',
		'PTGB',
		'SY',
		'SYGB',
		'MTH_PT',
		'FN',
		'MTH_SY',
		'SB'
		);

--8. Add active synonyms from merged descriptions list
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT d.conceptid,
	'SNOMED',
	vocabulary_pack.CutConceptSynonymName(d.term),
	4180186 -- English
FROM (SELECT m.id,
             m.conceptid::text,
             m.term,
             first_value(active) OVER (
                 PARTITION BY id ORDER BY effectivetime DESC
                 ) AS active_status
      FROM sources.sct2_desc_full_merged m
      WHERE
          m.moduleid NOT IN (
            999000011000001104, -- UK Drug extension
            999000021000001108  -- UK Drug extension reference set module
        )
      ) d
JOIN concept_stage s ON s.concept_code = d.conceptid
WHERE d.active_status = 1
	AND NOT EXISTS (
		SELECT 1
		FROM concept_synonym_stage css_int
		WHERE css_int.synonym_concept_code = d.conceptid
			AND css_int.synonym_name = vocabulary_pack.CutConceptSynonymName(d.term)
		);

--9. Fill concept_relationship_stage from merged SNOMED source
-- 9.1 Add relationships from concept to module and from concept to status:
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
WITH tmp_rel AS (
		--add relationships from concept to module
		SELECT cs.concept_code AS concept_code_1,
			moduleid::TEXT AS concept_code_2,
			'Has Module' AS relationship_id,
			cs.valid_start_date
		FROM sources.sct2_concept_full_merged c
		JOIN concept_stage cs ON cs.concept_code = c.id::TEXT
			AND cs.vocabulary_id = 'SNOMED'
		WHERE c.moduleid IN (
				900000000000207008, --Core (international) module
				999000011000000103, --UK edition
				731000124108, 		--US edition
                --999000011000001104, --SNOMED CT United Kingdom drug extension module
                --999000021000001108, --SNOMED CT United Kingdom drug extension reference set module
				900000000000012004 --SNOMED CT model component
				)

		UNION ALL

		--add relationship from concept to status
		SELECT st.concept_code::TEXT,
			st.statusid::TEXT,
			'Has status',
			valid_start_date
		FROM (
			SELECT cs.concept_code,
				statusid::TEXT,
				TO_DATE(effectivetime, 'YYYYMMDD') AS valid_start_date,
				ROW_NUMBER() OVER (
					PARTITION BY id ORDER BY TO_DATE(effectivetime, 'YYYYMMDD') DESC
					) rn
			FROM sources.sct2_concept_full_merged c
			JOIN concept_stage cs ON cs.concept_code = c.id::TEXT
				AND cs.vocabulary_id = 'SNOMED'
			WHERE c.statusid IN (
					900000000000073002, --Defined
					900000000000074008 --Primitive
					)
			  AND c.moduleid NOT IN (
                    999000011000001104, --SNOMED CT United Kingdom drug extension module
                    999000021000001108  --SNOMED CT United Kingdom drug extension reference set module
                )
			) st
		WHERE st.rn = 1
		)
SELECT concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	SELECT DISTINCT concept_code_1,
					concept_code_2,
					'SNOMED' AS vocabulary_id_1,
					'SNOMED' AS vocabulary_id_2,
					relationship_id,
					valid_start_date,
					TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
					NULL AS invalid_reason
	FROM tmp_rel
	 ) sn
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id
		);

-- 9.2. Add other attribute relationships:
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
WITH attr_rel AS (
		SELECT sourceid::TEXT,
			destinationid::TEXT,
			typeid,
			REPLACE(term, ' (attribute)', '') AS term
		FROM (
			SELECT r.sourceid,
				r.destinationid,
				r.typeid,
				term,
				ROW_NUMBER() OVER (
					PARTITION BY r.id ORDER BY r.effectivetime DESC,
						d.id DESC -- fix for AVOF-650
					) AS rn, -- get the latest in a sequence of relationships, to decide whether it is still active
				r.active
			FROM sources.sct2_rela_full_merged r
			JOIN sources.sct2_desc_full_merged d ON d.conceptid = r.typeid
            WHERE
                r.moduleid NOT IN (
                    999000011000001104, --UK Drug extension
                    999000021000001108  --UK Drug extension reference set module
                )
			) AS s0
		WHERE rn = 1
			AND active = 1
			AND sourceid IS NOT NULL
			AND destinationid IS NOT NULL
			AND term <> 'PBCL flag true'
)

SELECT concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	--convert SNOMED to OMOP-type relationship_id
SELECT DISTINCT sourceid AS concept_code_1,
		destinationid AS concept_code_2,
		'SNOMED' AS vocabulary_id_1,
		'SNOMED' AS vocabulary_id_2,
		CASE
			WHEN typeid = 260507000
				THEN 'Has access'
			WHEN typeid = 363715002
				THEN 'Has etiology'
			WHEN typeid = 255234002
				THEN 'Followed by'
			WHEN typeid = 260669005
				THEN 'Has surgical appr'
			WHEN typeid = 246090004
				THEN 'Has asso finding'
			WHEN typeid = 116676008
				THEN 'Has asso morph'
			WHEN typeid = 363589002
				THEN 'Has asso proc'
			WHEN typeid = 47429007
				THEN 'Finding asso with'
			WHEN typeid = 246075003
				THEN 'Has causative agent'
			WHEN typeid = 263502005
				THEN 'Has clinical course'
			WHEN typeid = 246093002
				THEN 'Has component'
			WHEN typeid = 363699004
				THEN 'Has dir device'
			WHEN typeid = 363700003
				THEN 'Has dir morph'
			WHEN typeid = 363701004
				THEN 'Has dir subst'
			WHEN typeid = 42752001
				THEN 'Has due to'
			WHEN typeid = 246456000
				THEN 'Has episodicity'
			WHEN typeid = 260858005
				THEN 'Has extent'
			WHEN typeid = 408729009
				THEN 'Has finding context'
			WHEN typeid = 419066007
				THEN 'Using finding inform'
			WHEN typeid = 418775008
				THEN 'Using finding method'
			WHEN typeid = 363698007
				THEN 'Has finding site'
			WHEN typeid = 127489000
				THEN 'Has active ing'
			WHEN typeid = 363705008
				THEN 'Has manifestation'
			WHEN typeid IN (411116001, 411116001)
				THEN 'Has dose form'
			WHEN typeid = 363702006
				THEN 'Has focus'
			WHEN typeid = 363713009
				THEN 'Has interpretation'
			WHEN typeid = 116678009
				THEN 'Has meas component'
			WHEN typeid = 116686009
				THEN 'Has specimen'
			WHEN typeid = 258214002
				THEN 'Has stage'
			WHEN typeid = 363710007
				THEN 'Has indir device'
			WHEN typeid = 363709002
				THEN 'Has indir morph'
			WHEN typeid = 309824003
				THEN 'Using device'
			WHEN typeid = 363703001
				THEN 'Has intent'
			WHEN typeid = 363714003
				THEN 'Has interprets'
			WHEN typeid = 116680003
				THEN 'Is a'
			WHEN typeid = 272741003
				THEN 'Has laterality'
			WHEN typeid = 370129005
				THEN 'Has measurement'
			WHEN typeid = 260686004
				THEN 'Has method'
			WHEN typeid = 246454002
				THEN 'Has occurrence'
			WHEN typeid = 246100006
				THEN 'Has clinical course'
			WHEN typeid = 123005000
				THEN 'Part of'
			WHEN typeid IN (308489006, 370135005, 719722006)
				THEN 'Has pathology'
			WHEN typeid = 260870009
				THEN 'Has priority'
			WHEN typeid = 408730004
				THEN 'Has proc context'
			WHEN typeid = 405815000
				THEN 'Has proc device'
			WHEN typeid = 405816004
				THEN 'Has proc morph'
			WHEN typeid = 405813007
				THEN 'Has dir proc site'
			WHEN typeid = 405814001
				THEN 'Has indir proc site'
			WHEN typeid = 363704007
				THEN 'Has proc site'
			WHEN typeid = 370130000
				THEN 'Has property'
			WHEN typeid = 370131001
				THEN 'Has recipient cat'
			WHEN typeid = 246513007
				THEN 'Has revision status'
			WHEN typeid = 410675002
				THEN 'Has route of admin'
			WHEN typeid = 370132008
				THEN 'Has scale type'
			WHEN typeid = 246112005
				THEN 'Has severity'
			WHEN typeid = 118171006
				THEN 'Has specimen proc'
			WHEN typeid = 118170007
				THEN 'Has specimen source'
			WHEN typeid = 118168003
				THEN 'Has specimen morph'
			WHEN typeid = 118169006
				THEN 'Has specimen topo'
			WHEN typeid = 370133003
				THEN 'Has specimen subst'
			WHEN typeid = 408732007
				THEN 'Has relat context'
			WHEN typeid = 424876005
				THEN 'Has surgical appr'
			WHEN typeid = 408731000
				THEN 'Has temporal context'
			WHEN typeid = 363708005
				THEN 'Occurs after'
			WHEN typeid = 370134009
				THEN 'Has time aspect'
			WHEN typeid = 425391005
				THEN 'Using acc device'
			WHEN typeid = 424226004
				THEN 'Using device'
			WHEN typeid = 424244007
				THEN 'Using energy'
			WHEN typeid = 424361007
				THEN 'Using subst'
			WHEN typeid = 255234002
				THEN 'Followed by'
			WHEN typeid = 8940601000001102
				THEN 'Has non-avail ind'
			WHEN typeid = 12223201000001101
				THEN 'Has ARP'
			WHEN typeid = 12223101000001108
				THEN 'Has VRP'
			WHEN typeid = 9191701000001107
				THEN 'Has trade family grp'
			WHEN typeid = 8941101000001104
				THEN 'Has flavor'
			WHEN typeid = 8941901000001101
				THEN 'Has disc indicator'
			WHEN typeid = 12223501000001103
				THEN 'VRP has prescr stat'
			WHEN typeid = 10362801000001104
				THEN 'Has spec active ing'
			WHEN typeid = 8653101000001104
				THEN 'Has excipient'
			WHEN typeid IN (732943007, 10363001000001101)
				THEN 'Has basis str subst'
			WHEN typeid = 10362601000001103
				THEN 'Has VMP'
			WHEN typeid = 10362701000001108
				THEN 'Has AMP'
			WHEN typeid = 10362901000001105
				THEN 'Has disp dose form'
			WHEN typeid = 8940001000001105
				THEN 'VMP has prescr stat'
			WHEN typeid IN (8941301000001102, 4074701000001107)
				THEN 'Has legal category'
			WHEN typeid = 42752001
				THEN 'Caused by'
			WHEN typeid = 704326004
				THEN 'Has precondition'
			WHEN typeid = 718497002
				THEN 'Has inherent loc'
			WHEN typeid = 246501002
				THEN 'Has technique'
			WHEN typeid = 719715003
				THEN 'Has relative part'
			WHEN typeid = 704324001
				THEN 'Has process output'
			WHEN typeid = 704318007
				THEN 'Has property type'
			WHEN typeid = 704319004
				THEN 'Inheres in'
			WHEN typeid = 704327008
				THEN 'Has direct site'
			WHEN typeid = 704321009
				THEN 'Characterizes'
					--added 20171116
			WHEN typeid = 371881003
				THEN 'During'
			WHEN typeid = 732947008
				THEN 'Has denominator unit'
			WHEN typeid = 732946004
				THEN 'Has denomin value'
			WHEN typeid = 732945000
				THEN 'Has numerator unit'
			WHEN typeid = 732944001
				THEN 'Has numerator value'
					--added 20180205
			WHEN typeid = 736476002
				THEN 'Has basic dose form'
			WHEN typeid = 726542003
				THEN 'Has disposition'
			WHEN typeid = 736472000
				THEN 'Has admin method'
			WHEN typeid = 736474004
				THEN 'Has intended site'
			WHEN typeid = 736475003
				THEN 'Has release charact'
			WHEN typeid = 736473005
				THEN 'Has transformation'
			WHEN typeid = 736518005
				THEN 'Has state of matter'
			WHEN typeid = 726633004
				THEN 'Temp related to'
					--added 20180622
			WHEN typeid = 13085501000001109
				THEN 'Has unit of admin'
			WHEN typeid = 762949000
				THEN 'Has prec ingredient'
			WHEN typeid = 763032000
				THEN 'Has unit of presen'
			WHEN typeid = 733724008
				THEN 'Has conc num val'
			WHEN typeid = 733723002
				THEN 'Has conc denom val'
			WHEN typeid = 733722007
				THEN 'Has conc denom unit'
			WHEN typeid = 733725009
				THEN 'Has conc num unit'
			WHEN typeid = 738774007
				THEN 'Modification of'
			WHEN typeid = 766952006
				THEN 'Has count of ing'
					--20190204
			WHEN typeid = 766939001
				THEN 'Plays role'
					--20190823
			WHEN typeid = 13088401000001104
				THEN 'Has route'
			WHEN typeid = 13089101000001102
				THEN 'Has CD category'
			WHEN typeid = 13088501000001100
				THEN 'Has ontological form'
			WHEN typeid = 13088901000001108
				THEN 'Has combi prod ind'
			WHEN typeid = 13088701000001106
				THEN 'Has form continuity'
					--20200312
			WHEN typeid = 13090301000001106
				THEN 'Has add monitor ind'
			WHEN typeid = 13090501000001104
				THEN 'Has AMP restr ind'
			WHEN typeid = 13090201000001102
				THEN 'Paral imprt ind'
			WHEN typeid = 13089701000001101
				THEN 'Has free indicator'
			WHEN typeid = 246514001
				THEN 'Has unit'
			WHEN typeid = 704323007
				THEN 'Has proc duration'
					--20201023
			WHEN typeid = 704325000
				THEN 'Relative to'
			WHEN typeid = 766953001
				THEN 'Has count of act ing'
			WHEN typeid = 860781008
				THEN 'Has prod character'
			WHEN typeid = 860779006
				THEN 'Has prod character'
			WHEN typeid = 246196007
				THEN 'Surf character of'
			WHEN typeid = 836358009
				THEN 'Has dev intend site'
			WHEN typeid = 840562008
				THEN 'Has prod character'
			WHEN typeid = 840560000
				THEN 'Has comp material'
			WHEN typeid = 827081001
				THEN 'Has filling'
					--January 2022
			WHEN typeid = 1148967007
				THEN 'Has coating material'
			WHEN typeid = 1148969005
				THEN 'Has absorbability'
			WHEN typeid = 1003703000
				THEN 'Process extends to'
			WHEN typeid = 1149366004
				THEN 'Has strength'
			WHEN typeid = 1148968002
				THEN 'Has surface texture'
			WHEN typeid = 1148965004
				THEN 'Is sterile'
			WHEN typeid = 1149367008
				THEN 'Has targ population'
					-- August 2023
			WHEN typeid = 1003735000
				THEN 'Process acts on'
			WHEN typeid = 288556008
				THEN 'Before'
			WHEN typeid = 704320005
				THEN 'Towards'
			ELSE term --'non-existing'
			END AS relationship_id,
       (SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'SNOMED'
			) AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM attr_rel
	) sn
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id);

--check for non-existing relationships
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;
--SELECT relationship_id FROM concept_relationship_stage EXCEPT SELECT relationship_id FROM relationship;

--10. Add replacement relationships. They are handled in a different SNOMED table
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

SELECT DISTINCT sn.concept_code_1,
	sn.concept_code_2,
	'SNOMED',
	'SNOMED',
	sn.relationship_id,
	TO_DATE(sn.effectivestart, 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM (
	SELECT sc.referencedcomponentid::TEXT AS concept_code_1,
		sc.targetcomponent::TEXT AS concept_code_2,
		sc.effectivetime AS effectivestart,
		CASE refsetid
			WHEN 900000000000526001
				THEN 'Concept replaced by'
			WHEN 900000000000523009
				THEN 'Concept poss_eq to'
			WHEN 900000000000528000
				THEN 'Concept was_a to'
			WHEN 900000000000527005
				THEN 'Concept same_as to'
			WHEN 900000000000530003
				THEN 'Concept alt_to to'
			END AS relationship_id,
		refsetid,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC,
				sc.id DESC --same as of AVOF-650
			) rn,
		ROW_NUMBER() OVER (
			PARTITION BY sc.referencedcomponentid, sc.targetcomponent, sc.moduleid ORDER BY TO_DATE(sc.effectivetime, 'YYYYMMDD') DESC) AS recent_status, --recent status of the relationship. To be used with 'active' field
		active
	FROM sources.der2_crefset_assreffull_merged sc
	WHERE sc.refsetid IN (
			900000000000526001,
			900000000000523009,
			900000000000528000,
			900000000000527005,
			900000000000530003
			)
            AND sc.moduleid not in (
                999000021000001108, --SNOMED CT United Kingdom drug extension reference set module
                999000011000001104  --SNOMED CT United Kingdom drug extension module
            )
	) sn
LEFT JOIN concept_stage cs ON -- for valid_end_date
	cs.concept_code = sn.concept_code_1
	AND cs.invalid_reason IS NOT NULL
JOIN concept_stage cs2 ON
	cs2.concept_code = sn.concept_code_2
WHERE (
		(
			--Bring all Concept poss_eq to concept_relationship table and do not build new Maps to based on them
			sn.refsetid = '900000000000523009'
			AND sn.rn >= 1
			)
		OR sn.rn = 1
		)
	AND sn.active = 1
	AND sn.recent_status = 1    --no row with the same target concept, but more recent relationship with active = 0
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = sn.concept_code_1
			AND crs.concept_code_2 = sn.concept_code_2
			AND crs.relationship_id = sn.relationship_id
		);

--10.1 Sometimes concept are back from U to fresh, we need to deprecate our replacement mappings
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
SELECT cs.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	cr.relationship_id,
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM concept_stage cs
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
JOIN concept c1 ON c1.concept_code = cs.concept_code
	AND c1.vocabulary_id = cs.vocabulary_id
JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
	AND cr.invalid_reason IS NULL
	AND cr.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE cs.invalid_reason IS NULL
	AND (
		c1.invalid_reason = 'U'
		OR c1.invalid_reason = 'D'
		)
	AND cs.vocabulary_id = 'SNOMED'
	AND crs.concept_code_1 IS NULL;

--same as above, but for 'Maps to' (we need to add the manual deprecation for proper work of the VOCABULARY_PACK.AddFreshMAPSTO)
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
SELECT c1.concept_code,
	c2.concept_code,
	'SNOMED' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Maps to',
	cr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM concept_relationship cr
JOIN concept c1 ON c1.concept_id = cr.concept_id_1
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = c1.concept_code
			AND crs_int.vocabulary_id_1 = c1.vocabulary_id
			AND crs_int.concept_code_2 = c2.concept_code
			AND crs_int.vocabulary_id_2 = c2.vocabulary_id
			AND crs_int.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept poss_eq to',
				'Concept was_a to'
				)
			AND crs_int.invalid_reason = 'D'
		);

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

--delete records that do not exist in the concept and concept_stage
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		LEFT JOIN concept c1 ON c1.concept_code = crs_int.concept_code_1
			AND c1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs_int.concept_code_1
			AND cs1.vocabulary_id = crs_int.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = crs_int.concept_code_2
			AND c2.vocabulary_id = crs_int.vocabulary_id_2
		LEFT JOIN concept_stage cs2 ON cs2.concept_code = crs_int.concept_code_2
			AND cs2.vocabulary_id = crs_int.vocabulary_id_2
		WHERE (
				(
					c1.concept_code IS NULL
					AND cs1.concept_code IS NULL
					)
				OR (
					c2.concept_code IS NULL
					AND cs2.concept_code IS NULL
					)
				)
			AND crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
		);

ANALYZE concept_relationship_stage;

--10.2. Update invalid reason for concepts with replacements to 'U', to ensure we keep correct date
UPDATE concept_stage cs
SET invalid_reason = 'U',
	valid_end_date = LEAST(
			cs.valid_end_date,
			crs.valid_start_date,
			(SELECT latest_update
				FROM vocabulary v
				WHERE v.vocabulary_id = 'SNOMED'))
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept was_a to'
		)
	AND crs.invalid_reason IS NULL;

--10.3. Update invalid reason for concepts with 'Concept poss_eq to' relationships. They are no longer considered replacement relationships.
UPDATE concept_stage cs
SET invalid_reason = 'D',
    valid_end_date = LEAST(
			crs.valid_start_date,
			(SELECT latest_update - 1
				FROM vocabulary v
				WHERE v.vocabulary_id = 'SNOMED'))
FROM concept_relationship_stage crs
WHERE crs.concept_code_1 = cs.concept_code
	AND crs.relationship_id = 'Concept poss_eq to'
	AND crs.invalid_reason IS NULL
	AND cs.invalid_reason IS NULL;

--10.4. Update valid_end_date to latest_update if there is a discrepancy after last point
UPDATE concept_stage cs
SET valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'
		)
WHERE invalid_reason = 'U'
	AND valid_end_date = TO_DATE('20991231', 'yyyymmdd');

--11. Inherit concept class for updated concepts from mapping target -- some of them never had hierarchy tags to extract them
UPDATE concept_stage cs
SET concept_class_id = x.concept_class_id
FROM concept_relationship_stage r,
	concept_stage x
WHERE r.concept_code_1 = cs.concept_code
	AND r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
	AND r.concept_code_2 = x.concept_code
	AND cs.concept_class_id = 'Undefined';

-- 12. Build domains, preassign all them with "Not assigned"
DROP TABLE IF EXISTS domain_snomed;
CREATE UNLOGGED TABLE domain_snomed AS
SELECT concept_code::BIGINT,
	CAST('Not assigned' AS VARCHAR(20)) AS domain_id
FROM concept_stage
WHERE vocabulary_id = 'SNOMED';

--13. Assign domains to the concepts according to their concept_classes
UPDATE domain_snomed d
SET domain_id = i.domain_id
FROM (
	SELECT CASE c.concept_class_id
			WHEN 'Admin Concept'
				THEN 'Type Concept'
			WHEN 'Attribute'
				THEN 'Observation'
			WHEN 'Biological Function'
				THEN 'Observation'
			WHEN 'Body Structure'
				THEN 'Spec Anatomic Site'
			WHEN 'Clinical Drug'
				THEN 'Drug'
			WHEN 'Clinical Drug Form'
				THEN 'Drug'
			WHEN 'Clinical Finding'
				THEN 'Observation'
			WHEN 'Context-dependent'
				THEN 'Observation'
			 WHEN 'Disorder'
				THEN 'Condition'
			WHEN 'Disposition'
				THEN 'Observation'
			WHEN 'Dose Form'
				THEN 'Drug'
			WHEN 'Event'
				THEN 'Observation'
			WHEN 'Inactive Concept'
				THEN 'Metadata'
			WHEN 'Linkage Assertion'
				THEN 'Relationship'
			WHEN 'Linkage Concept'
				THEN 'Relationship'
			WHEN 'Location'
				THEN 'Observation'
			WHEN 'Model Comp'
				THEN 'Metadata'
			WHEN 'Morph Abnormality'
				THEN 'Observation'
			WHEN 'Namespace Concept'
				THEN 'Metadata'
			WHEN 'Navi Concept'
				THEN 'Metadata'
			WHEN 'Observable Entity'
				THEN 'Observation'
			WHEN 'Organism'
				THEN 'Observation'
			WHEN 'Patient Status'
				THEN 'Observation'
			WHEN 'Physical Force'
				THEN 'Observation'
			WHEN 'Pharma/Biol Product'
				THEN 'Drug'
			WHEN 'Physical Force'
				THEN 'Observation'
			WHEN 'Physical Object'
				THEN 'Device'
			WHEN 'Procedure'
				THEN 'Procedure'
			WHEN 'Qualifier Value'
				THEN 'Observation'
			WHEN 'Record Artifact'
				THEN 'Type Concept'
			WHEN 'Social Context'
				THEN 'Observation'
			WHEN 'Special Concept'
				THEN 'Metadata'
			WHEN 'Specimen'
				THEN 'Specimen'
			WHEN 'Staging / Scales'
				THEN 'Measurement' -- domain changed
			WHEN 'Substance'
				THEN 'Observation' -- -- domain changed
			ELSE 'Observation'
			END AS domain_id,
		c.concept_code::BIGINT
	FROM concept_stage c
	WHERE c.VOCABULARY_ID = 'SNOMED'
	) i
WHERE i.concept_code = d.concept_code;

--14 All concepts mapped to Rx/RxE/CVX should be drugs
WITH a AS (
	SELECT concept_code_1 AS concept_code
	FROM concept_relationship_manual crm
		JOIN concept_stage cs ON cs.concept_code = crm.concept_code_1
	WHERE relationship_id = 'Maps to'
		AND vocabulary_id_1 = 'SNOMED'
		AND vocabulary_id_2 IN (
			'RxNorm',
			'RxNorm Extension',
			'CVX')
		AND crm.invalid_reason IS NULL
		AND cs.concept_class_id = 'Substance'

	UNION

	SELECT c.concept_code
	FROM concept_relationship cr
		JOIN concept c ON c.concept_id = cr.concept_id_1
		JOIN concept cc ON cc.concept_id = cr.concept_id_2
	WHERE c.vocabulary_id = 'SNOMED'
		AND cc.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension',
			'CVX')
		AND c.concept_class_id = 'Substance'
		AND cr.relationship_id = 'Maps to'
		AND cr.invalid_reason IS NULL
)

UPDATE domain_snomed d
SET domain_id = 'Drug'
FROM a
WHERE d.concept_code::TEXT = a.concept_code
;

--15. Start building the hierarchy for propagating domain_ids from top to bottom
DROP TABLE IF EXISTS snomed_ancestor;
CREATE UNLOGGED TABLE snomed_ancestor AS
	WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, levels_of_separation, full_path) AS (
		SELECT ancestor_concept_code,
			descendant_concept_code,
			ancestor_concept_code AS root_ancestor_concept_code,
			levels_of_separation,
			ARRAY [descendant_concept_code::TEXT] AS full_path
		FROM concepts

		UNION ALL

		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.levels_of_separation + c.levels_of_separation AS levels_of_separation,
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code::TEXT <> ALL (full_path)
		),
	concepts AS (
		SELECT crs.concept_code_2 AS ancestor_concept_code,
			crs.concept_code_1 AS descendant_concept_code,
			1 AS levels_of_separation
		FROM concept_relationship_stage crs
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'Is a'
			AND crs.vocabulary_id_1 = 'SNOMED'
			AND crs.vocabulary_id_2 = 'SNOMED'

		UNION

		SELECT cc.concept_code AS ancestor_concept_code,
		       c.concept_code AS descendant_concept_code,
		       1 AS levels_of_separation
		FROM concept_relationship cr
		JOIN concept c on c.concept_id = cr.concept_id_1
		JOIN concept cc on cc.concept_id = cr.concept_id_2
		WHERE cr.relationship_id = 'Is a'
		AND cr.invalid_reason IS NULL
		AND c.vocabulary_id = 'SNOMED'
		AND cc.vocabulary_id = 'SNOMED')
	SELECT DISTINCT hc.root_ancestor_concept_code::BIGINT AS ancestor_concept_code,
		hc.descendant_concept_code::BIGINT,
		MIN(hc.levels_of_separation) AS min_levels_of_separation
	FROM hierarchy_concepts hc
	JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
		AND cs1.vocabulary_id = 'SNOMED'
	JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code
		AND cs2.vocabulary_id = 'SNOMED'
		AND cs2.concept_class_id = cs1.concept_class_id
	GROUP BY hc.root_ancestor_concept_code,
		hc.descendant_concept_code;

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);
ANALYZE snomed_ancestor;

--15.1. Append deprecated concepts that have mappings or replacement links as extensions of their mapping target
INSERT INTO snomed_ancestor (
	ancestor_concept_code,
	descendant_concept_code,
	min_levels_of_separation
	)
SELECT a.ancestor_concept_code,
	s1.concept_code_1::BIGINT,
	MIN(a.min_levels_of_separation)
FROM (SELECT r.concept_code_1,
             r.concept_code_2
             from concept_stage s1
JOIN concept_relationship_stage r ON s1.invalid_reason IS NOT NULL
	AND s1.concept_code = r.concept_code_1
	AND r.vocabulary_id_1 = 'SNOMED'
	AND r.vocabulary_id_2 = 'SNOMED'
	AND r.relationship_id IN ('Maps to', 'Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
	AND r.invalid_reason IS NULL

UNION

SELECT c.concept_code AS concept_code_1,
       cc.concept_code AS concept_code_2
FROM concept c
       JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id
       JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE c.vocabulary_id = 'SNOMED'
AND cc.vocabulary_id = 'SNOMED'
AND cr.relationship_id in ('Maps to', 'Concept replaced by', 'Concept same_as to', 'Concept alt_to to', 'Concept was_a to')
AND cr.invalid_reason IS NULL) s1
JOIN snomed_ancestor a ON s1.concept_code_2 = a.descendant_concept_code::TEXT
JOIN concept_stage cs ON cs.concept_code = s1.concept_code_1
AND cs.vocabulary_id = 'SNOMED'
JOIN concept_stage ccs ON ccs.concept_code = s1.concept_code_2
AND ccs.vocabulary_id = 'SNOMED'
WHERE NOT EXISTS (
		SELECT
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code::TEXT = s1.concept_code_1
		)
AND ccs.concept_class_id = cs.concept_class_id
GROUP BY ancestor_concept_code, s1.concept_code_1;

ANALYZE snomed_ancestor;

--15.2. For deprecated concepts without mappings, take the latest 116680003 'Is a' relationship to active concept
INSERT INTO snomed_ancestor (
	ancestor_concept_code,
	descendant_concept_code,
	min_levels_of_separation
	)
SELECT a.ancestor_concept_code,
	m.sourceid,
	a.min_levels_of_separation
FROM concept_stage s1
JOIN (
	SELECT DISTINCT r.sourceid,
		FIRST_VALUE(r.destinationid) OVER (
			PARTITION BY r.sourceid,
			r.effectivetime
			) AS destinationid, --pick one parent at random
		r.effectivetime,
		max(r.effectivetime) OVER (PARTITION BY r.sourceid) AS maxeffectivetime
	FROM sources.sct2_rela_full_merged r
	JOIN concept_stage x ON x.concept_code = r.destinationid::TEXT
		AND x.invalid_reason IS NULL
	WHERE
	    r.typeid = 116680003 -- Is a
    AND r.moduleid NOT IN (
            999000021000001108, --SNOMED CT United Kingdom drug extension reference set module
            999000011000001104  --SNOMED CT United Kingdom drug extension module
        )
	) m ON m.sourceid::TEXT = s1.concept_code
	AND m.effectivetime = m.maxeffectivetime
JOIN snomed_ancestor a ON m.destinationid = a.descendant_concept_code
WHERE s1.invalid_reason IS NOT NULL
	AND NOT EXISTS (
		SELECT
		FROM snomed_ancestor x
		WHERE x.descendant_concept_code = m.sourceid
		);

--16. Create domain_id
--16.1. Create and populate table with "Peaks" = ancestors of records that are all of the same domain
DO $_$
BEGIN
	PERFORM dev_snomed.AddPeaks();
END $_$;

--16.2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
--Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
--The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
--This could cause trouble if a parallel fork happens at the same height, but it is resolved by domain precedence.
UPDATE peak p
SET ranked = (
		SELECT rnk
		FROM (
			SELECT ranked.pd AS peak_code,
				COUNT(*) + 1 AS rnk -- +1 so the top most who have an ancestor are ranked 2, and the ancestor can be ranked 1 (see below)
			FROM (
				SELECT DISTINCT pa.peak_code AS pa,
					pd.peak_code AS pd
				FROM peak pa,
					snomed_ancestor a,
					peak pd
				WHERE a.ancestor_concept_code = pa.peak_code
					AND a.descendant_concept_code = pd.peak_code
					AND pa.levels_down IS NULL
					AND pa.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
					AND pd.valid_end_date = TO_DATE('20991231', 'YYYYMMDD') --consider only active peaks
				) ranked
			GROUP BY ranked.pd
			) r
		WHERE r.peak_code = p.peak_code
		)
WHERE valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--rank only active peaks

--For those that have no ancestors, the rank is 1
UPDATE peak
SET ranked = 1
WHERE ranked IS NULL
	AND valid_end_date = TO_DATE('20991231', 'YYYYMMDD');--rank only active peaks

--16.3. Pass out domain_ids
--Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
--Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT ON (sa.descendant_concept_code) p.peak_domain_id,
		sa.descendant_concept_code
	FROM snomed_ancestor sa
	JOIN peak p ON p.peak_code = sa.ancestor_concept_code
		AND p.ranked IS NOT NULL
	WHERE p.levels_down >= sa.min_levels_of_separation
		OR p.levels_down IS NULL
	ORDER BY sa.descendant_concept_code,
		p.ranked DESC,
		sa.min_levels_of_separation,
		-- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
		CASE peak_domain_id WHEN 'Condition'
			THEN 1
		WHEN 'Measurement'
			THEN 2
		WHEN 'Procedure'
			THEN 3
		WHEN 'Device'
			THEN 4
		WHEN 'Provider'
			THEN 5
		WHEN 'Drug'
			THEN 6
		WHEN 'Gender'
			THEN 7
		WHEN 'Race'
			THEN 8
		ELSE
			10
		END, -- everything else is Observation
		p.peak_domain_id
	) i
WHERE d.concept_code = i.descendant_concept_code;

--Assign domains of peaks themselves (snomed_ancestor doesn't include self-descendants)
UPDATE domain_snomed d
SET domain_id = i.peak_domain_id
FROM (
	SELECT DISTINCT peak_code,
		-- if there are several records for 1 peak, use the following ORDER: levels_down = 0 > 1 ... x > NULL
		FIRST_VALUE(peak_domain_id) OVER (
			PARTITION BY peak_code ORDER BY levels_down ASC NULLS LAST
			) AS peak_domain_id
	FROM peak
	WHERE ranked IS NOT NULL --consider active peaks only
	) i
WHERE i.peak_code = d.concept_code;

--Update top guy
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = 138875005;

--16.4. Update concept_stage from newly created domains.
UPDATE concept_stage c
SET domain_id = i.domain_id
FROM (
	SELECT d.domain_id,
		d.concept_code
	FROM domain_snomed d
	) i
WHERE c.vocabulary_id = 'SNOMED'
	AND i.concept_code::TEXT = c.concept_code;

--17. Make manual changes according to rules
--Manual correction
---Assign Measurement domain to all scores:
UPDATE concept_stage
SET domain_id = 'Measurement'
WHERE concept_name ~* 'score'
	AND concept_class_id = 'Observable Entity'
	AND vocabulary_id = 'SNOMED';

--Trim word 'route' from the concepts in 'Route' domain [AVOC-4087]
UPDATE concept_stage
SET concept_name = TRIM(TRAILING ' route' FROM concept_name)
WHERE concept_name ~* '\sroute$'
AND domain_id = 'Route';

--Fix navigational concepts
UPDATE concept_stage
SET domain_id = CASE concept_class_id
		WHEN 'Admin Concept'
			THEN 'Type Concept'
		WHEN 'Attribute'
			THEN 'Observation'
		WHEN 'Body Structure'
			THEN 'Spec Anatomic Site'
		WHEN 'Clinical Finding'
			THEN 'Condition'
		WHEN 'Context-dependent'
			THEN 'Observation'
		WHEN 'Event'
			THEN 'Observation'
		WHEN 'Inactive Concept'
			THEN 'Metadata'
		WHEN 'Linkage Assertion'
			THEN 'Relationship'
		WHEN 'Location'
			THEN 'Observation'
		WHEN 'Model Comp'
			THEN 'Metadata'
		WHEN 'Morph Abnormality'
			THEN 'Observation'
		WHEN 'Namespace Concept'
			THEN 'Metadata'
		WHEN 'Navi Concept'
			THEN 'Metadata'
		WHEN 'Observable Entity'
			THEN 'Observation'
		WHEN 'Organism'
			THEN 'Observation'
		WHEN 'Pharma/Biol Product'
			THEN 'Drug'
		WHEN 'Physical Force'
			THEN 'Observation'
		WHEN 'Physical Object'
			THEN 'Device'
		WHEN 'Procedure'
			THEN 'Procedure'
		WHEN 'Qualifier Value'
			THEN 'Observation'
		WHEN 'Record Artifact'
			THEN 'Type Concept'
		WHEN 'Social Context'
			THEN 'Observation'
		WHEN 'Special Concept'
			THEN 'Metadata'
		WHEN 'Specimen'
			THEN 'Specimen'
		WHEN 'Staging / Scales'
			THEN 'Observation'
		WHEN 'Substance'
			THEN 'Observation'
		ELSE 'Observation'
		END
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 363743006 -- Navigational Concept, contains all sorts of orphan codes
		);

--18. Set standard_concept based on validity and domain_id
UPDATE concept_stage cs
SET standard_concept = CASE domain_id
		WHEN 'Drug'
			THEN NULL -- Drugs are RxNorm
		WHEN 'Gender'
			THEN NULL -- Gender are OMOP
		WHEN 'Metadata'
			THEN NULL -- Not used in CDM
		WHEN 'Race'
			THEN NULL -- Race are CDC
		WHEN 'Provider'
			THEN NULL -- got own Provider domain
		WHEN 'Visit'
			THEN NULL -- got own Visit domain
		WHEN 'Type Concept'
			THEN NULL -- got own Type Concept domain
		WHEN 'Unit'
			THEN NULL -- Units are UCUM
		ELSE 'S'
		END
WHERE cs.invalid_reason IS NULL
	AND --if the concept has outside mapping from manual table, do not update it's Standard status
	NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.invalid_reason IS NULL
			AND (
				crs_int.concept_code_1,
				crs_int.vocabulary_id_1
				) <> (
				crs_int.concept_code_2,
				crs_int.vocabulary_id_2
				)
			AND crs_int.concept_code_1 = cs.concept_code
			AND crs_int.relationship_id = 'Maps to'
			AND crs_int.vocabulary_id_1 = 'SNOMED'
		);

--18.1. De-standardize navigational concepts
UPDATE concept_stage
SET standard_concept = NULL
WHERE vocabulary_id = 'SNOMED'
	AND concept_code IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 363743006 -- Navigational Concept
		);

--18.2. Make those Obsolete routes non-standard
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_name LIKE 'Obsolete%'
	AND domain_id = 'Route';

--18.3 Make domain 'Geography' non-standard, except countries:
UPDATE concept_stage
SET standard_concept = NULL
WHERE domain_id = 'Geography'
AND concept_code NOT IN (
		SELECT descendant_concept_code::TEXT
		FROM snomed_ancestor
		WHERE ancestor_concept_code = 223369002 -- Country
		);

--18.4 Make procedures with the context = 'Done' non-standard:
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS(
       SELECT 1 FROM concept_relationship_stage crs
       WHERE crs.concept_code_1 = cs.concept_code
		AND crs.relationship_id = 'Has proc context'
		AND crs.concept_code_2 = '385658003'
		AND crs.vocabulary_id_2 = 'SNOMED'
);

--18.5 Make certain hierarchical branches non-standard:
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS(
       SELECT 1 FROM snomed_ancestor sa
       WHERE sa.descendant_concept_code::TEXT = cs.concept_code
       AND sa.ancestor_concept_code::TEXT = '373060007' -- Device status
);

--18.6 Make certain concept classes non-standard:
UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_class_id IN ('Attribute', 'Physical Force', 'Physical Object')
AND domain_id NOT IN ('Device');

--18.7. Add 'Maps to' relations to concepts that are duplicating between different SNOMED editions
--https://github.com/OHDSI/Vocabulary-v5.0/issues/431
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
WITH concept_status AS (
		SELECT *
		FROM (
			SELECT id AS conceptid,
				active,
				statusid,
				moduleid,
				effectivetime,
				rank() OVER (
					PARTITION BY id ORDER BY effectivetime DESC
					) AS rn
			FROM sources.sct2_concept_full_merged c
			WHERE c.moduleid NOT IN (
                    999000021000001108, --SNOMED CT United Kingdom drug extension reference set module
                    999000011000001104 --SNOMED CT United Kingdom drug extension module
                    )
			) AS s0
		WHERE rn = 1

		),
	concept_fsn AS (
		SELECT *
		FROM (
			SELECT d.conceptid,
				d.term AS fsn,
				a.active,
				a.statusid,
				a.moduleid,
				a.effectivetime,
				rank() OVER (
					PARTITION BY d.conceptid ORDER BY d.effectivetime DESC
					) AS rn
			FROM sources.sct2_desc_full_merged d
			JOIN concept_status a ON a.conceptid = d.conceptid
				AND a.active = 1
			WHERE
                    d.active = 1
                AND d.typeid = 900000000000003001 -- FSN
                AND d.moduleid NOT IN (
                    999000021000001108, --SNOMED CT United Kingdom drug extension reference set module
                    999000011000001105 --SNOMED CT United Kingdom drug extension module
                )
			) AS s0
		WHERE rn = 1
		),
	dupes AS (
		SELECT fsn
		FROM concept_fsn
		GROUP BY fsn
		HAVING COUNT(conceptid) > 1
		),
	preferred_code AS
	--1. International concept over local
	--2. Defined concept over primitive
	--3. Newest concept
	(
		SELECT d.fsn,
			c.conceptid,
			first_value(c.conceptid) OVER (
				PARTITION BY d.fsn ORDER BY CASE c.moduleid
						WHEN 900000000000207008 -- Core (International)
							THEN 1
						ELSE 2
						END,
					CASE c.statusid
						WHEN 900000000000073002 --fully defined
							THEN 1
						ELSE 2
						END,
					effectivetime DESC
				) AS replacementid
		FROM dupes d
		JOIN concept_fsn c ON c.fsn = d.fsn
		)
SELECT p.conceptid::VARCHAR,
	p.replacementid::VARCHAR,
	'SNOMED',
	'SNOMED',
	'Maps to',
	(SELECT latest_update -1
		FROM vocabulary
		WHERE vocabulary_id = 'SNOMED'),
	TO_DATE('20991231', 'yyyymmdd')
FROM preferred_code p
JOIN concept_stage c ON c.concept_code = p.replacementid::VARCHAR
	AND c.standard_concept IS NOT NULL
WHERE p.conceptid <> p.replacementid
AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = p.conceptid::VARCHAR
			AND crs_int.vocabulary_id_1='SNOMED'
			AND crs_int.concept_code_2 = p.replacementid::VARCHAR
			AND crs_int.vocabulary_id_2='SNOMED'
			AND crs_int.relationship_id = 'Maps to'
		);

--19. Upload all replacement links from base tables to create 'Maps to' links according to them:
---Remove after refresh.
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
SELECT DISTINCT c.concept_code,
	cc.concept_code,
	c.vocabulary_id,
	cc.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	cr.valid_end_date,
	cr.invalid_reason
FROM concept_relationship cr
JOIN concept c on c.concept_id = cr.concept_id_1
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE c.vocabulary_id = 'SNOMED'
AND cc.vocabulary_id = 'SNOMED'
AND cr.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept was_a to'
				)
AND cr.invalid_reason IS NULL
AND NOT EXISTS(
	SELECT 1 --if a concept already has an active replacement link in crs
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c.concept_code
			AND crs.relationship_id IN (
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept was_a to'
				)
			AND crs.vocabulary_id_1 = c.vocabulary_id
			AND crs.invalid_reason IS NULL
)
AND NOT EXISTS(
	SELECT 1 -- if the link from cr has been deprecated earlier in the course of load_stage
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c.concept_code
			AND crs.concept_code_2 = cc.concept_code
			AND crs.relationship_id = cr.relationship_id
			AND crs.vocabulary_id_1 = c.vocabulary_id
			AND crs.vocabulary_id_2 = cc.vocabulary_id
			AND crs.invalid_reason IS NOT NULL
)
AND NOT EXISTS(
	SELECT 1 -- if a concept has an active 'Maps to' link
		FROM concept_relationship cr1
		WHERE cr1.concept_id_1 = cr.concept_id_1
       AND cr1.relationship_id = 'Maps to'
       AND cr1.invalid_reason IS NULL
);

--20. Implement manual changes:

-- Append manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

-- Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--21. Make concepts non standard if they have a 'Maps to' relationship
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.relationship_id = 'Maps to'
			AND crs.invalid_reason IS NULL
			AND cs.concept_code = crs.concept_code_1
			AND cs.vocabulary_id = crs.vocabulary_id_1
		)
	AND cs.standard_concept = 'S'
	AND NOT EXISTS(
		SELECT 1 FROM snomed_ancestor sa
			WHERE sa.descendant_concept_code::text = cs.concept_code
			AND sa.ancestor_concept_code = 411115002 -- Exclude drug-device combinations - should be standard and mapped to drugs
);

--22. Make concepts non standard if they represent no information
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE cs.concept_code IN (
		'1321581000000100', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result unknown
		'1321641000000107', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result unknown
		'1321651000000105', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) immunity status unknown
		'1321691000000102', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result unknown
		'1321781000000107', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result unknown
		'1322821000000105', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result unknown
		'1322911000000106', --SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result unknown
		'442754001', --Inconclusive evaluation finding
		'384311000000106', --Inconclusive laboratory finding
		'352741000000109', --Indeterminate laboratory finding
		'85607003', --Morphology unknown
		'930901000000104', --Unreliable laboratory result
		'384281000000108', --Unsatisfactory laboratory analysis
		'441934005' --Measurement procedure result present
		)
	AND cs.standard_concept = 'S';

--23. Clean up
DROP TABLE peak;
DROP TABLE domain_snomed;
DROP TABLE snomed_ancestor;
DROP VIEW module_date;

--24. Need to check domains before running the generic_update
/*temporary disabled for later use
DO $_$
DO $_$
DECLARE
	z INT;
BEGIN
    SELECT COUNT (*)
      INTO z
      FROM concept_stage cs JOIN concept c USING (concept_code)
     WHERE c.vocabulary_id = 'SNOMED' AND cs.domain_id <> c.domain_id;

    IF z <> 0
    THEN
        RAISE EXCEPTION 'Please check domain_ids for SNOMED';
    END IF;
END $_$;*/

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

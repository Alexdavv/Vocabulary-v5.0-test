-- Adding new relationsip
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Reference to variant',
	pRelationship_id			=>'Has variant',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Variant of',
	pRelationship_name_rev		=>'Variant refer to concept',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

--Adding new vocabulary 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'OncoKB',
	pVocabulary_name		=> 'Oncology Knowledge Base (MSK)',
	pVocabulary_reference	=> 'https://www.oncokb.org/',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;


-- Run for update concept codes before run staging tables
-- Concept codes should contain version in refseq
update concept 
set concept_code = new_code
from dev_dkaduk.upd_concept_3 
where concept.concept_id = upd_concept_3.concept_id
;
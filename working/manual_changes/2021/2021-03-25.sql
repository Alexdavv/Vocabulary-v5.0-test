--Add new specific relationships for HemOnc (including external to RxN/E)

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has antibody-drug conjugate (HemOnc)',
	pRelationship_id			=>'Has AB-drug cjgt',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Antibody-drug conjugate of (HemOnc)',
	pReverse_relationship_id		=>'AB-drug cjgt of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has antibody-drug conjugate - RxNorm (HemOnc)',
	pRelationship_id			=>'Has ADC Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Antibody-drug conjugate of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx ADC of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has FDA labeling (HemOnc)',
	pRelationship_id			=>'Has FDA labeling',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'FDA labeling of (HemOnc)',
	pReverse_relationship_id		=>'FDA labeling of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has cytotoxic chemotherapy (HemOnc)',
	pRelationship_id			=>'Has cytotoxic chemo',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Cytotoxic chemotherapy of (HemOnc)',
	pReverse_relationship_id		=>'Cytotoxic chemo of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has cytotoxic chemotherapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has chemo Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Cytotoxic chemotherapy of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Chemo RX of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has endocrine therapy (HemOnc)',
	pRelationship_id			=>'Has endocrine tx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Endocrine therapy of (HemOnc)',
	pReverse_relationship_id		=>'Endocrine tx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has endocrine therapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has endo Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Endocrine therapy of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx endo of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has immunotherapy (HemOnc)',
	pRelationship_id			=>'Has immunotherapy',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Immunotherapy of (HemOnc)',
	pReverse_relationship_id		=>'Immunotherapy of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has immunotherapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has immuno Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Immunotherapy of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx immuno of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has peptide-drug conjugate (HemOnc)',
	pRelationship_id			=>'Has pept-drug cjgt',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Peptide-drug conjugate of (HemOnc)',
	pReverse_relationship_id		=>'Pept-drug cjgt of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has radioconjugate (HemOnc)',
	pRelationship_id			=>'Has radioconjugate',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Radioconjugate of (HemOnc)',
	pReverse_relationship_id		=>'Radioconjugate of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has radioconjugate - RxNorm (HemOnc)',
	pRelationship_id			=>'Has radiocjgt Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Radioconjugate of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx radiocjgt of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has radiotherapy (HemOnc)',
	pRelationship_id			=>'Has radiotherapy',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Radiotherapy of (HemOnc)',
	pReverse_relationship_id		=>'Radiotherapy of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has radiotherapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has radio Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Radiotherapy of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx radio of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has targeted therapy (HemOnc)',
	pRelationship_id			=>'Has targeted therapy',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Targeted therapy of (HemOnc)',
	pReverse_relationship_id		=>'Targeted therapy of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has targeted therapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has targeted Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Targeted therapy of - RxNorm (HemOnc)',
	pReverse_relationship_id		=>'Rx targeted of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


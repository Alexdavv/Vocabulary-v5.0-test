/*

OUTDATED

DROP TABLE IF EXISTS fo_product_1_vs_2;
CREATE TABLE fo_product_1_vs_2 AS
SELECT *
FROM SOURCES.AUS_FO_PRODUCT
UNION
SELECT fo_prd_id,
	prd_eid,
	prd_name,
	mast_prd_name,
	int_brand_name,
	dosage,
	dosage_as_text,
	unit,
	dosage2,
	dosage2_as_text,
	unit2,
	dosage3,
	dosage3_as_text,
	unit3,
	nbdose,
	nbdose_as_text,
	galenic,
	nbdose2,
	nbdose2_as_text,
	galenic2,
	is_prd_refundable,
	prd_refundable_rate,
	prd_price,
	canceled_dat,
	creation_dat,
	manufacturer_name,
	is_generic,
	is_hosp,
	prd_start_dat,
	prd_end_dat,
	regrouping_code,
	eph_code,
	eph_name,
	eph_type,
	eph_state,
	mol_eid,
	mol_name,
	atccode,
	atc_name,
	atc_mol,
	atc_type,
	atc_state,
	bnf_eid,
	bnf_name,
	version,
	updated,
	min_dosage_by_day_ref,
	max_dosage_by_day_ref,
	gal_id,
	gal_id2,
	first_prd_date,
	first_pre_tra_id,
	first_tra_date,
	ddl_id,
	ddl_lbl,
	prd_vat,
	regrouping_code_2,
	gmp_id,
	prd_id_dc
FROM SOURCES.AUS_FO_PRODUCT_p2;

DROP TABLE IF EXISTS drug_mapping_1_vs_2;
CREATE TABLE drug_mapping_1_vs_2 AS
SELECT *
FROM SOURCES.AUS_DRUG_MAPPING
UNION
SELECT prd_eid,
	lpdoriginalname,
	fcc,
	description,
	manufacturer,
	ephmra_atc_code,
	nfc_code,
	prd_name,
	mast_prd_name,
	who_atc_eid,
	prd_dosage,
	unit,
	prd_dosage2,
	unit_id2,
	mol_name
FROM SOURCES.AUS_DRUG_MAPPING_p2;
 */
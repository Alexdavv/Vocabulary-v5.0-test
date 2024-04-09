--Sources May 2022
DROP TABLE IF EXISTS SOURCES.lpd_aus_fo_product_4;
CREATE TABLE lpd_aus_fo_product_4
(
    fo_prd_id             text,
    prd_eid               text,
    prd_name              text,
    mast_prd_name         text,
    int_brand_name        text,
    dosage                text,
    unit                  text,
    dosage2               text,
    unit2                 text,
    dosage3               text,
    unit3                 text,
    nbdose                text,
    galenic               text,
    nbdose2               text,
    galenic2              text,
    is_prd_refundable     text,
    prd_refundable_rate   text,
    prd_price             text,
    canceled_dat          date,
    creation_dat          date,
    manufacturer_name     text,
    is_generic            text,
    is_hosp               text,
    prd_start_dat         date,
    prd_end_dat           date,
    regrouping_code       text,
    eph_code              text,
    eph_name              text,
    eph_type              text,
    eph_state             text,
    mol_eid               text,
    mol_name              text,
    atccode               text,
    atc_name              text,
    atc_mol               text,
    atc_type              text,
    atc_state             text,
    bnf_eid               text,
    bnf_name              text,
    version               text,
    updated               date,
    min_dosage_by_day_ref text,
    max_dosage_by_day_ref text,
    gal_id                text,
    gal_id2               text,
    first_prd_date        date,
    first_pre_tra_id      text,
    first_tra_date        date,
    ddl_id                text,
    ddl_lbl               text,
    prd_vat               text,
    regrouping_code_2     text,
    gmp_id                text,
    prd_id_dc             text
);

DROP TABLE IF EXISTS SOURCES.lpd_aus_drug_mapping_4;
CREATE TABLE lpd_aus_drug_mapping_4
(
    prd_eid         text,
    lpdoriginalname text,
    fcc             text,
    description     text,
    manufacturer    text,
    ephmra_atc_code text,
    nfc_code        text,
    prd_name        text,
    mast_prd_name   text,
    who_atc_eid     text,
    prd_dosage      text,
    unit            text,
    prd_dosage2     text,
    unit_id2        text,
    mol_name        text,
    oot             text
);

/*
DROP TABLE IF EXISTS SOURCES.AUS_FO_PRODUCT;
CREATE TABLE SOURCES.AUS_FO_PRODUCT
(
   FO_PRD_ID              VARCHAR(255),
   PRD_EID                VARCHAR(255),
   PRD_NAME               VARCHAR(255),
   MAST_PRD_NAME          VARCHAR(255),
   INT_BRAND_NAME         VARCHAR(255),
   DOSAGE                 VARCHAR(255),
   DOSAGE_AS_TEXT         VARCHAR(255),
   UNIT                   VARCHAR(255),
   DOSAGE2                VARCHAR(255),
   DOSAGE2_AS_TEXT        VARCHAR(255),
   UNIT2                  VARCHAR(255),
   DOSAGE3                VARCHAR(255),
   DOSAGE3_AS_TEXT        VARCHAR(255),
   UNIT3                  VARCHAR(255),
   NBDOSE                 VARCHAR(255),
   NBDOSE_AS_TEXT         VARCHAR(255),
   GALENIC                VARCHAR(255),
   NBDOSE2                VARCHAR(255),
   NBDOSE2_AS_TEXT        VARCHAR(255),
   GALENIC2               VARCHAR(255),
   IS_PRD_REFUNDABLE      VARCHAR(255),
   PRD_REFUNDABLE_RATE    VARCHAR(255),
   PRD_PRICE              VARCHAR(255),
   CANCELED_DAT           VARCHAR(255),
   CREATION_DAT           VARCHAR(255),
   MANUFACTURER_NAME      VARCHAR(255),
   IS_GENERIC             VARCHAR(255),
   IS_HOSP                VARCHAR(255),
   PRD_START_DAT          VARCHAR(255),
   PRD_END_DAT            VARCHAR(255),
   REGROUPING_CODE        VARCHAR(255),
   EPH_CODE               VARCHAR(255),
   EPH_NAME               VARCHAR(255),
   EPH_TYPE               VARCHAR(255),
   EPH_STATE              VARCHAR(255),
   MOL_EID                VARCHAR(255),
   MOL_NAME               VARCHAR(255),
   ATCCODE                VARCHAR(255),
   ATC_NAME               VARCHAR(255),
   ATC_MOL                VARCHAR(255),
   ATC_TYPE               VARCHAR(255),
   ATC_STATE              VARCHAR(255),
   BNF_EID                VARCHAR(255),
   BNF_NAME               VARCHAR(255),
   VERSION                VARCHAR(255),
   UPDATED                VARCHAR(255),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR(255),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR(255),
   GAL_ID                 VARCHAR(255),
   GAL_ID2                VARCHAR(255),
   FIRST_PRD_DATE         VARCHAR(255),
   FIRST_PRE_TRA_ID       VARCHAR(255),
   FIRST_TRA_DATE         VARCHAR(255),
   DDL_ID                 VARCHAR(255),
   DDL_LBL                VARCHAR(255),
   PRD_VAT                VARCHAR(255),
   REGROUPING_CODE_2      VARCHAR(255),
   GMP_ID                 VARCHAR(255),
   PRD_ID_DC              VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AUS_DRUG_MAPPING;
CREATE TABLE SOURCES.AUS_DRUG_MAPPING
(
   PRD_EID          VARCHAR(255),
   LPDORIGINALNAME  VARCHAR(255),
   FCC              VARCHAR(255),
   DESCRIPTION      VARCHAR(255),
   MANUFACTURER     VARCHAR(255),
   EPHMRA_ATC_CODE  VARCHAR(255),
   NFC_CODE         VARCHAR(255),
   PRD_NAME         VARCHAR(255),
   MAST_PRD_NAME    VARCHAR(255),
   WHO_ATC_EID      VARCHAR(255),
   PRD_DOSAGE       VARCHAR(255),
   UNIT             VARCHAR(255),
   PRD_DOSAGE2      VARCHAR(255),
   UNIT_ID2         VARCHAR(255),
   MOL_NAME         VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AUS_FO_PRODUCT_p2;
CREATE TABLE SOURCES.AUS_FO_PRODUCT_p2
(
   CNT                    VARCHAR(255),
   FO_PRD_ID              VARCHAR(255),
   PRD_EID                VARCHAR(255),
   PRD_NAME               VARCHAR(255),
   MAST_PRD_NAME          VARCHAR(255),
   INT_BRAND_NAME         VARCHAR(255),
   DOSAGE                 VARCHAR(255),
   DOSAGE_AS_TEXT         VARCHAR(255),
   UNIT                   VARCHAR(255),
   DOSAGE2                VARCHAR(255),
   DOSAGE2_AS_TEXT        VARCHAR(255),
   UNIT2                  VARCHAR(255),
   DOSAGE3                VARCHAR(255),
   DOSAGE3_AS_TEXT        VARCHAR(255),
   UNIT3                  VARCHAR(255),
   NBDOSE                 VARCHAR(255),
   NBDOSE_AS_TEXT         VARCHAR(255),
   GALENIC                VARCHAR(255),
   NBDOSE2                VARCHAR(255),
   NBDOSE2_AS_TEXT        VARCHAR(255),
   GALENIC2               VARCHAR(255),
   IS_PRD_REFUNDABLE      VARCHAR(255),
   PRD_REFUNDABLE_RATE    VARCHAR(255),
   PRD_PRICE              VARCHAR(255),
   CANCELED_DAT           VARCHAR(255),
   CREATION_DAT           VARCHAR(255),
   MANUFACTURER_NAME      VARCHAR(255),
   IS_GENERIC             VARCHAR(255),
   IS_HOSP                VARCHAR(255),
   PRD_START_DAT          VARCHAR(255),
   PRD_END_DAT            VARCHAR(255),
   REGROUPING_CODE        VARCHAR(255),
   EPH_CODE               VARCHAR(255),
   EPH_NAME               VARCHAR(255),
   EPH_TYPE               VARCHAR(255),
   EPH_STATE              VARCHAR(255),
   MOL_EID                VARCHAR(255),
   MOL_NAME               VARCHAR(255),
   ATCCODE                VARCHAR(255),
   ATC_NAME               VARCHAR(255),
   ATC_MOL                VARCHAR(255),
   ATC_TYPE               VARCHAR(255),
   ATC_STATE              VARCHAR(255),
   BNF_EID                VARCHAR(255),
   BNF_NAME               VARCHAR(255),
   VERSION                VARCHAR(255),
   UPDATED                VARCHAR(255),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR(255),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR(255),
   GAL_ID                 VARCHAR(255),
   GAL_ID2                VARCHAR(255),
   FIRST_PRD_DATE         VARCHAR(255),
   FIRST_PRE_TRA_ID       VARCHAR(255),
   FIRST_TRA_DATE         VARCHAR(255),
   DDL_ID                 VARCHAR(255),
   DDL_LBL                VARCHAR(255),
   PRD_VAT                VARCHAR(255),
   REGROUPING_CODE_2      VARCHAR(255),
   GMP_ID                 VARCHAR(255),
   PRD_ID_DC              VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AUS_DRUG_MAPPING_p2;
CREATE TABLE SOURCES.AUS_DRUG_MAPPING_p2
(
   PRD_EID          VARCHAR(255),
   LPDORIGINALNAME  VARCHAR(255),
   FCC              VARCHAR(255),
   DESCRIPTION      VARCHAR(255),
   MANUFACTURER     VARCHAR(255),
   EPHMRA_ATC_CODE  VARCHAR(255),
   NFC_CODE         VARCHAR(255),
   PRD_NAME         VARCHAR(255),
   MAST_PRD_NAME    VARCHAR(255),
   WHO_ATC_EID      VARCHAR(255),
   PRD_DOSAGE       VARCHAR(255),
   UNIT             VARCHAR(255),
   PRD_DOSAGE2      VARCHAR(255),
   UNIT_ID2         VARCHAR(255),
   MOL_NAME         VARCHAR(255),
   OOT              VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AUS_DRUG_MAPPING_3;
CREATE TABLE SOURCES.AUS_DRUG_MAPPING_3
(
   PRD_EID          VARCHAR(255),
   LPDORIGINALNAME  VARCHAR(255),
   FCC              VARCHAR(255),
   DESCRIPTION      VARCHAR(255),
   MANUFACTURER     VARCHAR(255),
   EPHMRA_ATC_CODE  VARCHAR(255),
   NFC_CODE         VARCHAR(255),
   PRD_NAME         VARCHAR(255),
   MAST_PRD_NAME    VARCHAR(255),
   WHO_ATC_EID      VARCHAR(255),
   PRD_DOSAGE       VARCHAR(255),
   UNIT             VARCHAR(255),
   PRD_DOSAGE2      VARCHAR(255),
   UNIT_ID2         VARCHAR(255),
   MOL_NAME         VARCHAR(255),
   OOT              VARCHAR(255)
);

DROP TABLE IF EXISTS SOURCES.AUS_FO_PRODUCT_3;
CREATE TABLE SOURCES.AUS_FO_PRODUCT_3
(
   FO_PRD_ID              VARCHAR(255),
   PRD_EID                VARCHAR(255),
   PRD_NAME               VARCHAR(255),
   MAST_PRD_NAME          VARCHAR(255),
   INT_BRAND_NAME         VARCHAR(255),
   DOSAGE                 VARCHAR(255),
   DOSAGE_AS_TEXT         VARCHAR(255),
   UNIT                   VARCHAR(255),
   DOSAGE2                VARCHAR(255),
   DOSAGE2_AS_TEXT        VARCHAR(255),
   UNIT2                  VARCHAR(255),
   DOSAGE3                VARCHAR(255),
   DOSAGE3_AS_TEXT        VARCHAR(255),
   UNIT3                  VARCHAR(255),
   NBDOSE                 VARCHAR(255),
   NBDOSE_AS_TEXT         VARCHAR(255),
   GALENIC                VARCHAR(255),
   NBDOSE2                VARCHAR(255),
   NBDOSE2_AS_TEXT        VARCHAR(255),
   GALENIC2               VARCHAR(255),
   IS_PRD_REFUNDABLE      VARCHAR(255),
   PRD_REFUNDABLE_RATE    VARCHAR(255),
   PRD_PRICE              VARCHAR(255),
   CANCELED_DAT           VARCHAR(255),
   CREATION_DAT           VARCHAR(255),
   MANUFACTURER_NAME      VARCHAR(255),
   IS_GENERIC             VARCHAR(255),
   IS_HOSP                VARCHAR(255),
   PRD_START_DAT          VARCHAR(255),
   PRD_END_DAT            VARCHAR(255),
   REGROUPING_CODE        VARCHAR(255),
   EPH_CODE               VARCHAR(255),
   EPH_NAME               VARCHAR(255),
   EPH_TYPE               VARCHAR(255),
   EPH_STATE              VARCHAR(255),
   MOL_EID                VARCHAR(255),
   MOL_NAME               VARCHAR(255),
   ATCCODE                VARCHAR(255),
   ATC_NAME               VARCHAR(255),
   ATC_MOL                VARCHAR(255),
   ATC_TYPE               VARCHAR(255),
   ATC_STATE              VARCHAR(255),
   BNF_EID                VARCHAR(255),
   BNF_NAME               VARCHAR(255),
   VERSION                VARCHAR(255),
   UPDATED                VARCHAR(255),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR(255),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR(255),
   GAL_ID                 VARCHAR(255),
   GAL_ID2                VARCHAR(255),
   FIRST_PRD_DATE         VARCHAR(255),
   FIRST_PRE_TRA_ID       VARCHAR(255),
   FIRST_TRA_DATE         VARCHAR(255),
   DDL_ID                 VARCHAR(255),
   DDL_LBL                VARCHAR(255),
   PRD_VAT                VARCHAR(255),
   REGROUPING_CODE_2      VARCHAR(255),
   GMP_ID                 VARCHAR(255),
   PRD_ID_DC              VARCHAR(255)
);
 */
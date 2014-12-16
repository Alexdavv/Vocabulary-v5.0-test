CREATE TABLE SCT2_RELA_FULL_INT
(
   ID                     INTEGER,
   EFFECTIVETIME          VARCHAR2 (8 BYTE),
   ACTIVE                 VARCHAR2 (1 BYTE),
   MODULEID               VARCHAR2 (256 BYTE),
   SOURCEID               VARCHAR2 (256 BYTE),
   DESTINATIONID          VARCHAR2 (256 BYTE),
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 INTEGER,
   CHARACTERISTICTYPEID   VARCHAR2 (256 BYTE),
   MODIFIERID             VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_DESC_FULL_EN_INT
(
   ID                   INTEGER,
   EFFECTIVETIME        VARCHAR2 (8 BYTE),
   ACTIVE               VARCHAR2 (1 BYTE),
   MODULEID             VARCHAR2 (18 BYTE),
   CONCEPTID            VARCHAR2 (256 BYTE),
   LANGUAGECODE         VARCHAR2 (2 BYTE),
   TYPEID               VARCHAR2 (18 BYTE),
   TERM                 VARCHAR2 (256 BYTE),
   CASESIGNIFICANCEID   VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_CONCEPT_FULL_INT
(
   ID              VARCHAR2 (18 BYTE),
   EFFECTIVETIME   VARCHAR2 (8 BYTE),
   ACTIVE          VARCHAR2 (1 BYTE),
   MODULEID        VARCHAR2 (18 BYTE),
   STATUSID        VARCHAR2 (256 BYTE)
);

CREATE INDEX X_CID
   ON SCT2_CONCEPT_FULL_INT (ID);

CREATE INDEX X_rel_id
   ON SCT2_RELA_FULL_INT (ID);

CREATE INDEX X_DESC_2CD
   ON SCT2_DESC_FULL_EN_INT (CONCEPTID, MODULEID);

CREATE INDEX X_DESC_3CD
   ON SCT2_DESC_FULL_EN_INT (CONCEPTID, MODULEID, TERM);

CREATE TABLE SCT2_RELA_FULL_UK
(
   ID                     INTEGER,
   EFFECTIVETIME          VARCHAR2 (8 BYTE),
   ACTIVE                 VARCHAR2 (1 BYTE),
   MODULEID               VARCHAR2 (256 BYTE),
   SOURCEID               VARCHAR2 (256 BYTE),
   DESTINATIONID          VARCHAR2 (256 BYTE),
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 INTEGER,
   CHARACTERISTICTYPEID   VARCHAR2 (256 BYTE),
   MODIFIERID             VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_DESC_FULL_UK
(
   ID                   INTEGER,
   EFFECTIVETIME        VARCHAR2 (8 BYTE),
   ACTIVE               VARCHAR2 (1 BYTE),
   MODULEID             VARCHAR2 (18 BYTE),
   CONCEPTID            VARCHAR2 (256 BYTE),
   LANGUAGECODE         VARCHAR2 (2 BYTE),
   TYPEID               VARCHAR2 (18 BYTE),
   TERM                 VARCHAR2 (256 BYTE),
   CASESIGNIFICANCEID   VARCHAR2 (256 BYTE)
);

CREATE TABLE SCT2_CONCEPT_FULL_UK
(
   ID              VARCHAR2 (18 BYTE),
   EFFECTIVETIME   VARCHAR2 (8 BYTE),
   ACTIVE          VARCHAR2 (1 BYTE),
   MODULEID        VARCHAR2 (18 BYTE),
   STATUSID        VARCHAR2 (256 BYTE)
);

CREATE INDEX X_rel_id_uk
   ON SCT2_RELA_FULL_UK (ID);

CREATE INDEX X_DESC_2CD_UK
   ON SCT2_DESC_FULL_UK (CONCEPTID, MODULEID);

CREATE INDEX X_DESC_3CD_UK
   ON SCT2_DESC_FULL_UK (CONCEPTID, MODULEID, TERM);

CREATE INDEX X_CID_UK
   ON SCT2_CONCEPT_FULL_UK (ID);
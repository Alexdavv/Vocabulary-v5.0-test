--create source tables, later use WbImport to insert original data
CREATE TABLE DRUG
(
   DRUG_CODE          VARCHAR2(255 Byte),
   DRUG_DESCR         VARCHAR2(300 Byte),
   FORM               VARCHAR2(255 Byte),
   ROUTE              VARCHAR2(255 Byte),
   STATUS             VARCHAR2(255 Byte),
   CERTIFIER          VARCHAR2(255 Byte),
   APPROVAL_DATE      DATE,
   MARKET_STATUS      VARCHAR2(255 Byte),
   INACTIVE_FLAG      VARCHAR2(25 Byte),
   EU_NUMBER          VARCHAR2(255 Byte),
   MANUFACTURER       VARCHAR2(255 Byte),
   SURVEILLANCE_FLAG  VARCHAR2(5 Byte)
)
TABLESPACE USERS;

CREATE TABLE PACKAGING
(
   DRUG_CODE           VARCHAR2(255 Byte),
   DIN_7               NUMBER,
   PACKAGING           VARCHAR2(355 Byte),
   STATUS              VARCHAR2(255 Byte),
   MARKET_STATUS       VARCHAR2(255 Byte),
   MARKETED_DATE       DATE,
   DIN_13              NUMBER,
   COMMUNITY_APPROVAL  VARCHAR2(255 Byte),
   REPAYMENT_RATE      VARCHAR2(255 Byte),
   DRUG_COST           VARCHAR2(255 Byte)
)
TABLESPACE USERS;
      
CREATE TABLE INGREDIENT
(
   DRUG_CODE    VARCHAR2(255 Byte),
   DRUG_FORM    VARCHAR2(255 Byte),
   FORM_CODE    NUMBER,
   INGREDIENT   VARCHAR2(255 Byte),
   DOSAGE       VARCHAR2(255 Byte),
   VOLUME       VARCHAR2(255 Byte),
   INGR_NATURE  VARCHAR2(5 Byte),
   COMP_NUMBER  NUMBER
)
TABLESPACE USERS;

CREATE TABLE GENERIC
(
   GENERIC_GROUP  VARCHAR2(255 Byte),
   GENERIC_DESC   VARCHAR2(1000 Byte),
   DRUG_CODE      VARCHAR2(255 Byte),
   GENERIC_TYPE   NUMBER,
   SERIAL_NUMBER  NUMBER
)
TABLESPACE USERS;

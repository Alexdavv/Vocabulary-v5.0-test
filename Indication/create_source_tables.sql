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

DROP TABLE IF EXISTS SOURCES.RFMLDRH0_DXID_HIST;
CREATE TABLE SOURCES.RFMLDRH0_DXID_HIST
(
   FMLPRVDXID   VARCHAR (8) NOT NULL,
   FMLREPDXID   VARCHAR (8) NOT NULL,
   FMLDXREPDT   DATE
);

DROP TABLE IF EXISTS SOURCES.RFMLDX0_DXID;
CREATE TABLE SOURCES.RFMLDX0_DXID
(
   DXID                       VARCHAR (8) NOT NULL,
   DXID_DESC56                VARCHAR (56),
   DXID_DESC100               VARCHAR (100),
   DXID_STATUS                VARCHAR (1) NOT NULL,
   FDBDX                      VARCHAR (9) NOT NULL,
   DXID_DISEASE_DURATION_CD   VARCHAR (1) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.RFMLSYN0_DXID_SYN;
CREATE TABLE SOURCES.RFMLSYN0_DXID_SYN
(
   DXID_SYNID         VARCHAR (8) NOT NULL,
   DXID               VARCHAR (8) NOT NULL,
   DXID_SYN_NMTYP     VARCHAR (2) NOT NULL,
   DXID_SYN_DESC56    VARCHAR (56),
   DXID_SYN_DESC100   VARCHAR (100),
   DXID_SYN_STATUS    VARCHAR (1) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.RINDMGC0_INDCTS_GCNSEQNO_LINK;
CREATE TABLE SOURCES.RINDMGC0_INDCTS_GCNSEQNO_LINK
(
   GCN_SEQNO   VARCHAR (6) NOT NULL,
   INDCTS      VARCHAR (5) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.RINDMMA2_INDCTS_MSTR;
CREATE TABLE SOURCES.RINDMMA2_INDCTS_MSTR
(
   INDCTS       VARCHAR (5) NOT NULL,
   INDCTS_SN    VARCHAR (2) NOT NULL,
   INDCTS_LBL   VARCHAR (1) NOT NULL,
   FDBDX        VARCHAR (9) NOT NULL,
   DXID         VARCHAR (8),
   PROXY_IND    VARCHAR (1),
   PRED_CODE    VARCHAR (1) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.RDDCMGC0_CONTRA_GCNSEQNO_LINK;
CREATE TABLE SOURCES.RDDCMGC0_CONTRA_GCNSEQNO_LINK
(
   GCN_SEQNO   VARCHAR (6) NOT NULL,
   DDXCN       VARCHAR (5) NOT NULL
);

DROP TABLE IF EXISTS SOURCES.RDDCMMA1_CONTRA_MSTR;
CREATE TABLE SOURCES.RDDCMMA1_CONTRA_MSTR
(
   DDXCN       VARCHAR (5) NOT NULL,
   DDXCN_SN    VARCHAR (2) NOT NULL,
   FDBDX       VARCHAR (9),
   DDXCN_SL    VARCHAR (1),
   DDXCN_REF   VARCHAR (26),
   DXID        VARCHAR (8)
);

DROP TABLE IF EXISTS SOURCES.RFMLISR1_ICD_SEARCH;
CREATE TABLE SOURCES.RFMLISR1_ICD_SEARCH
(
   SEARCH_ICD_CD   VARCHAR (10) NOT NULL,
   ICD_CD_TYPE     VARCHAR (2) NOT NULL,
   RELATED_DXID    VARCHAR (8) NOT NULL,
   FML_CLIN_CODE   VARCHAR (2) NOT NULL,
   FML_NAV_CODE    VARCHAR (2) NOT NULL
);
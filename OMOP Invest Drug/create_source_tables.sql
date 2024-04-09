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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2022
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.INVDRUG_ANTINEOPL;
CREATE TABLE SOURCES.INVDRUG_ANTINEOPL
(
   CODE                TEXT,
   NCIT_PREFERRED_NAME TEXT,
   SYNONYMS            TEXT,
   DEFINITION          TEXT,
   SEMANTIC_TYPE       TEXT
);

DROP TABLE IF EXISTS SOURCES.INVDRUG_PHARMSUB;
CREATE TABLE SOURCES.INVDRUG_PHARMSUB
(
   CONCEPT_ID         TEXT,
   PT                 TEXT,
   SY                 TEXT,
   CAS_REGISTRY       TEXT,
   FDA_UNII_CODE      TEXT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.INVDRUG_INXIGHT;
CREATE TABLE SOURCES.INVDRUG_INXIGHT
(
   JSONFIELD JSON
);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ncit(xls_path varchar)
RETURNS
TABLE (
    concept_id text,
    pt text,
    sy text,
    cas_registry text,
    fda_unii_code text
)
AS
$BODY$
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  concept_id=row[1].value if row[1].value else None
  pt=row[2].value if row[2].value else None
  sy=row[3].value if row[3].value else None
  cas_registry=row[5].value if row[5].value else None
  fda_unii_code=row[6].value if row[6].value else None
  res.append((concept_id,pt,sy,cas_registry,fda_unii_code))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;
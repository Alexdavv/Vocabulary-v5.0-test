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
DROP TABLE IF EXISTS SOURCES.ICD10PCS_TEMP;
CREATE TABLE SOURCES.ICD10PCS_TEMP
(
   icd10pcs_codes_and_desc   VARCHAR (4000)
);

DROP TABLE IF EXISTS SOURCES.ICD10PCS;
CREATE TABLE SOURCES.ICD10PCS
(
   concept_code       VARCHAR (50),
   concept_name       VARCHAR (1000),
   vocabulary_date    DATE,
   vocabulary_version VARCHAR (200)
);

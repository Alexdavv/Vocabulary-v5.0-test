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
* Authors: Timur Vakhitov
* Date: 2022
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.CIVIC_VARIANTSUMMARIES_RAW;
CREATE TABLE SOURCES.CIVIC_VARIANTSUMMARIES_RAW
(
   civic_variantsummaries_tsv   TEXT
);

DROP TABLE IF EXISTS SOURCES.CIVIC_VARIANTSUMMARIES;
CREATE TABLE SOURCES.CIVIC_VARIANTSUMMARIES
(
   variant_id                   TEXT,
   variant_civic_url            TEXT,
   gene                         TEXT,
   entrez_id                    TEXT,
   variant                      TEXT,
   summary                      TEXT,
   variant_groups               TEXT,
   chromosome                   TEXT,
   start                        TEXT,
   stop                         TEXT,
   reference_bases              TEXT,
   variant_bases                TEXT,
   representative_transcript    TEXT,
   ensembl_version              TEXT,
   reference_build              TEXT,
   chromosome2                  TEXT,
   start2                       TEXT,
   stop2                        TEXT,
   representative_transcript2   TEXT,
   variant_types                TEXT,
   hgvs_expressions             TEXT,
   last_review_date             TEXT,
   civic_variant_evidence_score TEXT,
   allele_registry_id           TEXT,
   clinvar_ids                  TEXT,
   variant_aliases              TEXT,
   assertion_ids                TEXT,
   vocabulary_date              DATE,
   vocabulary_version           VARCHAR (200)
);
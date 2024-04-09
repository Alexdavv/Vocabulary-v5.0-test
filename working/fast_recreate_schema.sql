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

CREATE OR REPLACE FUNCTION devv5.FastRecreateSchema (
  main_schema_name varchar(100) default 'devv5',
  include_concept_ancestor boolean default false,
  include_deprecated_rels boolean default false,
  include_synonyms boolean default false,
  drop_concept_ancestor boolean default true
)
RETURNS void AS
$body$
  /*
    Use this script to recreate main tables (concept, concept_relationship, concept_synonym etc) without dropping your schema
    Examples:
    SELECT devv5.FastRecreateSchema(); --recreate with default settings (copy from devv5, w/o ancestor, deprecated relationships and synonyms (faster)
    SELECT devv5.FastRecreateSchema(include_concept_ancestor=>true); --same as above, but table concept_ancestor is included
    SELECT devv5.FastRecreateSchema(include_concept_ancestor=>true,include_deprecated_rels=>true,include_synonyms=>true); --full recreate, all tables are included (much slower)
    SELECT devv5.FastRecreateSchema(drop_concept_ancestor=>false); --preserve old concept_ancestor, but it will be ignored if the include_concept_ancestor is set to true
  */
  BEGIN
    main_schema_name:=LOWER(main_schema_name);
    IF CURRENT_SCHEMA = 'devv5' THEN RAISE EXCEPTION 'You cannot use this script in the ''devv5''!'; END IF;
    
    DROP TABLE IF EXISTS concept, concept_relationship, concept_synonym, vocabulary, relationship, drug_strength, pack_content CASCADE;
    IF drop_concept_ancestor OR include_concept_ancestor THEN DROP TABLE IF EXISTS concept_ancestor; END IF;
    TRUNCATE TABLE concept_stage, concept_relationship_stage, concept_synonym_stage, concept_class, domain, vocabulary_conversion, drug_strength_stage, pack_content_stage;
    EXECUTE FORMAT ($$
      INSERT INTO concept_class SELECT * FROM %1$I.concept_class;
      INSERT INTO domain SELECT * FROM %1$I.domain;
      INSERT INTO vocabulary_conversion SELECT * FROM %1$I.vocabulary_conversion;
      CREATE TABLE concept (LIKE %1$I.concept INCLUDING CONSTRAINTS);
      INSERT INTO concept SELECT * FROM %1$I.concept;
      CREATE TABLE concept_relationship (LIKE %1$I.concept_relationship INCLUDING CONSTRAINTS);
      INSERT INTO concept_relationship SELECT * FROM %1$I.concept_relationship WHERE '%2$s'=TRUE OR ('%2$s'=FALSE AND invalid_reason IS NULL);
      CREATE TABLE concept_synonym (LIKE %1$I.concept_synonym INCLUDING CONSTRAINTS);
      INSERT INTO concept_synonym SELECT * FROM %1$I.concept_synonym WHERE '%3$s'=TRUE;
      CREATE TABLE vocabulary (LIKE %1$I.vocabulary);
      INSERT INTO vocabulary SELECT * FROM %1$I.vocabulary;
      CREATE TABLE relationship (LIKE %1$I.relationship);
      INSERT INTO relationship SELECT * FROM %1$I.relationship;
      CREATE TABLE drug_strength (LIKE %1$I.drug_strength);
      INSERT INTO drug_strength SELECT * FROM %1$I.drug_strength;
      CREATE TABLE pack_content (LIKE %1$I.pack_content);
      INSERT INTO pack_content SELECT * FROM %1$I.pack_content;
      CREATE TABLE IF NOT EXISTS concept_ancestor (LIKE %1$I.concept_ancestor);
      INSERT INTO concept_ancestor SELECT * FROM %1$I.concept_ancestor WHERE '%4$s'=TRUE;     
    $$, main_schema_name, include_deprecated_rels, include_synonyms, include_concept_ancestor);

    --Create indexes and constraints for main tables
    ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
    ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
    ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);
    ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
    ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id) NOT VALID;
    ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id) NOT VALID;
    ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id) NOT VALID;
    ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id) NOT VALID;
    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id) NOT VALID;
    ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_language FOREIGN KEY (language_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
    IF drop_concept_ancestor OR include_concept_ancestor THEN ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id); END IF;

    CREATE UNIQUE INDEX idx_unique_concept_code ON concept (vocabulary_id, concept_code) WHERE vocabulary_id NOT IN ('DRG', 'SMQ') AND concept_code <> 'OMOP generated';
    /*
        We need index listed below for queries like "SELECT * FROM concept WHERE vocabulary_id='xxx'".
        Previous unique index only to support unique pairs of voabulary_id+concept_code with some exceptions
    */
    CREATE INDEX idx_vocab_concept_code ON concept (vocabulary_id varchar_pattern_ops, concept_code);
    CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2);
    CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id);
    CREATE INDEX idx_csyn_concept_syn_name ON concept_synonym (concept_synonym_name);
    CREATE INDEX idx_pack_content_id_2 ON pack_content (drug_concept_id);
    CREATE UNIQUE INDEX u_pack_content ON pack_content (pack_concept_id, drug_concept_id, COALESCE(amount,-1));
    ALTER TABLE drug_strength ADD CONSTRAINT xpk_drug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id);
    ALTER TABLE concept_stage DROP CONSTRAINT IF EXISTS idx_pk_cs;
    ALTER TABLE concept_stage ADD CONSTRAINT idx_pk_cs PRIMARY KEY (concept_code,vocabulary_id);
    CREATE INDEX IF NOT EXISTS idx_cs_concept_id ON concept_stage (concept_id);
    ALTER TABLE concept_relationship_stage DROP CONSTRAINT IF EXISTS idx_pk_crs;
    ALTER TABLE concept_relationship_stage ADD CONSTRAINT idx_pk_crs PRIMARY KEY (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id);
    ALTER TABLE concept_synonym_stage DROP CONSTRAINT IF EXISTS idx_pk_css;
    ALTER TABLE concept_synonym_stage ADD CONSTRAINT idx_pk_css PRIMARY KEY (synonym_vocabulary_id,synonym_name,synonym_concept_code,language_concept_id);
    CREATE INDEX IF NOT EXISTS idx_concept_code_2 ON concept_relationship_stage (concept_code_2);
    CREATE INDEX IF NOT EXISTS idx_dss_concept_code ON drug_strength_stage (drug_concept_code);
    CREATE INDEX IF NOT EXISTS idx_ca_descendant ON concept_ancestor (descendant_concept_id);
    CREATE UNIQUE INDEX IF NOT EXISTS xpk_vocab_conversion ON vocabulary_conversion (vocabulary_id_v5);

    --Enable other constraints
    ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (DOMAIN_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_1 FOREIGN KEY (pack_concept_id) REFERENCES concept (concept_id) NOT VALID;
    ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_2 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) NOT VALID;

    --Analyzing
    ANALYZE concept;
    ANALYZE concept_relationship;
    ANALYZE concept_synonym;
    ANALYZE drug_strength;
    ANALYZE pack_content;
    ANALYZE concept_ancestor;
  END;
$body$
LANGUAGE 'plpgsql'
SET client_min_messages = error;
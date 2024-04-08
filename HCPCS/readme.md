Update of HCPCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- SNOMED must be loaded first
- Working directory HCPCS.

1. Run create_source_tables.sql
2. Download the latest file https://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets/HCPCS-Quarterly-Update file name Mon-YYYY-Alpha-Numeric-HCPCS-File.zip
3. Extract HCPCYYYY_CONTR_ANWEB.xlsx and rename to HCPC_CONTR_ANWEB.xlsx
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('HCPCS',TO_DATE('20171106','YYYYMMDD'),'2018 Alpha Numeric HCPCS File');
5. Run FULL FastRecreate:
```sql
   SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false, include_deprecated_rels=> true, include_synonyms=> true);
```
6. Run load_stage.sql.
7.  Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
8. Run basic tables check (should retrieve NULL):
```sql
   SELECT * FROM qa_tests.get_checks();
```
9. Perform manual work described in the readme.md file in the 'manual_work' folder.

Repeat steps 5-10.

10. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
    ```
11. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
12. Run manual_checks_after_generic.sql, and interpret the results. 
13. Run project_specific_manual_checks_after_generic.sql, and interpret the results.
14. If no problems, enjoy!

CSV sources for CONCEPT_MANUAL and CONCEPT_RELATIONSHIP_MANUAL are available here:
https://drive.google.com/drive/u/2/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ
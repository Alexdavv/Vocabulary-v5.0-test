### STEP 11 of the refresh:

11.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ) into the concept_manual table.
The file was generated using the query:
```sql
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name
```
11.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ) into the concept_relationship_manual table.
The file was generated using the query:
```sql
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date
```

11.3. Work with the [hcpcs_refresh] file:

11.3.1. Backup concept_relationship_manual table and concept_manual table.

11.3.2. Create hcpcs_mapped table in the spreadsheet editor pre-populate it with the resulting manual table of the previous HCPCS refresh.

11.3.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

11.3.4. Select concepts to map and add them to the manual file in the spreadsheet editor.

11.3.5. Truncate the hcpcs_mapped table. Save the spreadsheet as the hcpcs_mapped table and upload it into the working schema.

11.3.6. Perform any mapping checks you have set.

11.3.7. Iteratively repeat steps 8.2.3-8.2.6 if found any issues.

11.3.8. Deprecate all mappings that differ from the new version of resulting mapping file.

11.3.9. Insert new and corrected mappings into the concept_relationship_manual table.

11.3.10 Activate mapping, that became valid again.
--delete duplicates that was made from previous iteration and their relationships
insert into concept_stage 
SELECT concept_id,
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       null::varchar as standard_concept,
       concept_code,
       valid_start_date,
       current_date  as valid_end_date,
       'D' as invalid_reason
FROM concept
WHERE (concept_code,trim(concept_name),concept_class_id) NOT IN (SELECT MIN(concept_code) OVER (PARTITION BY c.concept_name,c.concept_class_id),
                                                                  trim(c.concept_name),
                                                                  c.concept_class_id
                                                           FROM concept c
                                                           WHERE c.vocabulary_id = 'GRR'
                                                           AND   (c.concept_name,c.concept_class_id) IN (SELECT trim(concept_name),
                                                                                                                concept_class_id
                                                                                                         FROM concept
                                                                                                         WHERE concept_class_id NOT IN ('Drug Product','Device')
                                                                                                         AND   vocabulary_id = 'GRR'
                                                                                                         GROUP BY concept_name,
                                                                                                                  concept_class_id
                                                                                                         HAVING COUNT(1) > 1))
AND   concept_class_id NOT IN ('Drug Product','Device')
AND   vocabulary_id = 'GRR'
AND   (concept_name,concept_class_id) IN (SELECT concept_name,
                                                                                                                concept_class_id
                                                                                                         FROM concept
                                                                                                         WHERE concept_class_id NOT IN ('Drug Product','Device')
                                                                                                         AND   vocabulary_id = 'GRR'
                                                                                                         GROUP BY concept_name,
                                                                                                                  concept_class_id
                                                                                                         HAVING COUNT(1) > 1)

or concept_id in (37596695,41732353)
;


insert into concept_stage
SELECT concept_id,
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       null::varchar as standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept
WHERE vocabulary_id = 'GRR'
AND   concept_class_id = 'Ingredient'
AND   standard_concept IS NOT NULL
AND   concept_code NOT IN (SELECT concept_code FROM concept_stage);

insert into concept_relationship_stage
SELECT NULL,
       NULL,
       c.concept_code,
       cc.concept_code,
       c.vocabulary_id,
       cc.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       CASE
         WHEN cr.valid_end_date != TO_DATE('20991231','yyyymmdd') THEN cr.valid_end_date 
         ELSE CURRENT_DATE 
       END ,
       'D'
FROM concept_stage c
  JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
  JOIN concept cc ON cr.concept_id_2 = cc.concept_id
  where c.invalid_reason is not null;


insert into concept_relationship_stage
SELECT NULL,
       NULL,
       c.concept_code,
       cc.concept_code,
       c.vocabulary_id,
       cc.vocabulary_id,
       cr.relationship_id,
       cr.valid_start_date,
       TO_DATE('20991231','yyyymmdd'),
       null::varchar
FROM concept c
  JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
  JOIN concept cc ON cr.concept_id_2 = cc.concept_id
WHERE (trim(c.concept_name),c.concept_class_id) IN (SELECT trim(concept_name),
                                                 concept_class_id
                                          FROM concept
                                          WHERE concept_class_id NOT IN ('Drug Product','Device')
                                          AND   vocabulary_id = 'GRR'
                                          GROUP BY concept_name,
                                                   concept_class_id
                                          HAVING COUNT(1) > 1)
AND   c.vocabulary_id = 'GRR'
and c.concept_code not in (select concept_code from concept_stage)
and cr.invalid_reason is not null
;



insert into concept_stage
SELECT c.concept_id,
       c.concept_name,
       c.domain_id,
       c.vocabulary_id,
       c.concept_class_id,
       null::varchar as standard_concept,
       c.concept_code,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason
FROM concept c
  JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
WHERE (c.concept_name,c.concept_class_id) IN (SELECT concept_name,
                                                 concept_class_id
                                          FROM concept
                                          WHERE concept_class_id NOT IN ('Drug Product','Device')
                                          AND   vocabulary_id = 'GRR'
                                          GROUP BY concept_name,
                                                   concept_class_id
                                          HAVING COUNT(1) > 1)
AND   c.vocabulary_id = 'GRR'
and c.concept_code not in (select concept_code from concept_stage)
and cr.invalid_reason is not null
;





insert into concept_stage 
select concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,current_date , 'D'
from concept where vocabulary_id = 'GRR' and 
concept_code like '%_01010001'

;

insert into concept_relationship_stage 
select null,null, c.concept_code , c1.concept_code , c.vocabulary_id , c1.vocabulary_id, cr.relationship_id, cr.valid_start_date,current_date , 'D' 
from ( 
select concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,current_date -1 , 'D'  
from concept where vocabulary_id = 'GRR' and 
concept_code like '%_01010001' ) c 
join concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.invalid_reason is null
join concept c1 on c1.concept_id = cr.concept_id_2;


 
insert into concept_stage
select * 
from concept 
where standard_concept is not null
and vocabulary_id = 'GRR'
and concept_class_id = 'Ingredient'
;
 update concept_stage 
 set standard_concept = null
where standard_concept is not null
and vocabulary_id = 'GRR'
and concept_class_id = 'Ingredient';

DELETE
FROM concept_relationship_stage f
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage f_int
		WHERE f_int.concept_code_1 = f.concept_code_1
		  AND f_int.concept_code_2 = f.concept_code_2
			AND f_int.ctid > f.ctid
		);
	



DELETE
FROM concept_stage f
WHERE EXISTS (
		SELECT 1
		FROM concept_stage f_int
		WHERE f_int.concept_code = f.concept_code
		and f_int.valid_start_date  = f.valid_start_date
			AND f_int.ctid > f.ctid
		);




update  concept_stage 
set invalid_reason = 'D',
standard_concept = null,
valid_end_date = Current_date 
where concept_code in (
select concept_code_1 
from concept_relationship_stage crs
where invalid_reason is not null
and not exists 
(
select 1 
from concept_relationship_stage crs1
where crs.concept_code_1 = crs1.concept_code_1
and invalid_reason is null
));




--for new vaccine and device mappings, since old mappings to RxN* are not deprecated automatically
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'GRR',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date ,
	'D'
from concept_relationship r
join concept c on 
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'GRR' and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.vocabulary_id like 'RxN%'
join concept_relationship_stage t on
	c.concept_code = t.concept_code_1 and
	t.vocabulary_id_2 not like 'RxN%'
where (c.concept_code, c2.concept_code) not in (select concept_code_1, concept_code_2 from concept_relationship_stage)
;

delete from concept_relationship_stage x
where
	x.invalid_reason is null and
	x.vocabulary_id_2 like 'RxN%' and
	x.relationship_id = 'Maps to' and
	exists	
		(
			select
			from concept_relationship_stage y
			where
				x.concept_code_1 = y.concept_code_1 and
				y.invalid_reason is null and
				y.relationship_id = 'Maps to' and
				y.vocabulary_id_2 not like 'RxN%'
		)
;


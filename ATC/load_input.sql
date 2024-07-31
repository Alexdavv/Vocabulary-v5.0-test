/**************************************************************************
    this script collects ATC - RxNorm connections from different sources and produces
**************************************************************************/

--- taking DMD from sources
drop table if exists dmd2atc;
CREATE TABLE if not exists dmd2atc AS
SELECT unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
	unnest(xpath('/VMP/ATC/text()', i.xmlfield))::VARCHAR ATC
FROM (
	SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
	FROM sources.dmdbonus i
	) AS i;


-----------------------------
drop table if exists class_atc_rxn_huge_temp;
create table class_ATC_RXN_huge_temp as   ------ wo ancestor
    SELECT
            source,
            c.concept_id as concept_id,
            c.concept_name,
            c.concept_class_id,
            atc.class_code,
            atc.class_name
    FROM

            (SELECT
                *
            FROM
                ------- dm+d--------
            (
                with base as (select t1.concept_id,
                       t1.concept_name,
                       t3.class_code,
                       t3.class_name
                from
                    (
                        select *
                        from devv5.concept
                        where concept_code in (select vpid
                        from dev_atatur.dmd2atc   ------ надо эту табличку в dmd и обновлять ее
                        where length(atc) = 7)
                        and vocabulary_id = 'dm+d') t1
                    join
                    (   select *
                        from dev_atatur.dmd2atc ------ надо эту табличку в dmd и обновлять ее
                        where length(atc) = 7) t2 on concept_code = vpid
                    join
                        dev_atatur.atc_codes_stable t3 on t2.atc = t3.class_code)  --- Эти коды должны приходить из sources
            select
                t1.concept_id_2::int as concept_id,
                base.class_code as class_code,
                'dmd' as source
            from devv5.concept_relationship t1
                     join base on t1.concept_id_1 = base.concept_id
                     join devv5.concept t2 on t1.concept_id_2 = t2.concept_id
            where t1.relationship_id = 'Maps to'
                     and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
            ) t1

            UNION


                    ------BDPM------
             (select t4.concept_id,
                     t2.atc_code,
                     'BDPM' as source
              from sources.bdpm_packaging t1
                       join dev_atatur.bpdm_atc_codes t2 on t1.drug_code = t2.id::VARCHAR ----- Перенести в сорсы.
                       join devv5.concept t3 on t1.din_7::VARCHAR = t3.concept_code and t3.vocabulary_id = 'BDPM'
                       join devv5.concept_relationship cr
                            on cr.concept_id_1 = t3.concept_id and cr.relationship_id = 'Maps to'
                       join devv5.concept t4 on cr.concept_id_2 = t4.concept_id and t4.invalid_reason is Null and
                                                t4.standard_concept = 'S')

            UNION

                    ----------------

                    ------GRR-------
            (with base_up as(
            with base as(SELECT
                    CASE
                     WHEN product_launch_date IS NULL THEN CAST(fcc AS VARCHAR)
                     ELSE fcc || '_' || TO_CHAR(TO_DATE(product_launch_date,'dd.mm.yyyy'),'mmddyyyy')
                   END AS concept_code,
                   therapy_name,
                   who_atc5_code
            FROM dev_grr.source_data
            where (length(who_atc5_code) = 7 and who_atc5_code != '???????' and who_atc5_code not like '%..'))

            select  t1.concept_id,
                    t1.concept_code,
                    t1.concept_name,
                   t2.therapy_name,
                   t2.who_atc5_code as who_atc5_code
            from devv5.concept t1
            join base t2 on t1.concept_code = t2.concept_code
            where t1.vocabulary_id = 'GRR')
            SELECT
                t1.concept_id_2::int as concept_id,
                base_up.who_atc5_code as class_code,
                'grr' as source
            from
                devv5.concept_relationship t1
                join base_up on t1.concept_id_1 = base_up.concept_id
                join concept t2 on t1.concept_id_2 = t2.concept_id
            where
                t1.relationship_id = 'Maps to'
                and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension'))

            UNION
                    ----- UMLS-------
            (select
                t3.concept_id::int as concept_id,
                t1.code as class_code,
                'umls' as source --||t4.sab as source
            from
                   sources.rxnrel main
                   join sources.rxnconso t1 on main.rxcui1=t1.rxcui
                   join sources.rxnconso t2 on main.rxcui2=t2.rxcui
                   join devv5.concept t3 on t2.code = t3.concept_code
                   --join sources.rxnconso t4 on t4.rxcui = t2.rxcui and t4.sab != t2.sab
            where t1.sab = 'ATC'
            and length(t1.code) = 7
            and t2.sab = 'RXNORM'
            and t3.vocabulary_id = 'RxNorm')

            ----- VANDF-------
            UNION

            (
                select
                       t5.concept_id::int,
                       t2.code,
                       'VANDF' as source
                from sources.rxnrel t1
                     join sources.rxnconso t2 on t1.rxcui1 = t2.rxcui
                     join sources.rxnconso t3 on t1.rxcui2 = t3.rxcui
                     join devv5.concept t4 on t3.code = t4.concept_code and t4.vocabulary_id = 'VANDF'
                     join devv5.concept_relationship cr on cr.concept_id_1 = t4.concept_id and cr.relationship_id = 'Maps to'
                     join devv5.concept t5 on cr.concept_id_2 = t5.concept_id
                where t2.sab = 'ATC'
                  and length(t2.code) = 7
                  and t3.sab = 'VANDF'

            )

            UNION

            -------------- JMDC -------------------
            (
            select
                   c.concept_id,
                   t2.who_atc_code,
                   'jmdc' as source
            from devv5.concept t1
                join dev_jmdc.jmdc t2 on t1.concept_code = t2.jmdc_drug_code
                join devv5.concept_relationship cr on cr.concept_id_1 = t1.concept_id
                join devv5.concept c on cr.concept_id_2 = c.concept_id

            where t1.concept_code in (select jmdc_drug_code
                                      from dev_jmdc.jmdc
                                      where length(who_atc_code) = 7)
            and t1.vocabulary_id = 'JMDC'
            and length(t2.who_atc_code) = 7
            and cr.relationship_id = 'Maps to'
            and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )

            ------- Other ------- to many trash from this source -------

--             UNION
--
--                 (
--                     select
--                         distinct t3.code::int, t1.code,
--                                  'Other' as sources
--                         --t1.str,
--                         --t3.str
--                     from sources.rxnrel rel
--                          join sources.rxnconso t1 on rel.rxcui1 = t1.rxcui
--                          join sources.rxnconso t2 on rel.rxcui2 = t2.rxcui and t2.sab in ('DRUGBANK','USP','MTHSPL','MMX','MMSL','GS','NDDF','SNOMEDCT_US')
--                          join sources.rxnrel rel2 on rel2.rxcui1 = t2.rxcui
--                          join sources.rxnconso t3 on rel2.rxcui2 = t3.rxcui
--                     where
--                         t1.sab = 'ATC'
--                         and length (t1.code) = 7
--                         and t3.sab = 'RXNORM'
--
--              )

            ----- z-index

            UNION

                (
--                     select concept_id, class_code, 'z-index' as source
--                         from dev_atatur.z_index

                    select targetid, atc, 'z-index' as source
                      from dev_atatur.zindex_full

                    )

            ------------Norske---------------    ---- Move to DEV_ATC

            UNION
            (
                select rx_ids,
                       atc_code,
                       'Norway' as source
                from dev_atatur.norske_result
            )

            UNION

                (
                    SELECT
                        t3.concept_id,
                        atc.concept_code_2,
                        'KDC'
                    FROM
                        dev_atatur.kdc_atc atc
                                join devv5.concept t1 on atc.concept_code = t1.concept_code and t1.vocabulary_id = 'KDC'
                                join devv5.concept t2 on atc.concept_code_2 = t2.concept_code and t2.vocabulary_id = 'ATC'
                                join devv5.concept_relationship cr on t1.concept_id = cr.concept_id_1 and cr.relationship_id = 'Maps to'
                                join devv5.concept t3 on cr.concept_id_2 = t3.concept_id and t3.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )

            UNION
            ------------ DPD ----------------
            (

                select
                        c2.concept_id,
                        dpd.tc_atc_number,
                        'dpd' as source
                from    devv5.concept c1 join sources.dpd_drug_all t1
                                                on c1.concept_code = (t1.drug_identification_number::INT)::VARCHAR and t1.drug_identification_number ~ '^\d+$'
                                         join sources.dpd_therapeutic_class_all dpd
                                                on t1.drug_code = dpd.drug_code
                                         join devv5.concept_relationship cr
                                                on cr.concept_id_1 = c1.concept_id
                                         join devv5.concept c2
                                                on cr.concept_id_2 = c2.concept_id

                where length(tc_atc_number)=7
                    and c1.vocabulary_id = 'DPD'
                    and cr.relationship_id = 'Maps to'
                    and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )


            ) t2
                join devv5.concept c on t2.concept_id = c.concept_id
                join dev_atatur.atc_codes_stable atc on t2.class_code = atc.class_code  ---- табличка должна быть в sources
            where c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                   and c.concept_class_id
                                            --not in     --------- Сразу отсечем все ненужные гранулированные формы.
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'Branded Drug Component', 'Clinical Drug Component', 'Dose Form', 'Brand',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'Branded Drug Comp', 'Branded Dose Group',
--                                              'Branded Drug Box', 'Multiple Ingredients', 'Branded Pack', 'Branded Drug Form', 'Branded Pack Box',
--                                             'Branded Drug', 'Multiple Ingredients', 'Brand Name','Quant Branded Box','Quant Branded Drug')

                                                     not in ('Brand Name',
                                                    'Branded Drug Comp',
                                                   'Branded Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')


            order by class_code;


select distinct concept_class_id
    from class_atc_rxn_huge_temp;

------------ ancestor build --------
drop table if exists class_ATC_RXN_huge_ancestor_temp;
create table class_ATC_RXN_huge_ancestor_temp as
SELECT *
FROM

                    -------------HUGE ANCESTOR------------
(select
                         c.concept_id,
                         c.concept_name,
                         c2.concept_id AS ids,
                         c2.concept_name AS names,
                         c2.concept_class_id
            from devv5.concept_ancestor ca
                join devv5.concept c on descendant_concept_id = c.concept_id
                join devv5.concept c2 on ancestor_concept_id =  c2.concept_id
            where
                    c2.concept_class_id
--                                         not in
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'Branded Drug Component', 'Clinical Drug Component', 'Dose Form', 'Brand',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'Branded Drug Comp', 'Branded Dose Group',
--                                              'Branded Drug Box', 'Multiple Ingredients', 'Branded Pack', 'Branded Drug Form', 'Branded Pack Box',
--                                              'Branded Drug', 'Multiple Ingredients', 'Brand Name','Quant Branded Box','Quant Branded Drug')
                                        not in ('Brand Name',
                                                    'Branded Drug Comp',
                                                   'Branded Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')


                    and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')) t1

UNION
(
select
                         c.concept_id as concept_id,
                         c.concept_name,
                         c2.concept_id AS ids,
                         c2.concept_name AS names,
                         c2.concept_class_id
            from devv5.concept_ancestor ca
                join devv5.concept c on ca.ancestor_concept_id = c.concept_id
                join devv5.concept c2 on ca.descendant_concept_id =  c2.concept_id
            where
                    c2.concept_class_id
--                                             not in
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'Branded Drug Component', 'Clinical Drug Component', 'Dose Form', 'Brand',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'Branded Drug Comp', 'Branded Dose Group',
--                                              'Branded Drug Box', 'Multiple Ingredients', 'Branded Pack', 'Branded Drug Form', 'Branded Pack Box',
--                                             'Branded Drug', 'Multiple Ingredients', 'Brand Name','Quant Branded Box','Quant Branded Drug')
                                                not in ('Brand Name',
                                                    'Branded Drug Comp',
                                                   'Branded Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')

                    and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
            );

                -------------SMALL ANCESTOR------------
-- select
--                          c.concept_id,
--                          c.concept_name,
--                          c2.concept_id AS ids,
--                          c2.concept_name AS names,
--                          c2.concept_class_id
--             from devv5.concept_ancestor ca
--                 join devv5.concept c on descendant_concept_id = c.concept_id
--                 join devv5.concept c2 on ancestor_concept_id =  c2.concept_id
--             where --c.concept_class_id = 'Clinical Drug'
--                     c2.concept_class_id not in
--                                             ('Ingredient', 'Precise Ingredient',   --- 'Clinical Drug Form', 'Branded Drug Form'
--                                              'Branded Drug Component',
--                                              'Clinical Drug Component', 'Dose Form', 'Brand',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'Branded Drug Comp', 'Branded Dose Group')
--                     and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
--                     and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

------------ ancestor end --------



-------------RxNorm Extension with RxNorm_is_a connection-----------


INSERT INTO class_ATC_RXN_huge_temp
SELECT
    'RxNorm_is_a' as source,
    t2.concept_id as concept_id,
    t2.concept_name as concept_name,
    t2.concept_class_id as concept_class_id,
    t1.class_code as class_code,
    t1.class_name as class_name
FROM
    dev_atatur.class_ATC_RXN_huge_temp t1
    JOIN devv5.concept_relationship cr ON t1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'RxNorm is a'
    JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.invalid_reason IS NULL
                                                             AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
;


---------------Первый проход анцестоора-------------------------

drop table if exists class_ATC_RXN_huge;
create table class_ATC_RXN_huge as

SELECT distinct *
FROM
    (
        SELECT
               t2.class_code,
               t2.class_name,
               'ATC - RxNorm' as relationship_id,
               t1.concept_class_id,
               ids,
               names,
               source
        FROM
            class_ATC_RXN_huge_temp t2
        join
            class_ATC_RXN_huge_ancestor_temp t1

            on t2.concept_id = t1.concept_id) full_table
UNION

        (select     ------ Чтобы не терялись некоторые коды после работы с анцестором
                class_code,
                class_name,
                'ATC - RxNorm' as relationship_id,
                concept_class_id,
                concept_id,
                concept_name,
                source
        from class_ATC_RXN_huge_temp);
------------------------------------------------------

--------Расширение промежуточной таблицы за счет RxNorm is a---------------------------

insert into class_ATC_RXN_huge
SELECT
    t1.class_code as class_code,
    t1.class_name as class_name,
    t1.relationship_id as relationship_id,
    t2.concept_class_id as concept_class_id,
    t2.concept_id as ids,
    t2.concept_name as names,
    'RxNorm_is_a' as source
FROM dev_atatur.class_ATC_RXN_huge t1
JOIN devv5.concept_relationship cr ON t1.ids = cr.concept_id_1
    AND cr.relationship_id = 'RxNorm is a'
JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id
    AND t2.invalid_reason IS NULL
    AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');
--
-- -------- Второй прогон анцестора и финальная временная таблица----------

drop table if exists class_ATC_RXN_huge_fin;
create table class_ATC_RXN_huge_fin as

SELECT distinct *
FROM
    (
        SELECT
               t2.class_code,
               t2.class_name,
               t2.relationship_id,
               t1.concept_class_id,
               t1.ids,
               t1.names,
               source
        FROM
            class_ATC_RXN_huge t2
        join
            class_ATC_RXN_huge_ancestor_temp t1
              on t2.ids = t1.concept_id
              and t2.names = t1.concept_name) full_table

UNION

(SELECT * FROM class_ATC_RXN_huge)
;
--
-- ------------------- Clinical Drug Form Extension with RxNormIsA connection---------------------
--
INSERT INTO dev_atatur.class_ATC_RXN_huge_fin (
    class_code,
    class_name,
    relationship_id,
    concept_class_id,
    ids,
    names,
    source
)
SELECT
    t1.class_code,
    t1.class_name,
    t1.relationship_id,
    t2.concept_class_id,
    cr.concept_id_2::INT as ids,
    t2.concept_name as names,
    'RxNorm_is_a' as source
FROM dev_atatur.class_ATC_RXN_huge_fin t1
JOIN devv5.concept_relationship cr ON t1.ids = cr.concept_id_1
    AND t1.concept_class_id in ('Clinical Drug', 'Clinical Drug Form', 'Quant Clinical Drug')  ---- Эти формы могут давать после Reverse is a в итоге Clinical Drug Form

    AND cr.relationship_id = 'RxNorm is a'
JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id
    AND t2.invalid_reason IS NULL
    AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');



-------Формируем результирущую таблицу выделяя Distinct Value
DROP TABLE IF EXISTS dev_atatur.class_ATC_RXN_huge_fin__11_7_24_rxis;
create table dev_atatur.class_ATC_RXN_huge_fin__11_7_24_rxis as
select distinct *
    from dev_atatur.class_ATC_RXN_huge_fin;




-------------- Step-Aside approach------------------
drop table if exists  step_aside_source;
create table step_aside_source as
    select distinct t1.concept_id,
                                            t1.concept_name,
                                            array_agg(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
                                            array_agg(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
                                            t2.concept_id                                       AS dose_form_id,
                                            t2.concept_name                                     AS dose_form_name,
                                            t3.concept_id                                       AS dose_form_group_id,
                                            t3.concept_name                                     AS dose_form_group_name,
                                            t4.concept_id                                       AS potential_dose_form_id,
                                            t4.concept_name                                     AS potential_dose_form_name
                            from devv5.concept t1
                                     --Dose Form
                                     join devv5.concept_relationship cr
                                          on cr.concept_id_1 = t1.concept_id and
                                             t1.concept_class_id = 'Clinical Drug Form' and
                                             cr.relationship_id = 'RxNorm has dose form' and cr.invalid_reason IS NULL
                                     join devv5.concept t2
                                          on cr.concept_id_2 = t2.concept_id and t2.invalid_reason is null and
                                             t2.concept_class_id in ('Dose Form')
                                --Dose Form Group
                                     join devv5.concept_relationship cr2 on cr2.concept_id_1 = t2.concept_id and
                                                                            cr2.relationship_id = 'RxNorm is a' and
                                                                            cr2.invalid_reason is null
                                     join devv5.concept t3
                                          on cr2.concept_id_2 = t3.concept_id and t3.invalid_reason is null and
                                             t3.concept_class_id = 'Dose Form Group'
                                --all potential forms in the group
                                     join devv5.concept_relationship cr3 on cr3.concept_id_1 = t3.concept_id and
                                                                            cr3.relationship_id =
                                                                            'RxNorm inverse is a' and
                                                                            cr3.invalid_reason is null
                                     join devv5.concept t4
                                          on cr3.concept_id_2 = t4.concept_id and t4.invalid_reason is null and
                                             t4.concept_class_id = 'Dose Form'

                                --Ingredients
                                     join devv5.concept_relationship cr4
                                          on cr4.concept_id_1 = t1.concept_id and
                                             t1.concept_class_id = 'Clinical Drug Form' and
                                             cr4.relationship_id = 'RxNorm has ing' and cr4.invalid_reason IS NULL
                                     join devv5.concept t5
                                          on cr4.concept_id_2 = t5.concept_id and t5.invalid_reason is null and
                                             t5.concept_class_id = 'Ingredient'

                            where t1.concept_id in (select distinct ids
                                                    from dev_atatur.class_atc_rxn_huge_fin__11_7_24_rxis    --------- Here should be name of source table!
                                                    where concept_class_id = 'Clinical Drug Form')
                              --filter out not useful dose form groups
                              and t3.concept_id NOT IN (
                                36217216 --Pill
                                )

                            GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name, t3.concept_id,
                                     t3.concept_name, t4.concept_id, t4.concept_name;

drop table if exists  step_aside_target;
    create table step_aside_target as
    select distinct t1.concept_id,
                                            t1.concept_name,
                                            array_agg(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
                                            array_agg(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
                                            t2.concept_id                                       AS dose_form_id,
                                            t2.concept_name                                     AS dose_form_name
                            from devv5.concept t1
                                     --Dose Form
                                     join devv5.concept_relationship cr
                                          on cr.concept_id_1 = t1.concept_id and
                                             t1.concept_class_id = 'Clinical Drug Form' and
                                             cr.relationship_id = 'RxNorm has dose form' and cr.invalid_reason IS NULL
                                     join devv5.concept t2
                                          on cr.concept_id_2 = t2.concept_id and t2.invalid_reason is null and
                                             t2.concept_class_id in ('Dose Form')

                                --Ingredients
                                     join devv5.concept_relationship cr4
                                          on cr4.concept_id_1 = t1.concept_id and
                                             t1.concept_class_id = 'Clinical Drug Form' and
                                             cr4.relationship_id = 'RxNorm has ing' and cr4.invalid_reason IS NULL
                                     join devv5.concept t5
                                          on cr4.concept_id_2 = t5.concept_id and t5.invalid_reason is null and
                                             t5.concept_class_id = 'Ingredient'

                            GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name;
drop table if exists atc_step_aside_final;
create table atc_step_aside_final as
select
    s.concept_id as source_concept_id,
    s.concept_name as source_concept_name,
    t.concept_id as target_concept_id,
    t.concept_name as target_concept_name
from step_aside_source s
      join step_aside_target t
      on s.array_ing = t.array_ing and t.dose_form_id != s.dose_form_id and s.concept_id != t.concept_id
      and t.dose_form_id = s.potential_dose_form_id
order by s.concept_id;

DROP TABLE IF EXISTS new_atc_codes_rxnorm;
CREATE TABLE new_atc_codes_rxnorm as
SELECT *
FROM
(select t1.class_code,
       t1.class_name,
       t1.relationship_id,
       t1.concept_class_id,
       t2.target_concept_id as ids,
       t2.target_concept_name as names,
       t1.source || ' - aside' as source
from dev_atatur.class_atc_rxn_huge_fin__11_7_24_rxis t1
     join atc_step_aside_final t2 on t1.ids = t2.source_concept_id and t1.concept_class_id = 'Clinical Drug Form') t1

UNION

(select
    *
from
    dev_atatur.class_atc_rxn_huge_fin__11_7_24_rxis);
-------------------------------------------------------------

DROP TABLE IF EXISTS class_atc_rxn_huge_fin__11_7_24_rxis;
DROP TABLE IF EXISTS step_aside_source;
DROP TABLE IF EXISTS step_aside_target;
DROP TABLE IF EXISTS atc_step_aside_final;
DROP TABLE IF EXISTS class_atc_rxn_huge_fin__11_7_24_rxis;
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin;
DROP TABLE IF EXISTS class_ATC_RXN_huge_temp;
DROP TABLE IF EXISTS class_ATC_RXN_huge_ancestor_temp;
DROP TABLE IF EXISTS class_ATC_RXN_huge;

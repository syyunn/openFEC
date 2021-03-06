SET search_path = public, pg_catalog;

--
-- 1)MV Name: ofec_audit_case_mv; Type: MATERIALIZED VIEW; Schema: public; Owner: fec
--

DROP MATERIALIZED VIEW ofec_audit_case_mv;
CREATE MATERIALIZED VIEW ofec_audit_case_mv AS
WITH 
cmte_info AS (
    SELECT DISTINCT dc.cmte_id,
        dc.cmte_nm,
        dc.fec_election_yr,
        dc.cmte_dsgn,
        dc.cmte_tp,
        b.filed_cmte_tp_desc::text AS cmte_desc
    FROM auditsearch.audit_case aa, disclosure.cmte_valid_fec_yr dc, staging.ref_filed_cmte_tp b
    WHERE btrim(aa.cmte_id::text) = dc.cmte_id::text
      AND aa.election_cycle = dc.fec_election_yr
      AND dc.cmte_tp::text IN ('H', 'S', 'P', 'X', 'Y', 'Z', 'N', 'Q', 'I', 'O')
      AND dc.cmte_tp::text = b.filed_cmte_tp_cd::text
), 
cand_info AS (
    SELECT DISTINCT dc.cand_id,
        dc.cand_name,
        "substring"(dc.cand_name::text, 1,
            CASE
                WHEN strpos(dc.cand_name::text, ','::text) > 0 THEN strpos(dc.cand_name::text, ','::text) - 1
                ELSE strpos(dc.cand_name::text, ','::text)
            END) AS last_name,
        "substring"(dc.cand_name::text, strpos(dc.cand_name::text, ','::text) + 1) AS first_name,
        dc.fec_election_yr
    FROM auditsearch.audit_case aa JOIN disclosure.cand_valid_fec_yr dc
    ON (btrim(aa.cand_id::text) = dc.cand_id::text AND aa.election_cycle = dc.fec_election_yr)
),
audit_case_finding_info AS (
    SELECT
        audit_case_finding.audit_case_id::text AS audit_case_id,
        audit_case_finding.parent_finding_pk::text AS primary_category_id,
        audit_case_finding.child_finding_pk::text AS sub_category_id
    FROM auditsearch.audit_case_finding
),
audit_case_subset AS (
    SELECT 
        audit_case_finding_info.primary_category_id,
        audit_case_finding_info.sub_category_id,
        audit_case_finding_info.audit_case_id,
        auditsearch.audit_case.election_cycle::integer AS cycle,
        auditsearch.audit_case.cmte_id AS committee_id,
        cmte_info.cmte_nm AS committee_name,
        cmte_info.cmte_dsgn AS committee_designation,
        cmte_info.cmte_tp AS committee_type,
        cmte_info.cmte_desc AS committee_description,
        auditsearch.audit_case.far_release_date::date AS far_release_date,
        auditsearch.audit_case.link_to_report,
        auditsearch.audit_case.audit_id::integer AS audit_id,
        auditsearch.audit_case.cand_id AS candidate_id,
        coalesce(cand_info.cand_name, 'No authorized candidate'::text::character varying) AS candidate_name
    FROM audit_case_finding_info
    LEFT JOIN auditsearch.audit_case ON audit_case_finding_info.audit_case_id = audit_case.audit_case_id::text
    LEFT JOIN cmte_info ON cmte_info.cmte_id::text = audit_case.cmte_id::text AND cmte_info.fec_election_yr = audit_case.election_cycle
    LEFT JOIN cand_info ON cand_info.cand_id::text = audit_case.cand_id::text AND cand_info.fec_election_yr = audit_case.election_cycle
),
audit_case_all AS (
    SELECT
        audit_case_subset.primary_category_id,
        audit_case_subset.sub_category_id,
        audit_case_subset.audit_case_id,
        audit_case_subset.cycle,
        audit_case_subset.committee_id,
        audit_case_subset.committee_name,
        audit_case_subset.committee_designation,
        audit_case_subset.committee_type,
        audit_case_subset.committee_description,
        audit_case_subset.far_release_date,
        audit_case_subset.link_to_report,
        audit_case_subset.audit_id,
        audit_case_subset.candidate_id,
        audit_case_subset.candidate_name
    FROM audit_case_subset
    UNION
    SELECT DISTINCT 
        'all' AS primary_category_id,
        'all' AS sub_category_id,
        audit_case_subset.audit_case_id,
        audit_case_subset.cycle,
        audit_case_subset.committee_id,
        audit_case_subset.committee_name,
        audit_case_subset.committee_designation,
        audit_case_subset.committee_type,
        audit_case_subset.committee_description,
        audit_case_subset.far_release_date,
        audit_case_subset.link_to_report,
        audit_case_subset.audit_id,
        audit_case_subset.candidate_id,
        audit_case_subset.candidate_name
    FROM audit_case_subset
    LEFT JOIN audit_case_finding_info ON audit_case_finding_info.audit_case_id = audit_case_subset.audit_case_id
    UNION
    SELECT DISTINCT 
        audit_case_subset.primary_category_id,
        'all' AS sub_category_id,
        audit_case_subset.audit_case_id,
        audit_case_subset.cycle,
        audit_case_subset.committee_id,
        audit_case_subset.committee_name,
        audit_case_subset.committee_designation,
        audit_case_subset.committee_type,
        audit_case_subset.committee_description,
        audit_case_subset.far_release_date,
        audit_case_subset.link_to_report,
        audit_case_subset.audit_id,
        audit_case_subset.candidate_id, 
        audit_case_subset.candidate_name
    FROM audit_case_subset
    LEFT JOIN audit_case_finding_info ON audit_case_finding_info.audit_case_id = audit_case_subset.audit_case_id
    AND audit_case_subset.primary_category_id = audit_case_finding_info.primary_category_id
)
SELECT 
    row_number() OVER () AS idx,
    audit_case_all.primary_category_id,
    audit_case_all.sub_category_id,
    audit_case_all.audit_case_id,
    audit_case_all.cycle,
    audit_case_all.committee_id,
    audit_case_all.committee_name,
    audit_case_all.committee_designation,
    audit_case_all.committee_type,
    audit_case_all.committee_description,
    audit_case_all.far_release_date,
    audit_case_all.link_to_report,
    audit_case_all.audit_id,
    audit_case_all.candidate_id,
    audit_case_all.candidate_name
FROM audit_case_all
ORDER BY cycle DESC, committee_name
WITH DATA;
ALTER TABLE ofec_audit_case_mv OWNER TO fec;
CREATE UNIQUE INDEX ON ofec_audit_case_mv(idx);
CREATE INDEX ON ofec_audit_case_mv(audit_case_id);
CREATE INDEX ON ofec_audit_case_mv(primary_category_id, sub_category_id, audit_case_id);
GRANT ALL ON TABLE ofec_audit_case_mv TO fec;
GRANT SELECT ON TABLE ofec_audit_case_mv TO fec_read;
GRANT SELECT ON TABLE ofec_audit_case_mv TO openfec_read;

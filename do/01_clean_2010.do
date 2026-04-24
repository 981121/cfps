*******************************************************
* File:    01_clean_2010.do
* Purpose: Clean 2010 CFPS adult file
*          Output: data/clean/person_2010.dta
*                  docs/var_dictionary_2010.csv
*
* Source:  $RAW/2010/cfps2010adult_201906.dta
*          N = 33,600 observations
*
* VARIABLE MAPPING NOTES (2010-specific — verified 2026-04-20):
*
*   CONFIRMED mappings (safe to use):
*     pid, fid, provcd     — same names as later waves; no rename needed.
*                            Note: fid has NO wave suffix in 2010 (unlike fid12, fid14...).
*     gender               — same name as later waves
*     qa1y_best            → birth_year  [出生日期修正（年）]
*     cfps2010edu_best     → edu_level   [已完成最高学历]
*     cfps2010eduy_best    → years_schooling [受教育年限]
*     urban                → urban  [NBS城乡分类, same classification series as urban12..urban22]
*                            Note: no wave suffix in 2010 raw file.
*     income               → income  [个人收入, same as 2012-2018]
*     pid_f, pid_m         → father_pid, mother_pid  [in adult file directly, same as 2012/2014]
*     qa5code              → ethnicity  [民族成分编码 — actual numeric code,
*                            BETTER than 2018/2020/2022 where minzu is only a flag]
*     children             — counted from famconf code_a_c1..code_a_c10 (slot > 0)
*                            Source: cfps2010famconf_report_nat072016.dta
*                            code_a_c* > 0 counts ALL children (incl. non-CFPS-sample);
*                            pid_c* would miss children not enrolled in CFPS.
*
*   VERIFIED mappings (manually cross-validated 2026-04-20):
*
*   marital_status: qe1_best
*     Codes confirmed consistent with qe104 (2012) and qea0 (2014+).
*     Safe to pool across waves.
*
*   employ: qg3
*     Codes confirmed consistent with later waves' derived employ variable.
*     Safe to pool across waves.
*
*   urban: NBS classification confirmed to use same boundaries as urban12..urban22.
*
* Updated: 2026-04-20 (verified 2026-04-20)
*******************************************************

clear all
set more off

local pid_min = 100000000

use "$RAW/2010/cfps2010adult_201906.dta", clear

display "Cleaning 2010 wave: N = " _N

* ─────────────────────────────────────────────────────────
* 1. Keep core variables
* ─────────────────────────────────────────────────────────
* Note: fid and urban have no wave suffix in the 2010 raw file.
local keep_vars ""
foreach v in pid fid provcd gender qa1y_best ///
             cfps2010edu_best cfps2010eduy_best ///
             urban income ///
             qe1_best qg3 ///
             qa5code qb1 ///
             pid_f pid_m {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}
keep `keep_vars'

* ─────────────────────────────────────────────────────────
* 2. Generate wave and year identifiers
* ─────────────────────────────────────────────────────────
gen wave = 2010
gen year = 2010
label variable wave "CFPS wave"
label variable year "Survey year"

* ─────────────────────────────────────────────────────────
* 3. Rename to standard names
* ─────────────────────────────────────────────────────────

* birth year — corrected version
rename qa1y_best birth_year
label variable birth_year "Birth year (corrected) [orig: qa1y_best]"

* education
rename cfps2010edu_best edu_level
label variable edu_level ///
    "Highest completed education level [orig: cfps2010edu_best]"

rename cfps2010eduy_best years_schooling
label variable years_schooling ///
    "Years of schooling [orig: cfps2010eduy_best]"

* urban — NBS classification; no wave suffix in 2010 raw
* The variable is already named 'urban', so no rename needed.
* But we label it to match the project convention.
label variable urban ///
    "Urban/rural: NBS classification [orig: urban; equiv. to urban12..urban22]"

* employment [UNCERTAIN-2: see header notes]
rename qg3 employ
label variable employ ///
    "Has job now (1/0/-8→.) [orig: qg3; verified consistent with later waves' employ]"

rename qe1_best marital_status
label variable marital_status ///
    "Current marital status [orig: qe1_best; verified consistent with qe104/qea0]"

* ethnicity — actual ethnicity code (better quality than 2018+)
rename qa5code ethnicity
label variable ethnicity ///
    "Ethnicity code [orig: qa5code; actual code, unlike 2018+ flag-only minzu]"

* parent PIDs — directly in adult file (like 2012/2014)
rename pid_f father_pid
label variable father_pid "Father PID [orig: pid_f; from adult file directly]"

rename pid_m mother_pid
label variable mother_pid "Mother PID [orig: pid_m; from adult file directly]"

* ─────────────────────────────────────────────────────────
* 4. Recode sentinel values
*    Same sentinel set as 02_build_kinship_backbone.do:
*    negative values (-10 to -1) and small positive codes
*    (77/78/79) are treated as missing via pid < pid_min.
*    For non-PID variables, standard CFPS sentinels apply.
* ─────────────────────────────────────────────────────────
foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

* Standard CFPS negative sentinel recodes for non-PID vars
* (−8 = 不适用, −9 = 缺失, −1 = 不知道, −2 = 拒绝)
foreach v in birth_year edu_level years_schooling urban ///
             income employ marital_status ethnicity {
    capture replace `v' = . if `v' < 0
}

* qb1: number of siblings (own sibling count, 2010 adult)
* Sentinels: negatives → .; 77/78/79 are common CFPS "don't know/refuse/N.A." codes
capture replace qb1 = . if qb1 < 0
capture replace qb1 = . if inlist(qb1, 77, 78, 79)
* Rename to own_sib for consistency with father_sib / mother_sib naming convention
capture rename qb1 own_sib

* ─────────────────────────────────────────────────────────
* 5. Count children from 2010 famconf (code_a_c1..code_a_c10)
*    Source: cfps2010famconf_report_nat072016.dta
*    Matches approach used in 2018–2022 waves.
*    The 2010 adult file does NOT contain code_a_c* columns.
* ─────────────────────────────────────────────────────────
tempfile childcount2010

preserve
    use "$RAW/2010/cfps2010famconf_report_nat072016.dta", clear

    * Use code_a_c* > 0 to count children.
    * code_a_c* is the household roster slot code: > 0 whenever a child occupies
    * that slot, regardless of whether the child is a CFPS sample member.
    * pid_c* would miss non-sample children (no PID assigned). Consistent with
    * the approach used in 2018/2020/2022 waves.
    gen children = 0
    forvalues j = 1/10 {
        capture confirm variable code_a_c`j'
        if !_rc {
            replace children = children + 1 ///
                if !missing(code_a_c`j') & code_a_c`j' > 0
        }
    }
    label variable children ///
        "Number of children [counted from famconf code_a_c1..code_a_c10, slot > 0]"

    * Collapse to one row per pid (handles duplicate pid rows in famconf)
    drop if missing(pid) | pid < `pid_min'
    collapse (max) children, by(pid)

    save `childcount2010'
restore

* Merge children count back onto 2010 person file
* Use m:1 in case adult file has duplicate pid rows; childcount2010 is unique by pid
merge m:1 pid using `childcount2010', nogenerate keep(master match)

* Respondents not in famconf get children = 0 (no child rows found)
replace children = 0 if missing(children)

gen has2plus = (children >= 2)
label variable has2plus "Has 2+ children (0/1)"

* ─────────────────────────────────────────────────────────
* 6. Finalize IDs
* ─────────────────────────────────────────────────────────
* fid and provcd already have correct names; add labels.
label variable fid    "Household ID [orig: fid; no wave suffix in 2010 raw]"
label variable provcd "Province code [orig: provcd]"
label variable pid    "Individual PID"
label variable gender "Gender [orig: gender]"
label variable income "Individual income (annual) [orig: income]"
capture label variable own_sib "Number of siblings (self-reported, 2010) [orig: qb1]"

* ─────────────────────────────────────────────────────────
* 7. Quick data check
* ─────────────────────────────────────────────────────────
display "  N = " _N
count if missing(pid)
display "  Missing pid: " r(N)
count if !missing(father_pid)
display "  father_pid non-missing: " r(N)
count if !missing(mother_pid)
display "  mother_pid non-missing: " r(N)
summarize children, detail
summarize birth_year

* ─────────────────────────────────────────────────────────
* 8. Save clean file
* ─────────────────────────────────────────────────────────
order pid fid provcd wave year gender birth_year ethnicity ///
      marital_status children has2plus edu_level years_schooling ///
      income employ urban own_sib father_pid mother_pid

compress
save "$CLEAN/person_2010.dta", replace
display "Saved: $CLEAN/person_2010.dta"

* ─────────────────────────────────────────────────────────
* 9. Export variable dictionary
* ─────────────────────────────────────────────────────────
preserve
ds
local vars `r(varlist)'

local nvars = 0
foreach v of local vars {
    local ++nvars
    local vname_`nvars' "`v'"
    local vlab_`nvars'  : variable label `v'
}

clear
set obs `nvars'
gen str32  varname = ""
gen str244 label   = ""

forvalues j = 1/`nvars' {
    quietly replace varname = "`vname_`j''" in `j'
    quietly replace label   = "`vlab_`j''"  in `j'
}

export delimited using "$PROJ/docs/var_dictionary_2010.csv", replace
restore

display _newline "01_clean_2010 complete."

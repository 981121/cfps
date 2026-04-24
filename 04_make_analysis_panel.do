*******************************************************
* File:    04_make_analysis_panel.do
* Purpose: Build the DiD-ready estimation dataset.
*
*          Pools 7 clean waves into a pid×year long panel,
*          merges time-invariant parental sibship treatment,
*          restricts to the 1975–1984 analysis cohort,
*          and generates post2016.
*
*          Interaction terms and event-study dummies are NOT
*          pre-computed here. Use Stata factor-variable syntax
*          (##) in 05_analysis.do instead.
*
* Input:   $CLEAN/person_{wave}.dta   (7 waves: 2010–2022)
*          $CONS/parent_sibship.dta   (one row per pid)
*
* Output:  $ANLY/did_panel.dta
*              Unit of observation: pid × year
*              Sample: birth_year 1975–1984
*
* Variables in final dataset:
*   IDs:       pid  fid  provcd
*   Time:      year  wave
*   Cohort:    birth_year  gender  ethnicity
*   Outcomes:  children  has2plus
*   Treatment (MAIN — qb1-based parental sibship):
*              parent_multisib   ← MAIN DiD treatment (any-parent OR)
*              father_sib        — father's sibling count (qb1)
*              mother_sib        — mother's sibling count (qb1)
*              father_multisib   — father binary (sib>=1)
*              mother_multisib   — mother binary (sib>=1)
*   Derived:   age  post2016
*   Controls:  marital_status  edu_level  years_schooling
*              income  employ  urban
*   Selection: has_father_link  has_mother_link
*
* Also included (linkage / diagnostic):
*   father_pid  mother_pid   — parent PIDs from backbone (mostly useful for
*                              diagnostics; may be missing for 2016+ respondents)
*   did_*  es_*  wave_YYYY   — use factor variables in estimation instead
*
* Merge key: pid (m:1 from parent_sibship into long panel)
*
* Updated: 2026-04-20 (rewritten for qb1-based parental sibship from 2010 adult)
*******************************************************

clear all
set more off

display "Building DiD analysis panel..."

* ─────────────────────────────────────────────────────────
* 1. Append all 7 clean person files into a long panel
*
*    Only variables needed for analysis are kept.
*    Intermediate parent/grandparent PID columns are excluded.
* ─────────────────────────────────────────────────────────

local keep_vars pid fid provcd wave year ///
    birth_year gender ethnicity ///
    children has2plus ///
    father_pid mother_pid ///
    marital_status edu_level years_schooling ///
    income employ urban own_sib ka205

* Load 2010 as base
use "$CLEAN/person_2010.dta", clear
local keep_this ""
foreach v of local keep_vars {
    capture confirm variable `v'
    if !_rc local keep_this `keep_this' `v'
}
keep `keep_this'
local N_2010 = _N
display "  2010: `N_2010' obs"

* Append 2012–2022
foreach yr in 2012 2014 2016 2018 2020 2022 {
    preserve
    use "$CLEAN/person_`yr'.dta", clear
    local keep_this ""
    foreach v of local keep_vars {
        capture confirm variable `v'
        if !_rc local keep_this `keep_this' `v'
    }
    keep `keep_this'
    tempfile w`yr'
    save `w`yr''
    restore
    append using `w`yr''
    display "  After appending `yr': " _N " obs"
}

local N_adult_raw = _N
display "  Pooled adult waves (all cohorts): `N_adult_raw' obs"

* ─────────────────────────────────────────────────────────
* 1b. Append child questionnaire files
*     child_2012.dta (wka202) and child_2020.dta (ka205)
*     These respondents have their own PIDs and are appended
*     as additional rows; wave-specific vars missing elsewhere.
* ─────────────────────────────────────────────────────────

local child_keep pid fid provcd wave year ///
    birth_year gender ethnicity ///
    children has2plus ///
    marital_status edu_level years_schooling ///
    income employ urban ///
    father_pid mother_pid ///
    wka202

foreach cwave in 2012 2020 {
    capture confirm file "$CLEAN/child_`cwave'.dta"
    if !_rc {
        preserve
        use "$CLEAN/child_`cwave'.dta", clear
        local keep_c ""
        foreach v of local child_keep {
            capture confirm variable `v'
            if !_rc local keep_c `keep_c' `v'
        }
        keep `keep_c'
        tempfile wc`cwave'
        save `wc`cwave''
        restore
        append using `wc`cwave''
        display "  After appending child_`cwave': " _N " obs"
    }
    else {
        display as text "  NOTE: $CLEAN/child_`cwave'.dta not found — skipping"
    }
}

local N_all_raw = _N
display "  Pooled (adult + child waves): `N_all_raw' obs"

* ─────────────────────────────────────────────────────────
* 2. Drop missing/invalid pid
*    Handles 2014 non-core household members (pid = .)
* ─────────────────────────────────────────────────────────
local pid_min = 100000000
drop if missing(pid) | pid < `pid_min'
local N_valid_pid = _N
display "  After dropping missing/invalid pid: `N_valid_pid' obs"
display "  Obs dropped (invalid pid): " (`N_all_raw' - `N_valid_pid')

* ─────────────────────────────────────────────────────────
* 3. [No cohort restriction here]
*    The full cross-cohort panel is kept so that 05_analysis.do
*    can apply sample restrictions (e.g. birth_year 1975–1984)
*    in one place and vary them for sensitivity checks.
* ─────────────────────────────────────────────────────────
display "  Full panel retained (no cohort restriction in 04)"

* ─────────────────────────────────────────────────────────
* 4. Merge parental sibship (time-invariant treatment)
*    Merge key: pid (m:1)
*    keep(master match): individuals not in backbone keep their
*    rows but receive missing treatment values.
*    No observation loss expected from this merge.
* ─────────────────────────────────────────────────────────
merge m:1 pid using "$CONS/parent_sibship.dta", ///
    keepusing(parent_multisib                                       ///
              father_sib        mother_sib                          ///
              father_multisib   mother_multisib                     ///
              has_father_link   has_mother_link)                    ///
    keep(master match) nogenerate

* Verify no unexpected obs loss
local N_post_merge = _N
if `N_post_merge' != `N_valid_pid' {
    display as error "WARNING: unexpected obs change in sibship merge."
    display as error "  Before: `N_valid_pid'  After: `N_post_merge'"
}
else {
    display "  Sibship merge: no obs lost (as expected). N = `N_post_merge'"
}

* ─────────────────────────────────────────────────────────
* 4b. Supplement sibship for child respondents
*     backbone-based parent_sibship.dta does not cover
*     children in the child questionnaire (pid_f/pid_m are
*     not in the adult backbone). Backfill using the direct
*     pid_f/pid_m merge output from 99_diagnose_child_sibship.
*
*     Strategy: replace only where currently missing.
*     Adult rows already resolved by Step 4 are untouched.
* ─────────────────────────────────────────────────────────
capture confirm file "$CONS/child_parentsib_2012.dta"
if !_rc {
    * Load supplement: pid + sib vars only
    preserve
    use pid father_sib mother_sib ///
        father_multisib mother_multisib parent_multisib ///
        using "$CONS/child_parentsib_2012.dta", clear
    * Rename to avoid collision with existing vars during merge
    foreach v in father_sib mother_sib ///
                 father_multisib mother_multisib parent_multisib {
        rename `v' _supp_`v'
    }
    tempfile child_sib_supp
    save `child_sib_supp'
    restore

    merge m:1 pid using `child_sib_supp', keep(master match) nogenerate

    * Backfill: only replace where backbone merge left missing
    foreach v in father_sib mother_sib ///
                 father_multisib mother_multisib parent_multisib {
        replace `v' = _supp_`v' if missing(`v') & !missing(_supp_`v')
        drop _supp_`v'
    }

    count if !missing(father_sib)
    display "  After child supplement — father_sib non-missing: " r(N)
    count if !missing(mother_sib)
    display "  After child supplement — mother_sib non-missing: " r(N)
    count if !missing(parent_multisib)
    display "  After child supplement — parent_multisib resolved: " r(N)
}
else {
    display as text "  NOTE: child_parentsib_2012.dta not found — skipping supplement."
    display as text "        Run 99_diagnose_child_sibship.do first to generate it."
}

* ─────────────────────────────────────────────────────────
* 5. Derived variables
* ─────────────────────────────────────────────────────────

* Age at survey
gen age = wave - birth_year
label variable age "Age at survey (wave - birth_year)"

* Post-treatment indicator
* Use year (== wave in CFPS) to align with standard DiD convention
gen post2016 = (year >= 2016)
label variable post2016 "Post two-child policy: 1 if year >= 2016"

* ─────────────────────────────────────────────────────────
* 6. Variable labels
* ─────────────────────────────────────────────────────────
label variable pid             "Individual PID"
label variable fid             "Household ID (wave-specific)"
label variable provcd          "Province code"
label variable wave            "CFPS wave year"
label variable year            "Survey year"
label variable birth_year      "Birth year"
label variable gender          "Gender"
label variable ethnicity       "Ethnicity code"
label variable age             "Age at survey"
label variable children        "Number of children at survey"
label variable has2plus        "Has 2+ children (0/1)"
* Main treatment (qb1-based parental sibship)
label variable parent_multisib   "MAIN DiD treatment: any observed parent had ≥1 sibling [qb1, OR] (0/1/.)"
label variable father_sib        "Father's sibling count [orig: qb1, 2010 adult]"
label variable mother_sib        "Mother's sibling count [orig: qb1, 2010 adult]"
label variable father_multisib   "Father had ≥1 sibling per 2010 qb1 (0/1/.)"
label variable mother_multisib   "Mother had ≥1 sibling per 2010 qb1 (0/1/.)"
capture label variable father_pid        "Father PID [from backbone; 2010/2012/2014 from adult file; 2016+ from famconf]"
capture label variable mother_pid        "Mother PID [from backbone; 2010/2012/2014 from adult file; 2016+ from famconf]"
label variable has_father_link   "1 if father_pid non-missing in backbone"
label variable has_mother_link   "1 if mother_pid non-missing in backbone"
label variable marital_status  "Current marital status"
label variable edu_level       "Highest education level"
label variable years_schooling "Years of schooling"
label variable income          "Individual income (annual)"
label variable employ          "Currently employed (1/0)"
label variable urban           "Urban: NBS classification"
capture label variable own_sib "Number of siblings (self-reported, 2010) [orig: qb1; 2010 wave only]"
capture label variable ka205   "ka205 [orig: qka205; 2020 adult wave only]"


* ─────────────────────────────────────────────────────────
* 7. Validate panel structure
* ─────────────────────────────────────────────────────────

* 7a. Check for duplicate pid × year combinations
duplicates report pid year
if r(N) != _N {
    display as error "ERROR: duplicate pid × year rows detected. Investigate before saving."
    error 1
}

* 7b. Confirm pid × year is unique identifier
isid pid year
display "  OK: pid × year is unique identifier"

* ─────────────────────────────────────────────────────────
* 8. Order variables and save
* ─────────────────────────────────────────────────────────
order pid fid provcd wave year birth_year gender ethnicity age ///
      post2016 ///
      children has2plus ///
      father_pid mother_pid ///
      parent_multisib father_sib mother_sib father_multisib mother_multisib ///
      has_father_link has_mother_link ///
      marital_status edu_level years_schooling income employ urban

* Wave-specific variables: present only for their respective wave, missing otherwise
* own_sib: 2010 only  |  wka202: 2012 only  |  ka205: 2020 only
capture order own_sib wka202 ka205, last

compress
save "$ANLY/did_panel.dta", replace
display "Saved: $ANLY/did_panel.dta"

* ─────────────────────────────────────────────────────────
* 9. SAMPLE SIZE REPORT
*    Runs after save — cannot corrupt output.
* ─────────────────────────────────────────────────────────

display _newline
display "=================================================="
display "  SAMPLE SIZE REPORT — did_panel.dta"
display "=================================================="

* ── 9a. Overall panel ────────────────────────────────────
local N_total = _N
bysort pid: gen _pf = (_n == 1)
count if _pf
local N_indiv = r(N)
drop _pf

display _newline "  [1] OVERALL PANEL"
display "  Total observations:       `N_total'"
display "  Total unique individuals: `N_indiv'"

* ── 9b. DiD-usable sample ────────────────────────────────
count if !missing(parent_multisib) & !missing(children) & !missing(has2plus)
local N_did = r(N)
bysort pid: gen _pf2 = (_n == 1) if !missing(parent_multisib)
count if _pf2 == 1
local N_did_indiv = r(N)
drop _pf2

display _newline "  [2] DiD-USABLE SAMPLE"
display "  (non-missing parent_multisib AND both outcomes)"
display "  Observations:  `N_did'"
display "  Individuals:   `N_did_indiv'"

* ── 9c. Treatment coverage (all individuals) ──────────────
bysort pid: gen _pf3 = (_n == 1)

count if _pf3
local N_all_ind = r(N)
display _newline "  [3] TREATMENT COVERAGE (all individuals in panel)"
display "  Total individuals:                `N_all_ind'"
display "  Total observations:               `N_total'"

count if _pf3 & !missing(parent_multisib)
local n_with_treat = r(N)
display "  % with valid parent_multisib:     " ///
    %5.1f `n_with_treat'/`N_all_ind'*100 "% (`n_with_treat' individuals)"

count if !missing(children) & !missing(has2plus)
local n_with_out = r(N)
display "  % obs with valid outcomes:        " ///
    %5.1f `n_with_out'/`N_total'*100 "% (`n_with_out' obs)"

drop _pf3

* ── 9d. Pre vs post ──────────────────────────────────────
count if post2016 == 0
local N_pre = r(N)
count if post2016 == 1
local N_post = r(N)

display _newline "  [4] PRE vs POST 2016"
display "  Pre-2016  (waves 2010 / 2012 / 2014): `N_pre'"
display "  Post-2016 (waves 2016 / 2018 / 2020 / 2022): `N_post'"

* ── 9e. Treatment vs control (at individual level) ───────
bysort pid: gen _pf4 = (_n == 1)

count if _pf4 & parent_multisib == 1
local N_treated = r(N)
count if _pf4 & parent_multisib == 0
local N_control = r(N)
count if _pf4 & missing(parent_multisib)
local N_miss_t  = r(N)
drop _pf4

display _newline "  [5] TREATMENT vs CONTROL (individual level)"
display "  parent_multisib = 1 (treated):        `N_treated'"
display "  parent_multisib = 0 (control):        `N_control'"
display "  parent_multisib = . (unresolved):     `N_miss_t'"

* ── 9f. Missing rates ────────────────────────────────────
display _newline "  [6] MISSING RATES (obs level)"
count if missing(parent_multisib)
display "  parent_multisib missing:   " r(N) " / `N_total' (" ///
    %5.1f r(N)/`N_total'*100 "%)"
count if missing(father_sib)
display "  father_sib missing:        " r(N) " / `N_total' (" ///
    %5.1f r(N)/`N_total'*100 "%)"
count if missing(mother_sib)
display "  mother_sib missing:        " r(N) " / `N_total' (" ///
    %5.1f r(N)/`N_total'*100 "%)"
count if missing(children)
display "  children missing:          " r(N) " / `N_total' (" ///
    %5.1f r(N)/`N_total'*100 "%)"
count if missing(has2plus)
display "  has2plus missing:          " r(N) " / `N_total' (" ///
    %5.1f r(N)/`N_total'*100 "%)"

* ── 9g. Observations by year ─────────────────────────────
display _newline "  [7] OBSERVATIONS BY YEAR"
tabulate year

display "=================================================="
display _newline "04_make_analysis_panel complete."

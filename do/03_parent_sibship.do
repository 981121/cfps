*******************************************************
* File:    03_parent_sibship.do
* Purpose: Construct parental sibship variables for each backbone PID.
*
* ── IDENTIFICATION STRATEGY ─────────────────────────────
*
*   Source: qb1 from the 2010 CFPS adult dataset.
*
*   qb1 = number of siblings reported by the respondent.
*         Does NOT include the respondent themselves.
*         No subtraction needed.
*
*   Linkage:
*     For each focal individual in the backbone,
*     look up qb1 for father_pid and mother_pid
*     from the 2010 adult file.
*     This gives father_sib and mother_sib directly.
*
* ── DATA FLOW ────────────────────────────────────────────
*
*   PHASE A — BUILD qb1_lookup TEMPFILE
*     Active dataset: backbone (loaded first).
*     The lookup is built inside a preserve/restore block
*     so the backbone remains in memory.
*     qb1_lookup schema:  pid → qb1
*
*   PHASE B — MERGE ONTO BACKBONE
*     Explicit reload of backbone_master before merges.
*     All merges use the gen / merge / drop pattern:
*         gen  parent_pid = father_pid   ← copy; source untouched
*         merge m:1 parent_pid using `qb1_lookup'
*         rename qb1 father_sib
*         drop parent_pid
*     father_pid and mother_pid are NEVER renamed.
*
*   PHASE C — CONSTRUCT TREATMENT VARIABLES
*     father_multisib, mother_multisib, parent_multisib.
*
*   PHASE D — DIAGNOSTICS
*     Reload saved file; no risk of corrupting output.
*
* Input:   $CONS/kinship_backbone.dta
*          $RAW/2010/cfps2010adult_201906.dta
*
* Output:  $CONS/parent_sibship.dta
*          Variables (one row per pid):
*
*   Parental sibling counts (from qb1)
*     father_sib, mother_sib
*
*   Binary parental-multisib indicators
*     father_multisib, mother_multisib
*
*   Main treatment variable
*     parent_multisib    ← MAIN DiD TREATMENT
*
*   Linkage flags
*     has_father_link, has_mother_link
*
* Updated: 2026-04-20
*   — Complete rewrite: replaced grandparent/two-hop approach
*     with direct qb1 lookup from 2010 adult dataset.
*   — All *_gp, *_2hop, hop1/hop2, grandparent, and
*     rep_children logic removed.
*******************************************************

clear all
set more off

display "Building parental sibship (qb1-based)..."

local pid_min = 100000000

* ═══════════════════════════════════════════════════════════
* PHASE A: LOAD BACKBONE AND BUILD qb1_lookup TEMPFILE
*
*   Active dataset: backbone throughout Phase A.
*   The lookup is built inside a preserve/restore block.
* ═══════════════════════════════════════════════════════════

* ─────────────────────────────────────────────────────────
* 0. Load backbone; record baseline counts; save to
*    backbone_master tempfile for the explicit Phase B reload.
*
*    Active dataset: backbone (pid, father_pid, mother_pid)
* ─────────────────────────────────────────────────────────
use "$CONS/kinship_backbone.dta", clear
isid pid
local N_bb = _N

display "  Backbone loaded: `N_bb' unique PIDs"
count if !missing(father_pid)
local n0_f = r(N)
display "  father_pid non-missing: `n0_f'"
count if !missing(mother_pid)
local n0_m = r(N)
display "  mother_pid non-missing: `n0_m'"

tempfile backbone_master
save `backbone_master'

* ─────────────────────────────────────────────────────────
* 1. Build qb1_lookup tempfile
*
*    Source:  $RAW/2010/cfps2010adult_201906.dta
*    Key:     pid
*    Returns: qb1  (number of siblings; does not include self)
*
*    Sentinel recodes (standard CFPS convention):
*      All negative codes → missing  (covers −1 不适用,
*      −2 拒绝回答, −8 不知道, and any other negative flag)
*      77 / 78 / 79 → missing  (CFPS non-substantive codes
*      used in some count variables for 不知道/拒绝/不适用)
*
*    isid pid: guard before saving.
*
*    Active dataset going in:  backbone
*    Active dataset coming out: backbone  (restored)
* ─────────────────────────────────────────────────────────
preserve
    * In memory: backbone — replaced by 2010 adult load below,
    * but backbone is restored when this block exits.
    use pid qb1 using "$RAW/2010/cfps2010adult_201906.dta", clear

    * Recode non-substantive sentinels to missing
	* qb1 = respondent's number of siblings; excludes self
    * negative values are non-substantive responses:
    * -8 not applicable, -2 refusal, -1 don't know
    replace qb1 = . if qb1 < 0

    * Drop records with missing pid
    drop if missing(pid) | pid < `pid_min'

    * In the 2010 adult file, pid should already be unique.
    * If duplicates exist (unlikely), keep first non-missing qb1.
    sort pid qb1
    by pid: keep if _n == 1

    rename pid parent_pid
    isid parent_pid
    sort parent_pid

    tempfile qb1_lookup
    save `qb1_lookup'
    * qb1_lookup schema: parent_pid | qb1

    count
    display "  qb1_lookup: " r(N) " unique parent PIDs"
    count if !missing(qb1)
    display "  qb1_lookup: " r(N) " with non-missing qb1"
restore

* ← backbone back in memory

display "  qb1_lookup tempfile built."

* ═══════════════════════════════════════════════════════════
* PHASE B: MERGE qb1 ONTO BACKBONE
*
*   Explicit reload of backbone_master removes any ambiguity
*   about what is in memory.
* ═══════════════════════════════════════════════════════════

* ─────────────────────────────────────────────────────────
* 2. Reload backbone — explicit safety reset
*    Active dataset after this line: backbone
* ─────────────────────────────────────────────────────────
use `backbone_master', clear
assert _N == `N_bb'
display "  Phase B: backbone reloaded. N = `N_bb'"

* ─────────────────────────────────────────────────────────
* 3. Merge father's qb1
*
*    Merge key: parent_pid = gen copy of father_pid
*    father_pid is NEVER renamed.
* ─────────────────────────────────────────────────────────
gen parent_pid = father_pid
merge m:1 parent_pid using `qb1_lookup', keep(master match) nogenerate
rename qb1 father_sib
drop parent_pid

count if !missing(father_sib)
local n_f = r(N)
display "  father_sib resolved: `n_f' / `N_bb' (" ///
    %5.1f `n_f'/`N_bb'*100 "%)"

* ─────────────────────────────────────────────────────────
* 4. Merge mother's qb1
*
*    Merge key: parent_pid = gen copy of mother_pid
*    mother_pid is NEVER renamed.
* ─────────────────────────────────────────────────────────
gen parent_pid = mother_pid
merge m:1 parent_pid using `qb1_lookup', keep(master match) nogenerate
rename qb1 mother_sib
drop parent_pid

count if !missing(mother_sib)
local n_m = r(N)
display "  mother_sib resolved: `n_m' / `N_bb' (" ///
    %5.1f `n_m'/`N_bb'*100 "%)"

* ═══════════════════════════════════════════════════════════
* PHASE C: CONSTRUCT TREATMENT VARIABLES
* ═══════════════════════════════════════════════════════════

* ─────────────────────────────────────────────────────────
* 5. Binary parental-multisib indicators
*
*    multisib = 1 if qb1 >= 1 (at least one sibling)
*             = 0 if qb1 == 0 (only child)
*             = . if qb1 missing (linkage failed)
*
*    CAUTION: Stata evaluates (x >= 1) as TRUE when x is missing
*    (missing treated as +infinity). The !missing() guard is required.
* ─────────────────────────────────────────────────────────
gen father_multisib = .
replace father_multisib = 0 if father_sib == 0
replace father_multisib = 1 if father_sib >= 1 & !missing(father_sib)

gen mother_multisib = .
replace mother_multisib = 0 if mother_sib == 0
replace mother_multisib = 1 if mother_sib >= 1 & !missing(mother_sib)

* ─────────────────────────────────────────────────────────
* 6. Main parental treatment: parent_multisib  ← MAIN DiD TREATMENT
*
*    = 1 if father_multisib == 1 OR mother_multisib == 1
*          (one-side fill: single observed-1 is sufficient)
*    = 0 if father_multisib == 0 AND mother_multisib == 0
*          (both must confirm only-child)
*    = . otherwise (neither parent resolved, or mixed 0/missing)
* ─────────────────────────────────────────────────────────
gen parent_multisib = .
replace parent_multisib = 1 if father_multisib == 1 | mother_multisib == 1
replace parent_multisib = 0 if father_multisib == 0 & mother_multisib == 0

* ─────────────────────────────────────────────────────────
* 7. Linkage flags
* ─────────────────────────────────────────────────────────
gen has_father_link = !missing(father_pid)
gen has_mother_link = !missing(mother_pid)

* ─────────────────────────────────────────────────────────
* 8. Variable labels
* ─────────────────────────────────────────────────────────
label variable father_sib ///
    "Father's sibling count [orig: qb1 in 2010 adult; does not include father himself]"
label variable mother_sib ///
    "Mother's sibling count [orig: qb1 in 2010 adult; does not include mother herself]"
label variable father_multisib ///
    "Father had ≥1 sibling per 2010 qb1 (0/1/.)"
label variable mother_multisib ///
    "Mother had ≥1 sibling per 2010 qb1 (0/1/.)"
label variable parent_multisib ///
    "MAIN DiD treatment: any observed parent had ≥1 sibling [OR, one-side fill] (0/1/.)"
label variable has_father_link ///
    "1 if father_pid non-missing in backbone"
label variable has_mother_link ///
    "1 if mother_pid non-missing in backbone"

* ─────────────────────────────────────────────────────────
* 9. Validate: row count and pid uniqueness unchanged
* ─────────────────────────────────────────────────────────
assert _N == `N_bb'
isid pid
display "  OK: pid uniqueness preserved. N = `N_bb'"

* ─────────────────────────────────────────────────────────
* 10. Save
* ─────────────────────────────────────────────────────────
compress
save "$CONS/parent_sibship.dta", replace
display "Saved: $CONS/parent_sibship.dta"

* ═══════════════════════════════════════════════════════════
* PHASE D: DIAGNOSTICS
*   Reload saved file — cannot corrupt output.
* ═══════════════════════════════════════════════════════════

use "$CONS/parent_sibship.dta", clear

display _newline "=================================================="
display "  PARENT SIBSHIP DIAGNOSTICS"
display "=================================================="

* ─────────────────────────────────────────────────────────
* 11a. Non-missing counts
* ─────────────────────────────────────────────────────────
display _newline "  [A] NON-MISSING COUNTS (all backbone PIDs, N = `N_bb')"

count if !missing(father_sib)
display "  father_sib:       " r(N) " (" %5.1f r(N)/`N_bb'*100 "%)"
count if !missing(mother_sib)
display "  mother_sib:       " r(N) " (" %5.1f r(N)/`N_bb'*100 "%)"
count if !missing(parent_multisib)
display "  parent_multisib:  " r(N) " (" %5.1f r(N)/`N_bb'*100 "%)"

* Unique individuals
count
display "  Total backbone rows: " r(N)

* ─────────────────────────────────────────────────────────
* 11b. Treatment balance
* ─────────────────────────────────────────────────────────
display _newline "  [B] TREATMENT BALANCE: parent_multisib"
tabulate parent_multisib, missing

* ─────────────────────────────────────────────────────────
* 11c. Sibling count distributions
* ─────────────────────────────────────────────────────────
display _newline "  [C] SIBLING COUNT DISTRIBUTIONS"
summarize father_sib mother_sib, detail

* Tabulate sibling counts up to 10 (flag any implausible values)
display _newline "  -- father_sib distribution (values 0–10) --"
tabulate father_sib if father_sib <= 10, missing

display _newline "  -- mother_sib distribution (values 0–10) --"
tabulate mother_sib if mother_sib <= 10, missing

* ─────────────────────────────────────────────────────────
* 11d. Cohort 1975–1984 coverage
* ─────────────────────────────────────────────────────────
display _newline "  [D] COHORT 1975–1984 COVERAGE"

preserve
    foreach yr in 2010 2012 2014 2016 2018 2020 2022 {
        use pid birth_year using "$CLEAN/person_`yr'.dta", clear
        keep if !missing(pid) & pid >= `pid_min'
        tempfile byr`yr'
        save `byr`yr''
    }
    use `byr2010', clear
    foreach yr in 2012 2014 2016 2018 2020 2022 {
        append using `byr`yr''
    }
    keep if !missing(birth_year)
    collapse (firstnm) birth_year, by(pid)
    tempfile byears
    save `byears'
restore

merge 1:1 pid using `byears', keep(master match) nogenerate
gen _in_cohort = (birth_year >= 1975 & birth_year <= 1984 & !missing(birth_year))

count if _in_cohort
local n_coh = r(N)

if `n_coh' == 0 {
    display "  WARNING: No cohort PIDs matched."
}
else {
    display "  Backbone PIDs in cohort 1975–1984: `n_coh'"
    count if _in_cohort & !missing(parent_multisib)
    local n_treat = r(N)
    display "  With valid parent_multisib: `n_treat' (" ///
        %5.1f `n_treat'/`n_coh'*100 "%)"
    count if _in_cohort & parent_multisib == 1
    display "  Treated (parent_multisib = 1): " r(N)
    count if _in_cohort & parent_multisib == 0
    display "  Control  (parent_multisib = 0): " r(N)
    count if _in_cohort & missing(parent_multisib)
    display "  Unresolved (parent_multisib = .): " r(N)
}

display "=================================================="
display _newline "03_parent_sibship complete."

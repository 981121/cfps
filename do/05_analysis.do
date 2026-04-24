*******************************************************
* 05_analysis.do
* Purpose: Main analysis on did_panel.dta
* Project: CFPS fertility and parental sibship
*******************************************************

version 18
clear all
set more off

*******************************************************
* 0. Paths
*******************************************************
* Please adjust these globals to your project structure
* >>> EDIT THIS LINE to your actual project path <<<
global PROJ "/Users/huy/cfps_fertility_project"

global RAW   "$PROJ/data/raw"
global CLEAN "$PROJ/data/clean"
global CONS  "$PROJ/data/constructed"
global ANLY  "$PROJ/data/analysis"
global DO    "$PROJ/do"
global LOG   "$PROJ/logs"
global OUT   "$PROJ/output"



*******************************************************
* 1. Load analysis panel and apply cohort restriction
*******************************************************
use "$ANLY/did_panel.dta", clear

* Restrict to main analysis cohort: birth_year 1975–1984
* Aged 26–35 in 2010; 32–41 at 2016 policy change; 38–47 in 2022.
* Three pre-period waves (2010/2012/2014) and four post-period waves.
keep if birth_year >= 1975 & birth_year <= 1984 & !missing(birth_year)
local N_cohort = _N
display "  After cohort restriction (1975-1984): `N_cohort' obs"

log using "$LOG/05_analysis.log", replace text

display "=================================================="
display "Loaded did_panel.dta"
display "=================================================="

describe
summarize

*******************************************************
* 2. Data cleaning and validation
*******************************************************
display "=================================================="
display "DATA CLEANING AND VALIDATION"
display "=================================================="

*------------------------------------------------------*
* 2a. Recode non-substantive negative values to missing
*------------------------------------------------------*

foreach v in provcd ethnicity children marital_status edu_level ///
             years_schooling income employ urban {
    capture confirm variable `v'
    if !_rc {
        replace `v' = . if `v' < 0
    }
}

*------------------------------------------------------*
* 2b. Additional range checks
*------------------------------------------------------*

* gender should be 0/1
capture confirm variable gender
if !_rc {
    replace gender = . if !inlist(gender, 0, 1)
}

* post2016 should be 0/1
capture confirm variable post2016
if !_rc {
    replace post2016 = . if !inlist(post2016, 0, 1)
}

* urban should be 0/1 after cleaning
capture confirm variable urban
if !_rc {
    replace urban = . if !inlist(urban, 0, 1) & !missing(urban)
}

* children should not be negative after cleaning; impose a sensible upper bound if desired
capture confirm variable children
if !_rc {
    replace children = . if children < 0
    replace children = . if children > 15
}

* father_sib / mother_sib should be nonnegative
capture confirm variable father_sib
if !_rc {
    replace father_sib = . if father_sib < 0
}
capture confirm variable mother_sib
if !_rc {
    replace mother_sib = . if mother_sib < 0
}

* parent_multisib / father_multisib / mother_multisib should be 0/1
foreach v in parent_multisib father_multisib mother_multisib has_father_link has_mother_link {
    capture confirm variable `v'
    if !_rc {
        replace `v' = . if !inlist(`v', 0, 1) & !missing(`v')
    }
}

*------------------------------------------------------*
* 2c. Rebuild has2plus from cleaned children
*------------------------------------------------------*
capture drop has2plus
gen has2plus = children >= 2 if !missing(children)
label variable has2plus "Has 2 or more children (rebuilt from cleaned children)"

*------------------------------------------------------*
* 2d. Rebuild parent_sibsize and treatment thresholds
*------------------------------------------------------*
capture drop parent_sibsize
egen parent_sibsize = rowmax(father_sib mother_sib)
label variable parent_sibsize "Maximum parental sibling count"

* sib1: MAIN binary treatment (any parent ≥ 1 sibling)
capture drop sib1
gen sib1 = parent_sibsize >= 1 if !missing(parent_sibsize)
label variable sib1 "Parent sibsize >= 1 [MAIN binary treatment]"

* sib2: robustness (parent sibsize >= 2)
capture drop sib2
gen sib2 = parent_sibsize >= 2 if !missing(parent_sibsize)
label variable sib2 "Parent sibsize >= 2 [robustness threshold]"

capture drop sib3
gen sib3 = parent_sibsize >= 3 if !missing(parent_sibsize)
label variable sib3 "Parent sibsize >= 3 [robustness threshold]"

*------------------------------------------------------*
* 2e. Simple validation checks
*------------------------------------------------------*
display _newline "---- Post-cleaning summaries ----"
summ children has2plus parent_sibsize father_sib mother_sib sib1 sib2 sib3

display _newline "---- Post-cleaning tabulations ----"
tab children, missing
tab has2plus, missing
tab sib1, missing
tab sib2, missing
tab sib3, missing
tab urban, missing
tab gender, missing

*------------------------------------------------------*
* 2f. Panel consistency check for children
* children is expected to be weakly non-decreasing over time
*------------------------------------------------------*
sort pid year
capture drop child_diff
by pid: gen child_diff = children - children[_n-1] if _n > 1 & !missing(children) & !missing(children[_n-1])

display _newline "---- Changes in children across waves ----"
tab child_diff, missing

* Fix: compute intermediate flag for non-missing obs, then propagate max per pid
capture drop _decline_obs any_child_decline
gen _decline_obs = (child_diff < 0) if !missing(child_diff)
by pid: egen any_child_decline = max(_decline_obs)
drop _decline_obs

display _newline "---- Individuals with any decline in children ----"
tab any_child_decline, missing

display _newline "---- Examples with child decline ----"
list pid year children child_diff if child_diff < 0 in 1/80, sepby(pid) noobs




xtset pid year

*------------------------------------------------------*
* 2g. Reconstruct key treatment variables if needed
*     sib1 = parent_sibsize >= 1 (any parent has ≥1 sibling)
*            This is the MAIN binary treatment.
*     sib2 = parent_sibsize >= 2 (robustness — higher threshold)
*------------------------------------------------------*

capture confirm variable parent_sibsize
if _rc {
    egen parent_sibsize = rowmax(father_sib mother_sib)
    label variable parent_sibsize "Maximum parental sibling count"
}

* sib1: MAIN binary treatment (any parent ≥ 1 sibling)
capture confirm variable sib1
if _rc {
    gen sib1 = parent_sibsize >= 1 if !missing(parent_sibsize)
    label variable sib1 "Parent sibsize >= 1 [MAIN binary treatment]"
}

* sib2: robustness threshold (parent sibsize >= 2)
capture confirm variable sib2
if _rc {
    gen sib2 = parent_sibsize >= 2 if !missing(parent_sibsize)
    label variable sib2 "Parent sibsize >= 2 [robustness threshold]"
}

capture confirm variable did_main
if _rc {
    gen did_main = post2016 * sib1 if !missing(post2016) & !missing(sib1)
    label variable did_main "DiD: post2016 x sib1"
}

capture confirm variable did_cont
if _rc {
    gen did_cont = post2016 * parent_sibsize if !missing(post2016) & !missing(parent_sibsize)
    label variable did_cont "DiD: post2016 x parent_sibsize"
}

capture confirm variable did_father
if _rc {
    gen did_father = post2016 * father_multisib if !missing(post2016) & !missing(father_multisib)
    label variable did_father "DiD: post2016 x father_multisib"
}

capture confirm variable did_mother
if _rc {
    gen did_mother = post2016 * mother_multisib if !missing(post2016) & !missing(mother_multisib)
    label variable did_mother "DiD: post2016 x mother_multisib"
}

*******************************************************
* 3. Sample diagnostics
*******************************************************
display "=================================================="
display "SAMPLE DIAGNOSTICS"
display "=================================================="

count
display "Total observations: " r(N)

preserve
bysort pid: keep if _n == 1
count
display "Total unique individuals: " r(N)

count if !missing(parent_sibsize)
display "Individuals with non-missing parent_sibsize: " r(N)

count if !missing(sib2)
display "Individuals with non-missing sib2: " r(N)

count if !missing(father_multisib)
display "Individuals with non-missing father_multisib: " r(N)

count if !missing(mother_multisib)
display "Individuals with non-missing mother_multisib: " r(N)
restore

tab year
tab post2016
tab sib1 if !missing(sib1), missing
tab sib2 if !missing(sib2), missing
tab father_multisib if !missing(father_multisib), missing
tab mother_multisib if !missing(mother_multisib), missing

summ children has2plus parent_sibsize father_sib mother_sib if !missing(parent_sibsize)

*******************************************************
* 4. Descriptive statistics by treatment group
*******************************************************
display "=================================================="
display "DESCRIPTIVE STATISTICS"
display "=================================================="

tabstat children has2plus parent_sibsize father_sib mother_sib, ///
    by(sib1) stat(n mean sd min p50 max) columns(statistics)

preserve
bysort pid: keep if _n == 1
tabstat children has2plus parent_sibsize father_sib mother_sib, ///
    by(sib1) stat(n mean sd min p50 max) columns(statistics)
restore

*******************************************************
* 5. Baseline DID: binary treatment (sib1 = parent_sibsize >= 1)
*    sib1 is the MAIN binary treatment.
*    Robustness with sib2/sib3 is in Section 8.
*******************************************************
display "=================================================="
display "BASELINE DID: sib1 (parent_sibsize >= 1) — MAIN"
display "=================================================="

* Outcome 1: children
xtreg children i.post2016##i.sib1 i.year ///
    if !missing(children) & !missing(sib1), ///
    fe vce(cluster pid)
estimates store did_children_bin

* Outcome 2: has2plus
xtreg has2plus i.post2016##i.sib1 i.year ///
    if !missing(has2plus) & !missing(sib1), ///
    fe vce(cluster pid)
estimates store did_has2plus_bin

*******************************************************
* 6. Continuous treatment DID
*******************************************************
display "=================================================="
display "CONTINUOUS DID: parent_sibsize"
display "=================================================="

xtreg children c.post2016##c.parent_sibsize i.year ///
    if !missing(children) & !missing(parent_sibsize), ///
    fe vce(cluster pid)
estimates store did_children_cont

xtreg has2plus c.post2016##c.parent_sibsize i.year ///
    if !missing(has2plus) & !missing(parent_sibsize), ///
    fe vce(cluster pid)
estimates store did_has2plus_cont

*******************************************************
* 7. Father vs Mother separate specifications
*******************************************************
display "=================================================="
display "FATHER VS MOTHER"
display "=================================================="

* Father only
xtreg children i.post2016##i.father_multisib i.year ///
    if !missing(children) & !missing(father_multisib), ///
    fe vce(cluster pid)
estimates store did_children_father

xtreg has2plus i.post2016##i.father_multisib i.year ///
    if !missing(has2plus) & !missing(father_multisib), ///
    fe vce(cluster pid)
estimates store did_has2plus_father

* Mother only
xtreg children i.post2016##i.mother_multisib i.year ///
    if !missing(children) & !missing(mother_multisib), ///
    fe vce(cluster pid)
estimates store did_children_mother

xtreg has2plus i.post2016##i.mother_multisib i.year ///
    if !missing(has2plus) & !missing(mother_multisib), ///
    fe vce(cluster pid)
estimates store did_has2plus_mother

* Joint father + mother
xtreg children i.post2016##i.father_multisib ///
               i.post2016##i.mother_multisib ///
               i.year ///
    if !missing(children) & !missing(father_multisib) & !missing(mother_multisib), ///
    fe vce(cluster pid)
estimates store did_children_joint

xtreg has2plus i.post2016##i.father_multisib ///
               i.post2016##i.mother_multisib ///
               i.year ///
    if !missing(has2plus) & !missing(father_multisib) & !missing(mother_multisib), ///
    fe vce(cluster pid)
estimates store did_has2plus_joint

*******************************************************
* 8. Robustness: alternative treatment thresholds
*    sib2 (>= 2) and sib3 (>= 3) as higher-bar alternatives to sib1
*******************************************************
display "=================================================="
display "ROBUSTNESS: alternative thresholds (sib2, sib3)"
display "=================================================="

* sib2 robustness
xtreg children i.post2016##i.sib2 i.year ///
    if !missing(children) & !missing(sib2), ///
    fe vce(cluster pid)
estimates store did_children_sib2

xtreg has2plus i.post2016##i.sib2 i.year ///
    if !missing(has2plus) & !missing(sib2), ///
    fe vce(cluster pid)
estimates store did_has2plus_sib2

* sib3 robustness
xtreg children i.post2016##i.sib3 i.year ///
    if !missing(children) & !missing(sib3), ///
    fe vce(cluster pid)
estimates store did_children_sib3

xtreg has2plus i.post2016##i.sib3 i.year ///
    if !missing(has2plus) & !missing(sib3), ///
    fe vce(cluster pid)
estimates store did_has2plus_sib3

*******************************************************
* 9. Event-study style check (simple)
*******************************************************
display "=================================================="
display "EVENT-STUDY STYLE CHECK"
display "=================================================="

capture drop rel_year
gen rel_year = year - 2016

* Reference wave: 2014 (last pre-treatment wave)
* ib2014.year sets 2014 as the base category for wave FEs.
* Coefficients on earlier waves (2010, 2012) test pre-trends.
capture noisily xtreg children ib2014.year##i.sib1 ///
    if !missing(children) & !missing(sib1), ///
    fe vce(cluster pid)
estimates store es_children_bin

capture noisily xtreg has2plus ib2014.year##i.sib1 ///
    if !missing(has2plus) & !missing(sib1), ///
    fe vce(cluster pid)
estimates store es_has2plus_bin

*******************************************************
* 10. Export regression tables
*******************************************************
display "=================================================="
display "EXPORT RESULTS"
display "=================================================="

capture which esttab
if _rc == 0 {

    esttab did_children_bin did_children_cont ///
           did_children_father did_children_mother did_children_joint ///
           did_children_sib3 ///
        using "$OUT/did_children_results.rtf", replace ///
        b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
        title("DiD Results: Outcome = Number of Children") ///
        label compress

    esttab did_has2plus_bin did_has2plus_cont ///
           did_has2plus_father did_has2plus_mother did_has2plus_joint ///
           did_has2plus_sib3 ///
        using "$OUT/did_has2plus_results.rtf", replace ///
        b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
        title("DiD Results: Outcome = Has 2+ Children") ///
        label compress
}
else {
    display "esttab not installed; skipping table export."
}

*******************************************************
* 11. Save enriched analysis panel
*******************************************************
save "$OUT/did_panel_analysis_ready.dta", replace

display "=================================================="
display "05_analysis.do complete."
display "=================================================="

log close

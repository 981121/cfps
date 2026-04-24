*******************************************************
* 99_diagnose_child_sibship.do
* Purpose: Diagnose and reconstruct father_sib / mother_sib
*          for the 2012 child sample (wka202 respondents)
*
* Logic:
*   cfps2012child_201906  →  pid / pid_f / pid_m / wka202
*   cfps2010adult_201906  →  pid / qb1
*   Merge child → adult twice (via pid_f, then pid_m)
*
* Output:  $CONS/child_parentsib_2012.dta
*          $LOG/99_diagnose_child_sibship.log
*
* Updated: 2026-04-24
*******************************************************

clear all
set more off

*------------------------------------------------------*
* 0. Paths
*------------------------------------------------------*
global PROJ "/Users/huy/cfps_fertility_project"
global RAW  "$PROJ/data/raw"
global CONS "$PROJ/data/constructed"
global LOG  "$PROJ/logs"

local pid_min = 100000000

log using "$LOG/99_diagnose_child_sibship.log", replace text

display "=================================================="
display " CHILD SIBSHIP DIAGNOSTIC"
display " $(c(current_date)) $(c(current_time))"
display "=================================================="

*======================================================*
* STEP 1  Build qb1 lookup from 2010 adult
*======================================================*

display _newline "---------- STEP 1: Build qb1 lookup ----------"

use pid qb1 using "$RAW/2010/cfps2010adult_201906.dta", clear

replace qb1 = . if qb1 < 0
replace qb1 = . if inlist(qb1, 77, 78, 79)
drop if missing(pid) | pid < `pid_min'

sort pid qb1
by pid: keep if _n == 1
isid pid

local N_lookup = _N
count if !missing(qb1)
local n_qb1_valid = r(N)
display "  2010 adult lookup: `N_lookup' unique pids"
display "  qb1 non-missing:   `n_qb1_valid' (" %5.1f `n_qb1_valid'/`N_lookup'*100 "%)"
display "  qb1 missing:       " (`N_lookup' - `n_qb1_valid') ///
    " (" %5.1f (`N_lookup'-`n_qb1_valid')/`N_lookup'*100 "%)"

tempfile qb1_lookup
save `qb1_lookup'

*======================================================*
* STEP 2  Load 2012 child file — restrict to wka202
*======================================================*

display _newline "---------- STEP 2: Load child sample ----------"

use "$RAW/2012/cfps2012child_201906.dta", clear

* Restrict to children who answered wka202
replace wka202 = . if wka202 < 0
keep if !missing(wka202)
drop if missing(pid) | pid < `pid_min'

* Validate parent pid variables exist
foreach pvar in pid_f pid_m {
    capture confirm variable `pvar'
    if _rc {
        display as error "  ERROR: `pvar' not found — check variable names in child file"
        error 1
    }
}

* Recode invalid parent pids
replace pid_f = . if pid_f < `pid_min'
replace pid_m = . if pid_m < `pid_min'

local N_child = _N
display "  Children with valid pid & non-missing wka202: `N_child'"

count if !missing(pid_f)
local n_has_f = r(N)
count if !missing(pid_m)
local n_has_m = r(N)
count if !missing(pid_f) & !missing(pid_m)
local n_has_both = r(N)
count if  missing(pid_f) &  missing(pid_m)
local n_has_none = r(N)

display "  Has valid pid_f:        `n_has_f' (" %5.1f `n_has_f'/`N_child'*100 "%)"
display "  Has valid pid_m:        `n_has_m' (" %5.1f `n_has_m'/`N_child'*100 "%)"
display "  Has both pid_f & pid_m: `n_has_both'"
display "  Missing both pids:      `n_has_none' (cannot recover parental sib for these)"

keep pid pid_f pid_m wka202
tempfile child_base
save `child_base'

*======================================================*
* STEP 3  Coverage check: how many parent pids are in 2010?
*======================================================*

display _newline "---------- STEP 3: Parent PID coverage in 2010 adult ----------"

* --- Father ---
preserve
keep pid_f
drop if missing(pid_f)
duplicates drop pid_f, force
rename pid_f pid          // match key name in qb1_lookup

merge 1:1 pid using `qb1_lookup', keep(master match) gen(_mf)

count
local n_f_unique = r(N)
count if _mf == 3
local n_f_in2010 = r(N)
count if _mf == 3 & !missing(qb1)
local n_f_qb1ok  = r(N)
count if _mf == 3 &  missing(qb1)
local n_f_qb1mis = r(N)
count if _mf == 1
local n_f_not2010 = r(N)

display "  Unique father pids in child file:          `n_f_unique'"
display "  Found in 2010 adult:                       `n_f_in2010' (" %5.1f `n_f_in2010'/`n_f_unique'*100 "%)"
display "    → qb1 non-missing (usable):              `n_f_qb1ok'"
display "    → qb1 missing (in 2010 but no answer):  `n_f_qb1mis'"
display "  NOT found in 2010 adult:                   `n_f_not2010' (" %5.1f `n_f_not2010'/`n_f_unique'*100 "%)"
restore

* --- Mother ---
preserve
keep pid_m
drop if missing(pid_m)
duplicates drop pid_m, force
rename pid_m pid          // match key name in qb1_lookup

merge 1:1 pid using `qb1_lookup', keep(master match) gen(_mm)

count
local n_m_unique = r(N)
count if _mm == 3
local n_m_in2010 = r(N)
count if _mm == 3 & !missing(qb1)
local n_m_qb1ok  = r(N)
count if _mm == 3 &  missing(qb1)
local n_m_qb1mis = r(N)
count if _mm == 1
local n_m_not2010 = r(N)

display "  Unique mother pids in child file:          `n_m_unique'"
display "  Found in 2010 adult:                       `n_m_in2010' (" %5.1f `n_m_in2010'/`n_m_unique'*100 "%)"
display "    → qb1 non-missing (usable):              `n_m_qb1ok'"
display "    → qb1 missing (in 2010 but no answer):  `n_m_qb1mis'"
display "  NOT found in 2010 adult:                   `n_m_not2010' (" %5.1f `n_m_not2010'/`n_m_unique'*100 "%)"
restore

*======================================================*
* STEP 4  Reconstruct: merge father_sib onto children
*======================================================*

display _newline "---------- STEP 4: Merge father_sib ----------"

use `child_base', clear

preserve
use `qb1_lookup', clear
rename pid pid_f
rename qb1 father_sib
tempfile father_lookup
save `father_lookup'
restore

merge m:1 pid_f using `father_lookup', keep(master match) gen(_mf)

count if _mf == 3 & !missing(father_sib)
local n_f_got = r(N)
count if _mf == 3 &  missing(father_sib)
local n_f_matched_nomiss = r(N)
count if _mf == 1
local n_f_nolink = r(N)
count if  missing(pid_f)
local n_f_nopid = r(N)

display "  pid_f → father_sib obtained:              `n_f_got'"
display "  pid_f matched but father_sib still .:     `n_f_matched_nomiss' (qb1 was . in 2010)"
display "  pid_f not found in 2010 adult:            `n_f_nolink'"
display "  pid_f was missing (no father link):       `n_f_nopid'"
display "  father_sib coverage: `n_f_got'/`N_child' = " %5.1f `n_f_got'/`N_child'*100 "%"

drop _mf
tempfile child_with_father
save `child_with_father'

*======================================================*
* STEP 5  Reconstruct: merge mother_sib onto children
*======================================================*

display _newline "---------- STEP 5: Merge mother_sib ----------"

preserve
use `qb1_lookup', clear
rename pid pid_m
rename qb1 mother_sib
tempfile mother_lookup
save `mother_lookup'
restore

merge m:1 pid_m using `mother_lookup', keep(master match) gen(_mm)

count if _mm == 3 & !missing(mother_sib)
local n_m_got = r(N)
count if _mm == 3 &  missing(mother_sib)
local n_m_matched_nomiss = r(N)
count if _mm == 1
local n_m_nolink = r(N)
count if  missing(pid_m)
local n_m_nopid = r(N)

display "  pid_m → mother_sib obtained:              `n_m_got'"
display "  pid_m matched but mother_sib still .:     `n_m_matched_nomiss' (qb1 was . in 2010)"
display "  pid_m not found in 2010 adult:            `n_m_nolink'"
display "  pid_m was missing (no mother link):       `n_m_nopid'"
display "  mother_sib coverage: `n_m_got'/`N_child' = " %5.1f `n_m_got'/`N_child'*100 "%"

drop _mm

*======================================================*
* STEP 6  Construct treatment variables
*======================================================*

display _newline "---------- STEP 6: Treatment variables ----------"

gen father_multisib = .
replace father_multisib = 0 if father_sib == 0
replace father_multisib = 1 if father_sib >= 1 & !missing(father_sib)
label variable father_multisib "Father had ≥1 sibling (0/1/.)"

gen mother_multisib = .
replace mother_multisib = 0 if mother_sib == 0
replace mother_multisib = 1 if mother_sib >= 1 & !missing(mother_sib)
label variable mother_multisib "Mother had ≥1 sibling (0/1/.)"

gen parent_multisib = .
replace parent_multisib = 1 if father_multisib == 1 | mother_multisib == 1
replace parent_multisib = 0 if father_multisib == 0 & mother_multisib == 0
label variable parent_multisib "Any parent had ≥1 sibling — OR logic (0/1/.)"

gen parent_sibsize = max(father_sib, mother_sib)
label variable parent_sibsize "Max of father_sib and mother_sib"

tab parent_multisib, missing

*======================================================*
* STEP 7  Final summary report
*======================================================*

display _newline "=================================================="
display " FINAL SUMMARY REPORT"
display "=================================================="

display _newline "  Total child sample (wka202 valid):           `N_child'"

count if !missing(father_sib)
local nf = r(N)
count if !missing(mother_sib)
local nm = r(N)
count if !missing(father_sib) | !missing(mother_sib)
local nat_least_one = r(N)
count if !missing(parent_multisib)
local npm = r(N)

display "  father_sib non-missing:                    `nf' (" %5.1f `nf'/`N_child'*100 "%)"
display "  mother_sib non-missing:                    `nm' (" %5.1f `nm'/`N_child'*100 "%)"
display "  At least one parent sib non-missing:       `nat_least_one' (" %5.1f `nat_least_one'/`N_child'*100 "%)"
display "  parent_multisib resolved (0 or 1):         `npm' (" %5.1f `npm'/`N_child'*100 "%)"

display _newline "  Residual missing analysis:"
count if missing(pid_f) & missing(pid_m)
display "    Missing both parent pids:                " r(N) ///
    " → child file had no parent links"
count if !missing(pid_f) & missing(father_sib) & !missing(pid_m) & missing(mother_sib)
display "    Has both pids but both sib missing:      " r(N) ///
    " → parents not in 2010 adult OR qb1 missing"
count if missing(father_sib) & !missing(mother_sib)
display "    father_sib missing, mother_sib present:  " r(N)
count if !missing(father_sib) & missing(mother_sib)
display "    mother_sib present, father_sib missing:  " r(N)

*======================================================*
* STEP 8  Save
*======================================================*

display _newline "---------- STEP 8: Save ----------"

label variable pid            "Child PID"
label variable pid_f          "Father PID [orig: pid_f]"
label variable pid_m          "Mother PID [orig: pid_m]"
label variable wka202         "Ideal number of children [orig: wka202, 2012 child]"
label variable father_sib     "Father's sibling count [qb1, 2010 adult]"
label variable mother_sib     "Mother's sibling count [qb1, 2010 adult]"

order pid pid_f pid_m wka202 ///
      father_sib mother_sib father_multisib mother_multisib ///
      parent_multisib parent_sibsize

compress
save "$CONS/child_parentsib_2012.dta", replace
display "  Saved: $CONS/child_parentsib_2012.dta  (N = `N_child')"

*======================================================*
* STEP 9  Panel follow-up: how many 2012 children
*         also answered qka205 (fertility intentions)
*         in the 2020 adult questionnaire?
*
*   Link: pid (shared across all CFPS databases)
*   2012 child sample aged 10–15 → aged 18–23 in 2020
*======================================================*

display _newline "---------- STEP 9: 2020 follow-up (qka205) ----------"

* Build qka205 lookup from 2020 adult file
preserve
use pid qka205 using "$RAW/2020/cfps2020person_202306.dta", clear

replace qka205 = . if qka205 < 0
replace qka205 = . if inlist(qka205, 77, 78, 79)
drop if missing(pid) | pid < 100000000

sort pid
by pid: keep if _n == 1
isid pid

local N_2020 = _N
count if !missing(qka205)
display "  2020 adult file: `N_2020' unique pids"
display "  qka205 non-missing in 2020 adult: " r(N)

tempfile qka205_lookup
save `qka205_lookup'
restore

* Merge onto the 2012 child sample (still in memory)
merge 1:1 pid using `qka205_lookup', keep(master match) gen(_m2020)

* Coverage report
count if _m2020 == 3
local n_found_2020 = r(N)
count if _m2020 == 3 & !missing(qka205)
local n_qka205_valid = r(N)
count if _m2020 == 3 & missing(qka205)
local n_qka205_miss  = r(N)
count if _m2020 == 1
local n_not_2020 = r(N)

display _newline "  2012 child sample (wka202 valid):           `N_child'"
display "  Found in 2020 adult questionnaire:          `n_found_2020' (" ///
    %5.1f `n_found_2020'/`N_child'*100 "%)"
display "    → qka205 non-missing (usable):            `n_qka205_valid' (" ///
    %5.1f `n_qka205_valid'/`N_child'*100 "%)"
display "    → qka205 missing (in 2020 but no answer): `n_qka205_miss'"
display "  Not in 2020 adult at all:                   `n_not_2020' (" ///
    %5.1f `n_not_2020'/`N_child'*100 "%)"

* Cross-tab: wka202 (2012) vs qka205 (2020) for those with both
display _newline "  Distribution of qka205 among re-interviewed children:"
tab qka205 if _m2020 == 3, missing

* Cross-tab with parent treatment
display _newline "  qka205 availability by parent_multisib:"
tab parent_multisib _m2020, missing row

drop _m2020

* Label and add to saved file
label variable qka205 "Fertility intentions next 2 yrs [orig: qka205, 2020 adult]"

display _newline "---------- Re-saving with qka205 ----------"
compress
save "$CONS/child_parentsib_2012.dta", replace
display "  Saved: $CONS/child_parentsib_2012.dta  (now includes qka205)"

display "=================================================="
display " 99_diagnose_child_sibship.do complete."
display "=================================================="

log close

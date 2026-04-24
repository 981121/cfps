*******************************************************
* File:    01_clean_2012.do
* Purpose: Clean CFPS 2012 adult file
* Input:   $RAW/2012/cfps2012adult_202505.dta
* Output:  $CLEAN/person_2012.dta
*          $PROJ/docs/var_dictionary_2012.csv
* Notes:
*   - pid_f / pid_m available in this wave
*   - children: nchd2 (main); nchd1, nchd3 kept as alternatives
*   - marital_status: qe104 (current at survey time, 现在的婚姻状况)
*   - urban: urban12 (NBS classification, consistent with later waves)
*   - ethnicity: cfps_minzu
*   - 2025-04: added qe104, cfps_minzu; switched urban to urban12
*******************************************************

clear all
set more off

display "Cleaning CFPS 2012 adult data..."

* ─────────────────────────────────────────
* 1. Load raw data
* ─────────────────────────────────────────
use "$RAW/2012/cfps2012adult_202505.dta", clear

* ─────────────────────────────────────────
* 2. Safe keep — grouped by function
* ─────────────────────────────────────────
local keep_vars ""

* IDs
foreach v in pid fid12 provcd pid_f pid_m {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Demographics
foreach v in cfps2012_gender_best cfps2012_birthy_best cfps_minzu qe104 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Fertility
foreach v in nchd1 nchd2 nchd3 cageyog {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Education
foreach v in edu2012 eduy2012 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Socioeconomic
foreach v in income income_adj employ {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Geography / urban
foreach v in urban12 urbancomm typecomm {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

keep `keep_vars'

* ─────────────────────────────────────────
* 3. Rename with label preservation
* ─────────────────────────────────────────

* IDs
capture {
    local lab : variable label fid12
    rename fid12 fid
    label variable fid "`lab' [orig: fid12]"
}

capture {
    local lab : variable label pid_f
    rename pid_f father_pid
    label variable father_pid "`lab' [orig: pid_f]"
}

capture {
    local lab : variable label pid_m
    rename pid_m mother_pid
    label variable mother_pid "`lab' [orig: pid_m]"
}

* Demographics
capture {
    local lab : variable label cfps2012_gender_best
    rename cfps2012_gender_best gender
    label variable gender "`lab' [orig: cfps2012_gender_best]"
}

capture {
    local lab : variable label cfps2012_birthy_best
    rename cfps2012_birthy_best birth_year
    label variable birth_year "`lab' [orig: cfps2012_birthy_best]"
}

capture {
    local lab : variable label cfps_minzu
    rename cfps_minzu ethnicity
    label variable ethnicity "`lab' [orig: cfps_minzu]"
}

capture {
    local lab : variable label qe104
    rename qe104 marital_status
    label variable marital_status "`lab' [orig: qe104]"
}

* Fertility
* nchd2 = main children count (survey-reported total); main outcome variable
capture {
    local lab : variable label nchd2
    rename nchd2 children
    label variable children "`lab' [orig: nchd2; main children count]"
}

capture {
    local lab : variable label nchd1
    rename nchd1 children_v1
    label variable children_v1 "`lab' [orig: nchd1; alternative count]"
}

* nchd3 = alternative children count (robustness)
capture {
    local lab : variable label nchd3
    rename nchd3 children_v3
    label variable children_v3 "`lab' [orig: nchd3; alternative count]"
}

* Additional panel variable
capture {
    local lab : variable label wka202
    rename wka202 wka202
    label variable wka202 "`lab' [orig: wka202; 2012 only]"
}

capture {
    local lab : variable label cageyog
    rename cageyog age_youngest_child
    label variable age_youngest_child "`lab' [orig: cageyog]"
}

* Education
capture {
    local lab : variable label edu2012
    rename edu2012 edu_level
    label variable edu_level "`lab' [orig: edu2012]"
}

capture {
    local lab : variable label eduy2012
    rename eduy2012 years_schooling
    label variable years_schooling "`lab' [orig: eduy2012]"
}

* Geography — urban12 as main (NBS classification, consistent with later waves)
capture {
    local lab : variable label urban12
    rename urban12 urban
    label variable urban "`lab' [orig: urban12]"
}

capture {
    local lab : variable label urbancomm
    rename urbancomm community_urban
    label variable community_urban "`lab' [orig: urbancomm]"
}

capture {
    local lab : variable label typecomm
    rename typecomm community_type
    label variable community_type "`lab' [orig: typecomm]"
}

* ─────────────────────────────────────────
* 4. Construct derived variables
* ─────────────────────────────────────────
gen year = 2012
gen wave = 2012
label variable year "Survey year"
label variable wave "Survey wave"

capture gen age = year - birth_year if !missing(birth_year)
capture label variable age "Age at survey [constructed]"

* Binary: has 2+ children
capture {
    gen has2plus = (children >= 2) if !missing(children)
    label variable has2plus "Has 2 or more children [constructed from nchd2; main children count]"
}

* ─────────────────────────────────────────
* 4b. Recode negative sentinel values to missing
*     (-8 不适用, -9 缺失, -1 不知道, -2 拒绝)
*     Applied before saving to prevent invalid codes entering the panel.
* ─────────────────────────────────────────
local pid_min = 100000000
foreach v in father_pid mother_pid {
    capture replace `v' = . if !missing(`v') & `v' < `pid_min'
}
foreach v in birth_year gender ethnicity marital_status ///
             edu_level years_schooling income employ urban ///
             children has2plus {
    capture replace `v' = . if `v' < 0
}

* ─────────────────────────────────────────
* 5. Save clean file
* ─────────────────────────────────────────
compress
save "$CLEAN/person_2012.dta", replace
display "Saved: $CLEAN/person_2012.dta  (N = " _N ")"

* ─────────────────────────────────────────
* 6. Export variable dictionary
* ─────────────────────────────────────────
* Fix: collect labels BEFORE clearing, to avoid r(111) "variable not found"
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

export delimited using "$PROJ/docs/var_dictionary_2012.csv", replace
restore

display "2012 clean complete."

*******************************************************
* PART 2: Clean 2012 child questionnaire
* Input:  $RAW/2012/cfps2012child_201906.dta
* Output: $CLEAN/child_2012.dta
* Notes:
*   - Respondents aged 10–15 in 2012 (birth_year ~1997–2002)
*   - pid shared with all CFPS databases → append into main panel
*   - wka202 is the target variable from this file
*   - Standard adult vars kept where available
*******************************************************

preserve
use "$RAW/2012/cfps2012child_201906.dta", clear

display "  Cleaning 2012 child file: N = " _N

local keep_c ""
foreach v in pid fid12 provcd ///
             gender cfps2012_gender_best ///
             cfps2012_birthy_best ibirthy ///
             cfps_minzu ///
             urban12 ///
             wka202 {
    capture confirm variable `v'
    if !_rc local keep_c `keep_c' `v'
}
keep `keep_c'

* Renames — safe; skip if already done or var absent
capture rename fid12   fid
capture rename cfps2012_gender_best gender
* Birth year: prefer corrected version
capture confirm variable cfps2012_birthy_best
if !_rc {
    capture rename cfps2012_birthy_best birth_year
}
else {
    capture rename ibirthy birth_year
}
capture rename cfps_minzu ethnicity
capture rename urban12    urban

gen year = 2012
gen wave = 2012
label variable year "Survey year"
label variable wave "Survey wave"

* Sentinel recodes
foreach v in birth_year gender ethnicity urban {
    capture replace `v' = . if `v' < 0
}
capture replace wka202 = . if wka202 < 0

* Drop invalid pid
local pid_min = 100000000
drop if missing(pid) | pid < `pid_min'

* Placeholders so schema matches adult files
foreach v in children has2plus marital_status edu_level ///
             years_schooling income employ ///
             father_pid mother_pid {
    capture confirm variable `v'
    if _rc gen `v' = .
}
capture gen has2plus = (children >= 2) if !missing(children)

label variable wka202 "wka202 [orig: wka202; 2012 child questionnaire only]"

compress
save "$CLEAN/child_2012.dta", replace
display "  Saved: $CLEAN/child_2012.dta  (N = " _N ")"
restore

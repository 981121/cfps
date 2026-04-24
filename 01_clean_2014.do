*******************************************************
* File:    01_clean_2014.do
* Purpose: Clean CFPS 2014 adult file
* Input:   $RAW/2014/cfps2014adult_201906.dta
* Output:  $CLEAN/person_2014.dta
*          $PROJ/docs/var_dictionary_2014.csv
* Notes:
*   - pid_f / pid_m available in this wave
*   - children: counted from famconf code_a_c1..code_a_c10 (slot > 0)
*     Source: cfps2014famconf_170630.dta
*     code_a_c* > 0 counts ALL children including non-CFPS-sample members;
*     pid_c* would miss children not enrolled in CFPS.
*   - marital_status: qea0 (current at survey time, 当前婚姻状态)
*   - urban: urban14 (NBS classification)
*   - ethnicity: cfps_minzu
*   - income: variable named `income` (all jobs total)
*   - employment: employ2014
*******************************************************

clear all
set more off

display "Cleaning CFPS 2014 adult data..."

* ─────────────────────────────────────────
* 1. Load raw data
* ─────────────────────────────────────────
use "$RAW/2014/cfps2014adult_201906.dta", clear

* ─────────────────────────────────────────
* 2. Safe keep — grouped by function
* ─────────────────────────────────────────
local keep_vars ""

* IDs
foreach v in pid fid14 provcd14 pid_f pid_m {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Demographics
foreach v in cfps_gender cfps_birthy cfps_minzu qea0 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Fertility — child PIDs (to count children)
forvalues j = 1/10 {
    capture confirm variable code_a_c`j'
    if !_rc local keep_vars `keep_vars' code_a_c`j'
}

* Education
foreach v in cfps2014edu cfps2014eduy {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Socioeconomic
foreach v in income employ2014 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Geography
foreach v in urban14 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

keep `keep_vars'

* ─────────────────────────────────────────
* 3. Rename with label preservation
* ─────────────────────────────────────────

* IDs
capture {
    local lab : variable label fid14
    rename fid14 fid
    label variable fid "`lab' [orig: fid14]"
}

capture {
    local lab : variable label provcd14
    rename provcd14 provcd
    label variable provcd "`lab' [orig: provcd14]"
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
    local lab : variable label cfps_gender
    rename cfps_gender gender
    label variable gender "`lab' [orig: cfps_gender]"
}

capture {
    local lab : variable label cfps_birthy
    rename cfps_birthy birth_year
    label variable birth_year "`lab' [orig: cfps_birthy]"
}

capture {
    local lab : variable label cfps_minzu
    rename cfps_minzu ethnicity
    label variable ethnicity "`lab' [orig: cfps_minzu]"
}

capture {
    local lab : variable label qea0
    rename qea0 marital_status
    label variable marital_status "`lab' [orig: qea0]"
}

* Education
capture {
    local lab : variable label cfps2014edu
    rename cfps2014edu edu_level
    label variable edu_level "`lab' [orig: cfps2014edu]"
}

capture {
    local lab : variable label cfps2014eduy
    rename cfps2014eduy years_schooling
    label variable years_schooling "`lab' [orig: cfps2014eduy]"
}

* Socioeconomic
capture {
    local lab : variable label employ2014
    rename employ2014 employ
    label variable employ "`lab' [orig: employ2014]"
}

* Geography
capture {
    local lab : variable label urban14
    rename urban14 urban
    label variable urban "`lab' [orig: urban14]"
}

* ─────────────────────────────────────────
* 4. Construct derived variables
* ─────────────────────────────────────────
gen year = 2014
gen wave = 2014
label variable year "Survey year"
label variable wave "Survey wave"

capture gen age = year - birth_year if !missing(birth_year)
capture label variable age "Age at survey [constructed]"

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
             edu_level years_schooling income employ urban {
    capture replace `v' = . if `v' < 0
}

* ─────────────────────────────────────────
* 4c. Count children from 2014 famconf (code_a_c1..code_a_c10)
*     Source: cfps2014famconf_170630.dta
*     The 2014 adult file does NOT contain code_a_c* / pid_c* columns.
* ─────────────────────────────────────────
tempfile childcount2014

preserve
    use "$RAW/2014/cfps2014famconf_170630.dta", clear

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

    save `childcount2014'
restore

* Merge children count back onto 2014 person file
* Use m:1 because 2014 adult file can have duplicate pid rows
* (non-core household members); childcount2014 is unique by pid from collapse
merge m:1 pid using `childcount2014', nogenerate keep(master match)

* Respondents not in famconf get children = 0
replace children = 0 if missing(children)

gen has2plus = (children >= 2) if !missing(children)
label variable has2plus "Has 2 or more children [constructed from famconf code count]"

* ─────────────────────────────────────────
* 5. Save clean file
* ─────────────────────────────────────────
compress
save "$CLEAN/person_2014.dta", replace
display "Saved: $CLEAN/person_2014.dta  (N = " _N ")"

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

export delimited using "$PROJ/docs/var_dictionary_2014.csv", replace
restore

display "2014 clean complete."

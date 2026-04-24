*******************************************************
* File:    01_clean_2016.do
* Purpose: Clean CFPS 2016 adult file
* Input:   $RAW/2016/cfps2016adult_201906.dta
* Output:  $CLEAN/person_2016.dta
*          $PROJ/docs/var_dictionary_2016.csv
* Notes:
*   - pid_f / pid_m NOT in adult file; available in famconf.
*     Parent links for 2016 will be built in 02_build_kinship_backbone.do
*   - children: cfps_childn (受访者子女数目) — directly available
*   - marital_status: qea0 (当前婚姻状态)
*   - urban: urban16 (NBS classification)
*   - ethnicity: NOT available in 2016 adult file; will be carried
*     from earlier waves in the kinship backbone step
*   - income: `income` (all jobs total)
*   - employment: employ
*******************************************************

clear all
set more off

display "Cleaning CFPS 2016 adult data..."

* ─────────────────────────────────────────
* 1. Load raw data
* ─────────────────────────────────────────
use "$RAW/2016/cfps2016adult_201906.dta", clear

* ─────────────────────────────────────────
* 2. Safe keep — grouped by function
* ─────────────────────────────────────────
local keep_vars ""

* IDs
foreach v in pid fid16 provcd16 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Demographics
foreach v in cfps_gender cfps_birthy qea0 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}
* Note: cfps_minzu / minzu not present in 2016 adult file

* Fertility
foreach v in cfps_childn {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Education
foreach v in cfps2016edu cfps2016eduy {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Socioeconomic
foreach v in income employ {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Geography
foreach v in urban16 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

keep `keep_vars'

* ─────────────────────────────────────────
* 3. Rename with label preservation
* ─────────────────────────────────────────

* IDs
capture {
    local lab : variable label fid16
    rename fid16 fid
    label variable fid "`lab' [orig: fid16]"
}

capture {
    local lab : variable label provcd16
    rename provcd16 provcd
    label variable provcd "`lab' [orig: provcd16]"
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
    local lab : variable label qea0
    rename qea0 marital_status
    label variable marital_status "`lab' [orig: qea0]"
}

* Fertility
capture {
    local lab : variable label cfps_childn
    rename cfps_childn children
    label variable children "`lab' [orig: cfps_childn]"
}

* Education
capture {
    local lab : variable label cfps2016edu
    rename cfps2016edu edu_level
    label variable edu_level "`lab' [orig: cfps2016edu]"
}

capture {
    local lab : variable label cfps2016eduy
    rename cfps2016eduy years_schooling
    label variable years_schooling "`lab' [orig: cfps2016eduy]"
}

* Geography
capture {
    local lab : variable label urban16
    rename urban16 urban
    label variable urban "`lab' [orig: urban16]"
}

* ─────────────────────────────────────────
* 4. Construct derived variables
* ─────────────────────────────────────────
gen year = 2016
gen wave = 2016
label variable year "Survey year"
label variable wave "Survey wave"

capture gen age = year - birth_year if !missing(birth_year)
capture label variable age "Age at survey [constructed]"

* Binary: has 2+ children
capture {
    gen has2plus = (children >= 2) if !missing(children)
    label variable has2plus "Has 2 or more children [constructed from cfps_childn]"
}

* ─────────────────────────────────────────
* 4b. Recode negative sentinel values to missing
*     (-8 不适用, -9 缺失, -1 不知道, -2 拒绝)
*     Applied before saving to prevent invalid codes entering the panel.
* ─────────────────────────────────────────
foreach v in birth_year gender marital_status ///
             edu_level years_schooling income employ urban ///
             children has2plus {
    capture replace `v' = . if `v' < 0
}

* Placeholder for parent PIDs (to be merged from famconf in 02_build_kinship_backbone.do)
gen father_pid = .
gen mother_pid = .
label variable father_pid "Father PID [to be filled from famconf in step 02]"
label variable mother_pid "Mother PID [to be filled from famconf in step 02]"

* Placeholder for ethnicity (not in 2016 adult; carry forward from earlier waves)
gen ethnicity = .
label variable ethnicity "Ethnicity [not in 2016 adult; to be filled from earlier waves]"

* ─────────────────────────────────────────
* 5. Save clean file
* ─────────────────────────────────────────
compress
save "$CLEAN/person_2016.dta", replace
display "Saved: $CLEAN/person_2016.dta  (N = " _N ")"

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

export delimited using "$PROJ/docs/var_dictionary_2016.csv", replace
restore

display "2016 clean complete."

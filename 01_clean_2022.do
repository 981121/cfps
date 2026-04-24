*******************************************************
* File:    01_clean_2022.do
* Purpose: Clean CFPS 2022 person file
* Input:   $RAW/2022/cfps2022person_202410.dta
* Output:  $CLEAN/person_2022.dta
*          $PROJ/docs/var_dictionary_2022.csv
* Notes:
*   - pid_f / pid_m NOT in person file; from famconf only.
*     Parent links built in 02_build_kinship_backbone.do
*   - children: counted from xchildpid_a_1..8 (non-missing, >0)
*   - marital_status: qea0 (当前婚姻状态)
*   - urban: urban22 (NBS classification)
*   - ethnicity: `minzu` (indicator flag; actual value from famconf)
*   - income: emp_income (consistent with 2020)
*   - employment: employ
*   - birth year: ibirthy_update if present, else ibirthy
*******************************************************

clear all
set more off

display "Cleaning CFPS 2022 person data..."

* ─────────────────────────────────────────
* 1. Load raw data
* ─────────────────────────────────────────
use "$RAW/2022/cfps2022person_202410.dta", clear

* ─────────────────────────────────────────
* 2. Safe keep — grouped by function
* ─────────────────────────────────────────
local keep_vars ""

* IDs
foreach v in pid fid22 provcd22 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Demographics
foreach v in gender ibirthy ibirthy_update minzu qea0 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Fertility — child PIDs
forvalues j = 1/8 {
    capture confirm variable xchildpid_a_`j'
    if !_rc local keep_vars `keep_vars' xchildpid_a_`j'
}

* Education
foreach v in cfps2022edu cfps2022eduy {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Socioeconomic
foreach v in emp_income income employ {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Geography
foreach v in urban22 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

keep `keep_vars'

* ─────────────────────────────────────────
* 3. Rename with label preservation
* ─────────────────────────────────────────

* IDs
capture {
    local lab : variable label fid22
    rename fid22 fid
    label variable fid "`lab' [orig: fid22]"
}

capture {
    local lab : variable label provcd22
    rename provcd22 provcd
    label variable provcd "`lab' [orig: provcd22]"
}

* Demographics
* Prefer ibirthy_update (corrected) over ibirthy
capture confirm variable ibirthy_update
if !_rc {
    capture {
        local lab : variable label ibirthy_update
        rename ibirthy_update birth_year
        label variable birth_year "`lab' [orig: ibirthy_update]"
    }
    capture drop ibirthy
}
else {
    capture {
        local lab : variable label ibirthy
        rename ibirthy birth_year
        label variable birth_year "`lab' [orig: ibirthy]"
    }
}

capture {
    local lab : variable label minzu
    rename minzu ethnicity
    label variable ethnicity "`lab' [orig: minzu]"
}

capture {
    local lab : variable label qea0
    rename qea0 marital_status
    label variable marital_status "`lab' [orig: qea0]"
}

* Education
capture {
    local lab : variable label cfps2022edu
    rename cfps2022edu edu_level
    label variable edu_level "`lab' [orig: cfps2022edu]"
}

capture {
    local lab : variable label cfps2022eduy
    rename cfps2022eduy years_schooling
    label variable years_schooling "`lab' [orig: cfps2022eduy]"
}

* Income
capture confirm variable emp_income
if !_rc {
    capture {
        local lab : variable label emp_income
        rename emp_income income
        label variable income "`lab' [orig: emp_income]"
    }
}

* Geography
capture {
    local lab : variable label urban22
    rename urban22 urban
    label variable urban "`lab' [orig: urban22]"
}

* ─────────────────────────────────────────
* 4. Construct derived variables
* ─────────────────────────────────────────
gen year = 2022
gen wave = 2022
label variable year "Survey year"
label variable wave "Survey wave"

capture gen age = year - birth_year if !missing(birth_year)
capture label variable age "Age at survey [constructed]"

* ------------------------------------------------------ *
* Children count from famconf code_a_c1..code_a_c8
* Use code-based child list instead of xchildpid_a_*,
* because code does not depend on successful child sample linkage.
* ------------------------------------------------------ *

tempfile childcount2022

preserve
    use "$RAW/2022/cfps2022famconf_202410.dta", clear

    * Keep key and child code columns
    keep pid fid22 code_a_c1-code_a_c10

    * Count children from code variables
    gen children = 0
    label variable children "Number of children [counted from famconf code_a_c1..code_a_c8]"

    forvalues j = 1/10 {
        capture confirm variable code_a_c`j'
        if !_rc {
            replace children = children + 1 ///
                if !missing(code_a_c`j') & code_a_c`j' > 0
        }
    }

    * Keep only merge key(s) + outcome
    keep pid fid22 children

    * Prefer pid if unique
    capture isid pid
    if _rc {
        isid pid fid22
    }

    save `childcount2022'
restore

* ------------------------------------------------------ *
* Merge famconf-based child count back to main 2022 file
* Prefer pid merge; fall back to pid+fid only if needed
* ------------------------------------------------------ *

capture merge 1:1 pid using `childcount2022', nogenerate keep(master match)
if _rc {
    merge 1:1 pid fid22 using `childcount2022', nogenerate keep(master match)
}

* Binary: has 2+ children
capture drop has2plus
gen has2plus = (children >= 2) if !missing(children)
label variable has2plus "Has 2 or more children [constructed from famconf code count]"

* ─────────────────────────────────────────
* 4b. Recode negative sentinel values to missing
*     (-8 不适用, -9 缺失, -1 不知道, -2 拒绝)
*     Applied before saving to prevent invalid codes entering the panel.
* ─────────────────────────────────────────
foreach v in birth_year gender ethnicity marital_status ///
             edu_level years_schooling income employ urban ///
             children has2plus {
    capture replace `v' = . if `v' < 0
}

* Placeholders for parent PIDs (from famconf, step 02)
gen father_pid = .
gen mother_pid = .
label variable father_pid "Father PID [to be filled from famconf in step 02]"
label variable mother_pid "Mother PID [to be filled from famconf in step 02]"

* ─────────────────────────────────────────
* 5. Save clean file
* ─────────────────────────────────────────
compress
save "$CLEAN/person_2022.dta", replace
display "Saved: $CLEAN/person_2022.dta  (N = " _N ")"

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

export delimited using "$PROJ/docs/var_dictionary_2022.csv", replace
restore

display "2022 clean complete."

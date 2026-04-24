*******************************************************
* File:    01_clean_2018.do
* Purpose: Clean CFPS 2018 person file
* Input:   $RAW/2018/cfps2018person_202012.dta
* Output:  $CLEAN/person_2018.dta
*          $PROJ/docs/var_dictionary_2018.csv
* Notes:
*   - pid_f / pid_m NOT in person file; from famconf only.
*     Parent links built in 02_build_kinship_backbone.do
*   - children: counted from xchildpid_a_1..10 (non-missing, >0)
*   - marital_status: qea0 (当前婚姻状态)
*   - urban: urban18 (NBS classification)
*   - ethnicity: `minzu` (indicator flag for whether ethnicity data
*     exists; actual ethnicity value must be merged from famconf)
*   - income: `income` (all jobs, 税后工资性收入)
*   - employment: employ
*   - birth year: ibirthy (加载变量); use ibirthy_update if available
*******************************************************

clear all
set more off

display "Cleaning CFPS 2018 person data..."

* ─────────────────────────────────────────
* 1. Load raw data
* ─────────────────────────────────────────
use "$RAW/2018/cfps2018person_202012.dta", clear

* ─────────────────────────────────────────
* 2. Safe keep — grouped by function
* ─────────────────────────────────────────
local keep_vars ""

* IDs
foreach v in pid fid18 provcd18 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Demographics
foreach v in gender ibirthy ibirthy_update minzu qea0 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Fertility — child PIDs
forvalues j = 1/10 {
    capture confirm variable xchildpid_a_`j'
    if !_rc local keep_vars `keep_vars' xchildpid_a_`j'
}

* Education
foreach v in cfps2018edu cfps2018eduy {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Socioeconomic
foreach v in income employ {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

* Geography
foreach v in urban18 {
    capture confirm variable `v'
    if !_rc local keep_vars `keep_vars' `v'
}

keep `keep_vars'

* ─────────────────────────────────────────
* 3. Rename with label preservation
* ─────────────────────────────────────────

* IDs
capture {
    local lab : variable label fid18
    rename fid18 fid
    label variable fid "`lab' [orig: fid18]"
}

capture {
    local lab : variable label provcd18
    rename provcd18 provcd
    label variable provcd "`lab' [orig: provcd18]"
}

* Demographics
* Use ibirthy_update if present (corrected birth year), else ibirthy
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
    local lab : variable label cfps2018edu
    rename cfps2018edu edu_level
    label variable edu_level "`lab' [orig: cfps2018edu]"
}

capture {
    local lab : variable label cfps2018eduy
    rename cfps2018eduy years_schooling
    label variable years_schooling "`lab' [orig: cfps2018eduy]"
}

* Geography
capture {
    local lab : variable label urban18
    rename urban18 urban
    label variable urban "`lab' [orig: urban18]"
}

* ─────────────────────────────────────────
* 4. Construct derived variables
* ─────────────────────────────────────────
gen year = 2018
gen wave = 2018
label variable year "Survey year"
label variable wave "Survey wave"

capture gen age = year - birth_year if !missing(birth_year)
capture label variable age "Age at survey [constructed]"

tempfile childcount2018

preserve
    use "$RAW/2018/cfps2018famconf_202008.dta", clear

    * Keep key and child code columns
    keep pid fid18 code_a_c1-code_a_c10

    * Count children from code variables
    gen children = 0
    forvalues j = 1/10 {
        capture confirm variable code_a_c`j'
        if !_rc {
            replace children = children + 1 ///
                if !missing(code_a_c`j') & code_a_c`j' > 0
        }
    }

    label variable children "Number of children [counted from famconf code_a_c1..code_a_c10]"

    * Keep only merge keys + outcome
    keep pid fid18 children

    * Check uniqueness; choose pid if unique, otherwise use pid fid
    capture isid pid
    if _rc {
        isid pid fid18
    }

    save `childcount2018'
restore

* Return to main 2018 person/adult file in memory
* Merge child count back
capture merge 1:1 pid using `childcount2018', nogenerate keep(master match)
if _rc {
    merge 1:1 pid fid18 using `childcount2018', nogenerate keep(master match)
}

* Rebuild has2plus
capture drop has2plus
gen has2plus = children >= 2 if !missing(children)
label variable has2plus "Has 2+ children (0/1)"

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
save "$CLEAN/person_2018.dta", replace
display "Saved: $CLEAN/person_2018.dta  (N = " _N ")"

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

export delimited using "$PROJ/docs/var_dictionary_2018.csv", replace
restore

display "2018 clean complete."

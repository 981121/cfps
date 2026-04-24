*******************************************************
* File:    02_build_kinship_backbone.do
* Purpose: Build cross-wave parent-child PID linkage backbone
*          for later parental sibship construction
*
* Input:   $RAW/{wave}/cfps{wave}famconf_*.dta  (all 7 waves: 2010–2022)
*          $CLEAN/person_{wave}.dta             (updated in Step 8)
*
* Output:  $CONS/kinship_backbone.dta
*              One row per pid. Variables: pid, father_pid, mother_pid.
*              Earliest-wave non-missing value used when multiple
*              waves provide a value.
*          $CLEAN/person_{wave}.dta
*              father_pid / mother_pid placeholders (2016–2022) filled.
*              2010/2012/2014 values preserved; backbone fills missing only.
*
* Merge key: pid (1:1 into backbone, m:1 into person files)
*
* Notes on parent PID coding in famconf:
*   Valid PIDs   : integer >= 100,000,000 (CFPS 9-digit sample codes)
*   Sentinels → .: -10 无法判断, -9 缺失, -8 不适用,
*                  -2 拒绝回答, -1 不知道,
*                  77 其他, 78 以上都没有, 79 没有
*   Variable name differs by wave:
*     2010/2012/2014/2016/2022 famconf: pid_f  / pid_m
*     2018/2020 famconf:                pid_a_f / pid_a_m
*   2010 famconf filename: cfps2010famconf_report_nat072016.dta
*
* Why 2010 is included:
*   Primary purpose is to improve parent/grandparent PID coverage
*   for parental sibship construction (03_parent_sibship.do).
*   Parents of the 1975-1984 cohort (born ~1945-1960) and their
*   parents (born ~1920-1940) are more likely to appear in the 2010
*   famconf than in later waves (still alive in 2010; may have died
*   by 2012+). Adding 2010 as the EARLIEST wave gives it the highest
*   priority in the "earliest-wave wins" collapse logic.
*
* Known data facts (from pre-audit of 2012-2022, 2026-04-19):
*   - Pooled rows across 6 waves: ~328,000 (7-wave total TBD at runtime)
*   - Cross-wave father_pid conflicts: ~81 unique pids (6-wave estimate)
*   - Cross-wave mother_pid conflicts: ~114 unique pids (6-wave estimate)
*   - Backbone coverage: father ~75%, mother ~75% (will improve with 2010)
*
* IMPORTANT FOR NEXT STEP (03_parent_sibship.do):
*   Only pids whose father_pid (or mother_pid) is itself a pid in
*   the backbone can have sibship computed.
*
* Updated: 2026-04-20 (added 2010 wave)
*******************************************************

clear all
set more off

display "Building kinship backbone..."

* Macro: valid PID lower bound (all CFPS sample codes >= 100,000,000)
local pid_min = 100000000

* ─────────────────────────────────────────────────────────
* 1. Extract parent PIDs from each famconf wave  (7 waves: 2010–2022)
*    Each wave produces: pid | father_pid | mother_pid | wave_src
*    Sentinel values are replaced with . (missing)
*    Rows with missing/invalid pid are dropped
* ─────────────────────────────────────────────────────────

* ---------- 2010 ----------
* Filename differs from later waves: cfps2010famconf_report_nat072016.dta
* Variable names pid_f / pid_m — same as 2012/2014/2016/2022.
use "$RAW/2010/cfps2010famconf_report_nat072016.dta", clear
keep pid pid_f pid_m
rename pid_f father_pid
rename pid_m mother_pid
gen wave_src = 2010

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2010
save `fam2010'
display "  2010 famconf: " _N " obs"

* ---------- 2012 ----------
use "$RAW/2012/cfps2012famconf_092015.dta", clear
keep pid pid_f pid_m
rename pid_f father_pid
rename pid_m mother_pid
gen wave_src = 2012

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2012
save `fam2012'
display "  2012 famconf: " _N " obs"

* ---------- 2014 ----------
use "$RAW/2014/cfps2014famconf_170630.dta", clear
keep pid pid_f pid_m
rename pid_f father_pid
rename pid_m mother_pid
gen wave_src = 2014

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2014
save `fam2014'
display "  2014 famconf: " _N " obs"

* ---------- 2016 ----------
use "$RAW/2016/cfps2016famconf_201804.dta", clear
keep pid pid_f pid_m
rename pid_f father_pid
rename pid_m mother_pid
gen wave_src = 2016

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2016
save `fam2016'
display "  2016 famconf: " _N " obs"

* ---------- 2018 (pid_a_f / pid_a_m — different naming from other waves) ----------
use "$RAW/2018/cfps2018famconf_202008.dta", clear
keep pid pid_a_f pid_a_m
rename pid_a_f father_pid
rename pid_a_m mother_pid
gen wave_src = 2018

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2018
save `fam2018'
display "  2018 famconf: " _N " obs"

* ---------- 2020 (pid_a_f / pid_a_m) ----------
use "$RAW/2020/cfps2020famconf_202306.dta", clear
keep pid pid_a_f pid_a_m
rename pid_a_f father_pid
rename pid_a_m mother_pid
gen wave_src = 2020

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2020
save `fam2020'
display "  2020 famconf: " _N " obs"

* ---------- 2022 ----------
use "$RAW/2022/cfps2022famconf_202410.dta", clear
keep pid pid_f pid_m
rename pid_f father_pid
rename pid_m mother_pid
gen wave_src = 2022

foreach v in father_pid mother_pid {
    replace `v' = . if `v' < `pid_min'
}

keep if !missing(pid) & pid > 0
tempfile fam2022
save `fam2022'
display "  2022 famconf: " _N " obs"

* ─────────────────────────────────────────────────────────
* 2. Pool all 7 waves (2010–2022)
*    2010 is appended first so that after sorting by wave_src,
*    it becomes the highest-priority wave in Step 4's collapse.
* ─────────────────────────────────────────────────────────
use `fam2010', clear
foreach yr in 2012 2014 2016 2018 2020 2022 {
    append using `fam`yr''
}

display _N " total obs across all waves (before dedup and collapse)"

* ─────────────────────────────────────────────────────────
* 3. Remove within-wave pid duplicates
*    Cause: same person appears in multiple roster positions
*    in the same wave's famconf (e.g., co-resident + listed again).
*    Resolution: sort so the row with the SMALLEST non-missing parent
*    PID comes first, then keep first within pid-wave.
*    This is deterministic but somewhat arbitrary; cross-wave
*    conflicts are detected separately in Step 3b.
* ─────────────────────────────────────────────────────────
duplicates report pid wave_src

duplicates tag pid wave_src, gen(_dup_tag)
count if _dup_tag > 0
if r(N) > 0 {
    display "  NOTE: " r(N) " within-wave duplicate pid-wave rows detected."
    display "        Keeping row with smallest non-missing parent PID per pid-wave."
    sort pid wave_src father_pid mother_pid
    by pid wave_src: keep if _n == 1
    display "  After dedup: " _N " obs remain"
}
drop _dup_tag

* ─────────────────────────────────────────────────────────
* 3b. Detect cross-wave parent PID conflicts
*
*     Definition: same pid has two or more DIFFERENT non-missing
*     values for father_pid (or mother_pid) across waves.
*     This is NOT the same as: missing in some waves (harmless).
*
*     ASSUMPTION: a person's biological parent is fixed. Conflicts
*     suggest data entry errors, panel attrition artifacts, or
*     re-interviewing the same person in a different household.
*
*     Action: conflicts are LOGGED but not dropped. Step 4's collapse
*     (firstnm, sorted by wave_src ascending) will silently keep the
*     earliest-wave value. This section makes that choice auditable.
*
*     IMPACT ON NEXT STEP: if a conflicted pid is a respondent in the
*     1975-1984 cohort, their parental sibship may be mis-assigned.
*     Analysts should verify conflict pids are not driving results.
* ─────────────────────────────────────────────────────────

* Use min/max per pid: if min ≠ max, there are at least 2 distinct
* non-missing values → cross-wave conflict
bysort pid: egen _f_min = min(father_pid)
bysort pid: egen _f_max = max(father_pid)
bysort pid: egen _m_min = min(mother_pid)
bysort pid: egen _m_max = max(mother_pid)

gen _conflict_f = (!missing(_f_min) & _f_min != _f_max)
gen _conflict_m = (!missing(_m_min) & _m_min != _m_max)

* Count at pid level (not row level)
bysort pid: gen _pid_first = (_n == 1)

count if _conflict_f & _pid_first
local n_conf_f = r(N)
count if _conflict_m & _pid_first
local n_conf_m = r(N)

display "  Cross-wave conflicting father_pid: `n_conf_f' unique pids"
display "  Cross-wave conflicting mother_pid:  `n_conf_m' unique pids"

if `n_conf_f' > 0 | `n_conf_m' > 0 {
    display "  --> Earliest-wave non-missing value will be used (Step 4)."
    display "  --> For the 1975-1984 cohort, verify these conflicts are negligible."
}

drop _f_min _f_max _m_min _m_max _conflict_f _conflict_m _pid_first

* ─────────────────────────────────────────────────────────
* 3c. Enforce 2010-only for pids present in 2010 famconf
*
*     For any pid that appears in wave_src == 2010, keep ONLY its 2010 row.
*     Rows from later waves are dropped for those pids.
*
*     Rationale:
*       (a) cfps2010famconf has 50,000+ records — largest coverage
*       (b) Parents of the 1975–1984 cohort (b. ~1945–1960) are more
*           likely alive and present in 2010 than later waves
*       (c) qb1 (parental sibship key variable) was collected in 2010 only;
*           pids observed in 2010 have the best chance of having parents
*           with qb1 responses
*       (d) Prevents later-wave data from silently overriding a deliberately
*           missing 2010 parent link (e.g., confirmed absent parent)
*
*     Pids NOT in 2010 famconf retain all available waves; Step 4 then
*     applies earliest-wave-wins logic normally.
* ─────────────────────────────────────────────────────────
bysort pid: egen _in2010 = max(wave_src == 2010)
drop if _in2010 == 1 & wave_src != 2010
drop _in2010
display _N " obs after enforcing 2010 authoritative base (Step 3c)"

* ─────────────────────────────────────────────────────────
* 4. Collapse to person-level: take EARLIEST-WAVE non-missing value
*
*    Mechanism: sort by pid wave_src (ascending), then collapse
*    with (firstnm). Stata's firstnm respects the current row order
*    within each by-group and returns the first non-missing value.
*    Because rows are sorted earliest-wave-first, this guarantees
*    "earliest available wave" semantics — not just "first row".
*
*    This sort must immediately precede collapse. Do not re-sort
*    between these two lines.
* ─────────────────────────────────────────────────────────
sort pid wave_src                    // ← guarantees earliest-wave priority for firstnm
collapse (firstnm) father_pid mother_pid, by(pid)

display _N " unique PIDs in backbone (after collapse)"

* ─────────────────────────────────────────────────────────
* 5. Verify uniqueness — backbone must be keyed by pid
* ─────────────────────────────────────────────────────────
isid pid
display "  OK: pid is unique identifier in backbone"

* ─────────────────────────────────────────────────────────
* 6. Label variables and save backbone
* ─────────────────────────────────────────────────────────
label variable pid        "Individual PID"
label variable father_pid "Father PID [famconf, earliest non-missing wave]"
label variable mother_pid "Mother PID [famconf, earliest non-missing wave]"

compress
save "$CONS/kinship_backbone.dta", replace
display "Saved: $CONS/kinship_backbone.dta"

* Also save a diagnostic copy to tempfile for the diagnostics block below
tempfile backbone_diag
save `backbone_diag'

* ─────────────────────────────────────────────────────────
* 7. DIAGNOSTICS BLOCK
*    Runs after backbone is saved so diagnostics cannot corrupt output.
*    Produces three sub-sections:
*      7a. Build helper lookup files (pid set, birth_year pool)
*      7b. Load backbone + add indicators
*      7c. Report: overall coverage, parent-in-backbone, cohort
* ─────────────────────────────────────────────────────────

display _newline "--- Running backbone diagnostics ---"

* ── 7a-i. Build backbone pid lookup (for parent-in-backbone check) ──
* We need to ask: "is father_pid itself a pid in this backbone?"
* Strategy: save all backbone pids to a tempfile keyed by check_pid,
* then merge backbone against itself on father_pid / mother_pid.
use `backbone_diag', clear
keep pid
rename pid check_pid
sort check_pid
tempfile bb_pids
save `bb_pids'

* ── 7a-ii. Build pooled birth_year lookup (for cohort diagnostics) ──
* Load only pid and birth_year from each clean wave (7 waves: 2010–2022)
* and collapse to one row per pid (first non-missing birth_year).
foreach yr in 2010 2012 2014 2016 2018 2020 2022 {
    use pid birth_year using "$CLEAN/person_`yr'.dta", clear
    tempfile byr`yr'
    save `byr`yr''
}
use `byr2010', clear
foreach yr in 2012 2014 2016 2018 2020 2022 {
    append using `byr`yr''
}
keep if !missing(pid) & pid > 0
collapse (firstnm) birth_year, by(pid)
tempfile byears
save `byears'

* ── 7b. Reload backbone and attach diagnostic indicators ──
use `backbone_diag', clear

* Parent-in-backbone indicator: father
* Rename father_pid → check_pid so we can merge on it;
* merge will add a _merge indicator; restore name afterwards.
rename father_pid check_pid
merge m:1 check_pid using `bb_pids', keep(master match)
gen _f_in_bb = (_merge == 3) & !missing(check_pid)
drop _merge
rename check_pid father_pid

* Parent-in-backbone indicator: mother (same approach)
rename mother_pid check_pid
merge m:1 check_pid using `bb_pids', keep(master match)
gen _m_in_bb = (_merge == 3) & !missing(check_pid)
drop _merge
rename check_pid mother_pid

* Merge birth_year for cohort-specific reporting
merge 1:1 pid using `byears', keep(master match) nogenerate
gen _in_cohort = (birth_year >= 1975 & birth_year <= 1984) ///
                 if !missing(birth_year)

* ── 7c. Report ──
display _newline "=========================================="
display "  BACKBONE DIAGNOSTICS"
display "=========================================="

local N_bb = _N
display "  Total unique PIDs in backbone: `N_bb'"

* Overall coverage
count if !missing(father_pid)
local n_f = r(N)
display "  father_pid non-missing: `n_f' (" %5.1f `n_f'/`N_bb'*100 "%)"

count if !missing(mother_pid)
local n_m = r(N)
display "  mother_pid non-missing: `n_m' (" %5.1f `n_m'/`N_bb'*100 "%)"

count if !missing(father_pid) & !missing(mother_pid)
display "  both parents non-missing: " r(N) " (" %5.1f r(N)/`N_bb'*100 "%)"

* Parent-in-backbone (critical for sibship)
display _newline "  -- Parent-in-backbone (relevant for sibship construction) --"
count if _f_in_bb
display "  father_pid found in backbone: " r(N) " / `n_f'"
count if _m_in_bb
display "  mother_pid found in backbone: " r(N) " / `n_m'"
count if _f_in_bb & _m_in_bb
display "  both parents found in backbone: " r(N)
display "  NOTE: Only pids whose parent is found in backbone can"
display "        have parental sibship computed in the next step."

* Cohort-specific (1975-1984 main analysis sample)
display _newline "  -- Cohort 1975-1984 (main DiD sample) --"
count if _in_cohort
local n_coh = r(N)
if `n_coh' == 0 {
    display "  WARNING: No cohort pids found in backbone."
    display "           Check that birth_year loaded correctly from clean files."
}
else {
    display "  Backbone pids in cohort: `n_coh'"

    count if _in_cohort & !missing(father_pid)
    display "  With non-missing father_pid: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"

    count if _in_cohort & !missing(mother_pid)
    display "  With non-missing mother_pid: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"

    count if _in_cohort & !missing(father_pid) & !missing(mother_pid)
    display "  With both parents non-missing: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"

    count if _in_cohort & _f_in_bb
    display "  Father found in backbone: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"

    count if _in_cohort & _m_in_bb
    display "  Mother found in backbone: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"

    count if _in_cohort & _f_in_bb & _m_in_bb
    display "  Both parents in backbone: " r(N) " (" %5.1f r(N)/`n_coh'*100 "%)"
}

display "=========================================="

* Diagnostics done — drop temp vars, no need to re-save backbone
* (backbone_diag tempfile and $CONS/kinship_backbone.dta are clean)

* ─────────────────────────────────────────────────────────
* 8. SAFE MERGE-BACK
*    Fill father_pid / mother_pid in clean person files.
*
*    Strategy:
*      (a) Rename existing father_pid → _f_orig (preserve original)
*      (b) Merge backbone values in as father_pid / mother_pid
*      (c) Rename backbone values → father_pid_bb / mother_pid_bb
*      (d) Restore originals: rename _f_orig → father_pid
*      (e) Count and report: fills (orig missing, bb non-missing)
*                            conflicts (orig ≠ bb, both non-missing)
*      (f) Fill missing originals with backbone value only
*      (g) Drop _bb temp vars; save
*
*    For 2010/2012/2014: father_pid already non-missing from adult file.
*      Fills should be near zero; any conflict is flagged.
*    For 2016–2022: father_pid = . (placeholder); fills = coverage.
*
*    NOTE: Rows with pid = . (2014 non-core members, N=2,621) will
*      not match any backbone row; their parent fields remain missing.
* ─────────────────────────────────────────────────────────

foreach yr in 2010 2012 2014 2016 2018 2020 2022 {

    display _newline "--- Updating person_`yr'.dta ---"
    use "$CLEAN/person_`yr'.dta", clear

    * Warn about obs that cannot be matched (missing/invalid pid)
    count if missing(pid) | pid <= 0
    if r(N) > 0 {
        display "  NOTE: " r(N) " obs with missing/invalid pid (non-core members)."
        display "        These will not be matched to backbone."
    }

    * (a) Preserve originals by renaming
    rename father_pid _f_orig
    rename mother_pid _m_orig

    * (b) Merge backbone values
    * Because we renamed the originals, father_pid / mother_pid do not
    * exist in master — merge can safely create them from the backbone.
    merge m:1 pid using "$CONS/kinship_backbone.dta", ///
        keepusing(father_pid mother_pid) ///
        keep(master match) nogenerate

    * (c) Rename backbone values to temporary names
    rename father_pid father_pid_bb
    rename mother_pid mother_pid_bb

    * (d) Restore originals
    rename _f_orig father_pid
    rename _m_orig mother_pid

    * (e-i) Count fills: original was missing, backbone has a value
    count if missing(father_pid) & !missing(father_pid_bb)
    local n_fill_f = r(N)
    count if missing(mother_pid) & !missing(mother_pid_bb)
    local n_fill_m = r(N)

    * (e-ii) Count conflicts: both non-missing AND disagreeing
    * These should be rare; if non-zero, the original is kept.
    count if !missing(father_pid) & !missing(father_pid_bb) ///
             & father_pid != father_pid_bb
    local n_conf_f = r(N)
    count if !missing(mother_pid) & !missing(mother_pid_bb) ///
             & mother_pid != mother_pid_bb
    local n_conf_m = r(N)

    if `n_conf_f' > 0 | `n_conf_m' > 0 {
        display "  WARNING: `n_conf_f' father_pid conflicts, " ///
                "`n_conf_m' mother_pid conflicts."
        display "           Original (adult-file) value kept; backbone value discarded."
    }

    * (f) Fill only missing original values
    replace father_pid = father_pid_bb if missing(father_pid)
    replace mother_pid = mother_pid_bb if missing(mother_pid)

    display "  father_pid filled from backbone: `n_fill_f'"
    display "  mother_pid filled from backbone: `n_fill_m'"

    * Final coverage report
    count if !missing(father_pid)
    display "  Final father_pid non-missing: " r(N) " / " _N
    count if !missing(mother_pid)
    display "  Final mother_pid non-missing: " r(N) " / " _N

    * (g) Clean up and save
    drop father_pid_bb mother_pid_bb
    compress
    save "$CLEAN/person_`yr'.dta", replace
    display "  Saved: $CLEAN/person_`yr'.dta"
}

display _newline "02_build_kinship_backbone complete."

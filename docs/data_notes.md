# Data Notes — CFPS Fertility Project

## Session: 2026-04-19 — Wave Cleaning Do Files

### Key decisions recorded

**1. Outcome variable: `children`**
- 2012: Use `nchd2` as main (`children`). Also keep `nchd1` (`children_v1`) and `nchd3` (`children_v3`) for robustness checks.
- 2014: Count non-missing child PIDs from `pid_c1..pid_c10`. Raw columns dropped after counting.
- 2016: Use `cfps_childn` (受访者子女数目) — directly available in adult file.
- 2018: Count non-missing PIDs from `xchildpid_a_1..xchildpid_a_10`. Raw columns dropped after counting.
- 2020/2022: Count from `xchildpid_a_1..xchildpid_a_8`. Raw columns dropped after counting.
- Derived binary `has2plus = (children >= 2)` generated in every wave.

**2. Marital status: `marital_status`**
- 2012: `qe104` (现在的婚姻状况, current at survey).
- 2014–2022: `qea0` (当前婚姻状态, current at survey).
- Consistent "current marital status" variable across all waves.

**3. Urban classification: `urban`**
- All waves use the NBS (国家统计局) classification: `urban12`, `urban14`, `urban16`, `urban18`, `urban20`, `urban22`.
- 2012 also retains `urbancomm` (社区性质分类) renamed to `community_urban` for potential robustness check.

**4. Ethnicity: `ethnicity`**
- 2012: `cfps_minzu` (民族).
- 2014: `cfps_minzu`.
- 2016: NOT available in adult file. Placeholder (`.`) generated; to be filled from earlier waves in kinship backbone step.
- 2018–2022: `minzu` variable is an indicator flag ("民族数据是否有数据"), NOT the actual ethnicity code. Should be treated with caution; actual ethnicity to be merged from famconf or prior waves.

**5. Parent PIDs: `father_pid`, `mother_pid`**
- 2012/2014: `pid_f` / `pid_m` directly available in adult file.
- 2016: NOT in adult file; available in `cfps2016famconf_201804.dta`.
- 2018–2022: NOT in person file; must be extracted from famconf files.
- Placeholder (`.`) generated in 2016–2022 clean files; to be filled in `02_build_kinship_backbone.do`.

**6. Income**
- 2012–2018: Variable named `income`.
- 2020–2022: Variable named `emp_income` (过去12个月所有工作税后工资性收入). Renamed to `income` in clean files.

**7. Education**
- Wave-specific variables: `edu2012`, `cfps2014edu`, `cfps2016edu`, `cfps2018edu`, `cfps2020edu`, `cfps2022edu`.
- All renamed to `edu_level` in clean files.
- Years of schooling: `eduy2012`, `cfps2014eduy`, etc. → `years_schooling`.

---

## Variable Name Cross-Walk (clean files)

| Clean name      | **2010**          | 2012              | 2014          | 2016          | 2018              | 2020              | 2022              |
|-----------------|-------------------|-------------------|---------------|---------------|-------------------|-------------------|-------------------|
| pid             | pid               | pid               | pid           | pid           | pid               | pid               | pid               |
| fid             | fid *(no suffix)* | fid12             | fid14         | fid16         | fid18             | fid20             | fid22             |
| provcd          | provcd            | provcd            | provcd14      | provcd16      | provcd18          | provcd20          | provcd22          |
| birth_year      | **qa1y_best**     | cfps2012_birthy_best | cfps_birthy | cfps_birthy  | ibirthy_update    | ibirthy_update    | ibirthy_update    |
| gender          | **gender**        | cfps2012_gender_best | cfps_gender | cfps_gender  | gender            | gender            | gender            |
| ethnicity       | **qa5code** ✓     | cfps_minzu        | cfps_minzu    | (placeholder) | minzu (flag)      | minzu (flag)      | minzu (flag)      |
| marital_status  | **qe1_best** ✓   | qe104             | qea0          | qea0          | qea0              | qea0              | qea0              |
| children        | **famconf code_a_c*** | nchd2         | famconf code_a_c* | cfps_childn | famconf code_a_c* | famconf code_a_c* | famconf code_a_c* |
| has2plus        | constructed       | constructed       | constructed   | constructed   | constructed       | constructed       | constructed       |
| edu_level       | **cfps2010edu_best** | edu2012        | cfps2014edu   | cfps2016edu   | cfps2018edu       | cfps2020edu       | cfps2022edu       |
| years_schooling | **cfps2010eduy_best** | eduy2012      | cfps2014eduy  | cfps2016eduy  | cfps2018eduy      | cfps2020eduy      | cfps2022eduy      |
| income          | income            | income            | income        | income        | income            | emp_income        | emp_income        |
| employ          | **qg3** ✓        | employ            | employ2014    | employ        | employ            | employ            | employ            |
| urban           | **urban** (no suffix) | urban12       | urban14       | urban16       | urban18           | urban20           | urban22           |
| father_pid      | pid_f             | pid_f             | pid_f         | (placeholder) | (placeholder)     | (placeholder)     | (placeholder)     |
| mother_pid      | pid_m             | pid_m             | pid_m         | (placeholder) | (placeholder)     | (placeholder)     | (placeholder)     |

All 2010 mappings verified 2026-04-20. No uncertain mappings remain.

---

---

---

## Session: 2026-04-20 — Adding 2010 Wave

**Reason for adding 2010:** To improve grandparent PID coverage for the two-hop parental sibship construction. Parents of the 1975–1984 cohort (born ~1945–1960) and their parents (born ~1920–1940) are more likely to appear in the 2010 famconf than in later waves — they may have died between 2010 and 2012+. Because the backbone collapse uses "earliest wave wins", 2010 data is assigned the highest priority.

**Files changed:**
- `do/01_clean_2010.do` — new
- `do/02_build_kinship_backbone.do` — 2010 famconf added as first wave; loops updated 6→7
- `do/03_parent_sibship.do` — birth_year loop updated 6→7
- `do/00_master.do` — 01_clean_2010.do inserted before 01_clean_2012.do
- `CLAUDE.md` — status updated
- `docs/data_notes.md` — this entry, crosswalk updated

---

## Session: 2026-04-24 — Fix children counts, sentinel cleaning, backbone priority

### Changes

**1. `children` variable: 2010 and 2014 now sourced from famconf**
- **Problem:** Both waves produced `children = 0` for all respondents.
  - 2010: clean script looked for `code_a_c*` in adult file → absent → 0.
  - 2014: clean script looked for `pid_c*` in adult file → absent → 0.
- **Fix:** Both waves now load their respective famconf file inside a `preserve/restore` block, count valid child PIDs (`code_a_c`j' >= 100000000`) from `code_a_c1..code_a_c10`, and merge the count back onto the person file by pid.
  - 2010 source: `cfps2010famconf_report_nat072016.dta`
  - 2014 source: `cfps2014famconf_170630.dta`
- **Method:** `collapse (max) children, by(pid)` handles duplicate pid rows in famconf. Unmatched persons default to `children = 0`.
- **Downstream affected:** `02_build_kinship_backbone.do` → `03_parent_sibship.do` → `04_make_analysis_panel.do` → `05_analysis.do` (re-run full pipeline to get corrected children counts).

**2. Negative sentinel cleaning: all seven `01_clean_*.do` files**
- **Problem:** Sentinels (−8 不适用, −9 缺失, −1 不知道, −2 拒绝) were only cleaned in `05_analysis.do` (too late). Some waves had no cleaning at all.
- **Fix:** Added a standardised `4b. Recode negative sentinel values` block to every wave's clean script, applied after renaming and before saving.
  - Variables cleaned: `birth_year gender ethnicity marital_status edu_level years_schooling income employ urban children has2plus`
  - For 2010/2012/2014: also clean `father_pid mother_pid` (values < 100000000 → missing)
  - 2010 already had a sentinel block; the new blocks are added to 2012, 2014, 2016, 2018, 2020, 2022
- **Downstream affected:** Any downstream script that relied on negative values being present in the clean files (none expected).

**3. Backbone priority: 2010 famconf as authoritative source**
- **Problem:** The backbone used "earliest-wave wins" via `firstnm` collapse, but `firstnm` skips missing — so if 2010 had `father_pid = .` and 2014 had a non-missing value, 2014 would silently take priority for a 2010 pid.
- **Fix:** Added Step 3c to `02_build_kinship_backbone.do`. After conflict detection (Step 3b) and before collapse (Step 4), all non-2010 rows for pids that appear in the 2010 famconf are dropped. This enforces: "if a pid is in 2010, use ONLY its 2010 parent PIDs."
- **Rationale:** `cfps2010famconf` has 50,000+ records (largest coverage); parents of the 1975–1984 cohort were alive in 2010 and may have attrited by later waves; qb1 was only collected in 2010.
- **Downstream affected:** `kinship_backbone.dta` will change for any pid present in both 2010 and a later wave where later wave had a different non-missing parent PID.

**4. `father_pid` / `mother_pid` added to `04_make_analysis_panel.do` keep_vars**
- **Problem:** These variables were dropped by the safe-keep pattern, appearing as byte/all-missing stubs in `did_panel.dta`.
- **Fix:** Added to `local keep_vars` and to the `order` statement. Added labels in section 6.
- **Note:** 2016–2022 parent PIDs are filled by the backbone merge-back in `02_build_kinship_backbone.do`. 2010/2012/2014 retain adult-file values (with backbone fill for any missing).

### Crosswalk update
`children` source corrected in the crosswalk table above:
- 2010: ~~count `pid_c1..pid_c10`~~ → count `code_a_c1..code_a_c10` from `cfps2010famconf`
- 2014: ~~count `pid_c*`~~ → count `code_a_c1..code_a_c10` from `cfps2014famconf`

**2010-specific variable decisions:**

| Clean name | 2010 raw var | Notes |
|---|---|---|
| birth_year | `qa1y_best` | Best-corrected version, confirmed |
| gender | `gender` | Same name as later waves |
| ethnicity | `qa5code` | Actual ethnicity code — BETTER than 2018+ `minzu` flag |
| fid | `fid` | No wave suffix in 2010 raw file |
| urban | `urban` | NBS classification, no wave suffix; equivalent to `urban12`..`urban22` |
| edu_level | `cfps2010edu_best` | Confirmed |
| years_schooling | `cfps2010eduy_best` | Confirmed |
| income | `income` | Confirmed; same name as 2012–2018 |
| father_pid | `pid_f` | In adult file directly (like 2012/2014); valid ≥ 100,000,000 |
| mother_pid | `pid_m` | In adult file directly |
| children | count `pid_c1..pid_c10` ≥ 1e8 | Same approach as 2014 |

**Verification results (2026-04-20, manual cross-check by researcher):**
- `qe1_best` → `marital_status`: coding confirmed consistent with `qe104` (2012) and `qea0` (2014+). Safe to pool.
- `qg3` → `employ`: coding confirmed consistent with later waves' derived `employ`. Safe to pool.
- `urban`: NBS classification boundaries confirmed same as `urban12`..`urban22`. Safe to pool.
- All 2010 control variables cleared for use in pooled analysis.

**2010 famconf details:**
- Filename: `cfps2010famconf_report_nat072016.dta`
- Variable names: `pid_f` / `pid_m` (same as 2012/2014/2016/2022)
- Valid father PIDs (≥ 1e8) in famconf: 21,805
- Valid mother PIDs (≥ 1e8) in famconf: 23,102

---

## Session: 2026-04-19 — Kinship Backbone (02_build_kinship_backbone.do)

**Famconf parent PID variable name differences:**
| Wave | Father PID var | Mother PID var |
|------|---------------|----------------|
| **2010** | **pid_f** | **pid_m** |
| 2012 | pid_f | pid_m |
| 2014 | pid_f | pid_m |
| 2016 | pid_f | pid_m |
| 2018 | pid_a_f | pid_a_m |
| 2020 | pid_a_f | pid_a_m |
| 2022 | pid_f | pid_m |

**Sentinel values treated as missing (→ .):**
- Negative: -10 (无法判断), -9 (缺失), -8 (不适用), -2 (拒绝), -1 (不知道)
- Positive codes: 77 (其他), 78 (以上都没有), 79 (没有)
- Valid PID threshold: `pid_f >= 100,000,000`

**Collapse strategy:** `firstnm` by pid — takes earliest wave's non-missing value. Earlier waves prioritised.

**2014 person file note:** 2,621 rows have `pid = .` (non-core members in raw adult file). These are naturally excluded from merge but retained in clean file as-is.

**Output:** `$CONS/kinship_backbone.dta` — one row per pid. Then merged (update) back into all 6 clean person files, filling 2016–2022 placeholders.

---

---

## Session: 2026-04-20 — Parental Sibship Construction (03_parent_sibship.do)

**CORRECTION (same session):** An earlier draft of this script incorrectly computed the respondent's own sibship (counting how many backbone PIDs share `father_pid` = R's father). This was a conceptual error. The research target is **parental generation's sibship** — how many siblings the respondent's father or mother had. The script was rewritten with a two-hop linkage.

**Two-hop linkage design**

```
Father side:
  R.father_pid = F  →  F.father_pid = GF  →  count(backbone pids with father_pid = GF)
                                              = father's sibship (CFPS lower bound)

Mother side:
  R.mother_pid = M  →  M.father_pid = MGF  →  count(backbone pids with father_pid = MGF)
                                               = mother's sibship (CFPS lower bound)
```

Counting pivot is the grandfather (via `father_pid`), not grandmother. Grandmother-side counting would be a robustness check.

**What sibship measures and does NOT measure**
- `father_sibship = k` means: k CFPS-panel members share the same paternal grandfather. This includes the father himself.
- This is a **lower bound** — non-sampled, deceased, or untracked siblings of the father are not counted.
- `father_sibship = .` means two-hop linkage failed (grandfather not identifiable from backbone). It does NOT mean the father was an only child.
- Expected two-hop attrition: significant. Fathers born ~1950-1960; their fathers (grandparents) born ~1920-1940 and likely not CFPS sample members. Actual coverage rates reported by the diagnostics block at runtime.

**Treatment variable definitions (revised)**

| Variable | Definition |
|---|---|
| `father_sibship` | # backbone PIDs sharing same paternal grandfather as father [2-hop] |
| `mother_sibship` | # backbone PIDs sharing same maternal grandfather as mother [2-hop] |
| `father_gf_pid` | Paternal grandfather PID [from backbone, hop-1] |
| `mother_gf_pid` | Maternal grandfather PID [from backbone, hop-1] |
| `father_multisib` | 1 if father_sibship ≥ 2; 0 if = 1; . if linkage failed |
| `mother_multisib` | 1 if mother_sibship ≥ 2; 0 if = 1; . if linkage failed |
| `parent_multisib` | **Main DiD treatment.** Conservative OR: 1 if either = 1; 0 if both = 0; . otherwise |

**`parent_multisib` missing-value logic (conservative)**
- = 1 if at least one parent's linkage confirms 2+ siblings
- = 0 only if BOTH parents confirmed as sole-child in backbone
- = . if one side is missing (can't confirm "no siblings" when linkage fails)
- Prevents false zeros from being assigned when linkage simply fails on one side.

**Downstream note**
- Missing `parent_multisib` should be treated as potentially MCAR pending robustness checks. Analysis should compare characteristics of the linked vs. unlinked subsample.
- Large sibship values (> 8) may reflect famconf PID reuse errors — check at analysis stage.

**Cohort restriction**
- This file covers ALL backbone PIDs. The 1975–1984 restriction is applied in `04_make_analysis_panel.do`.

**Output:** `$CONS/parent_sibship.dta` — one row per pid, keyed by pid.

---

---

## Session: 2026-04-20 — Analysis Panel (04_make_analysis_panel.do)

**Input:** `$CLEAN/person_{wave}.dta` (7 waves) + `$CONS/parent_sibship.dta`
**Output:** `$ANLY/did_panel.dta` — pid × wave, cohort 1975–1984

**Sample restriction:** birth_year 1975–1984 (aged 26–35 in 2010, 32–41 at policy change, 38–47 in 2022).

**Pre/post split:**
- Pre-treatment: waves 2010, 2012, 2014 (three pre-period points)
- Post-treatment: waves 2016, 2018, 2020, 2022
- `post2016 = (wave >= 2016)`

**Variables generated:**

| Variable | Definition |
|---|---|
| `age` | `wave - birth_year` |
| `post2016` | 1 if wave ≥ 2016 |
| `t_event` | `wave - 2016` (−6 to +6 in steps of 2) |
| `wave_YYYY` | Wave indicator dummies (2010–2022) |
| `did_main` | `post2016 × parent_multisib` — **baseline DiD term** |
| `did_father` | `post2016 × father_multisib` |
| `did_mother` | `post2016 × mother_multisib` |
| `did_fsib` | `post2016 × father_sibship` (continuous robustness) |
| `did_msib` | `post2016 × mother_sibship` (continuous robustness) |
| `es_main_YYYY` | `wave_YYYY × parent_multisib` (event-study interactions) |
| `es_father_YYYY` | `wave_YYYY × father_multisib` |
| `es_mother_YYYY` | `wave_YYYY × mother_multisib` |

**Event-study reference period:** wave 2014 (last pre-treatment wave) — omit `es_main_2014` in regression.

**Outcomes:** `children` (count), `has2plus` (binary).

**Fixed effects** (to be absorbed in 05_analysis.do, not dummied here): `pid`, `wave`, optionally `provcd`.

**Pid × wave uniqueness** verified by `isid pid wave` before save.

---

---

## Session: 2026-04-20 — Treatment Variable Redesign (03_parent_sibship.do rewrite)

**Problem with two-hop approach:**
The original `father_sibship` counted how many backbone PIDs share the same paternal grandfather. Because grandparents (born ~1920–1940) almost never appear as parents of multiple CFPS-sampled individuals, this count was almost always = 1. The variable had near-zero variation and could not serve as a DiD treatment.

**Solution: family-size approach (new main treatment)**
Instead of counting backbone offspring, look up each grandparent's own survey-reported `children` count from the clean person files. This is not limited to CFPS-sampled offspring and captures total lifetime fertility.

**Reported children priority hierarchy:**
| Priority | Wave | Variable | Type |
|---|---|---|---|
| 1 (best) | 2012 | `children` = nchd2 | Survey-reported total |
| 1 (best) | 2016 | `children` = cfps_childn | Survey-reported total |
| 2 (fallback) | 2010, 2014, 2018, 2020, 2022 | `children` = pid-counted | Lower bound only |

When a grandparent PID appears in multiple waves, the 2012/2016 value is used. Implementation: pool all waves with priority code, sort pid × priority ascending, collapse firstnm.

**New treatment variable definitions:**

| Variable | Definition |
|---|---|
| `father_gpchild_f` | Paternal grandfather (PGF) reported total children |
| `father_gpchild_m` | Paternal grandmother (PGM) reported total children |
| `mother_gpchild_f` | Maternal grandfather (MGF) reported total children |
| `mother_gpchild_m` | Maternal grandmother (MGM) reported total children |
| `father_famsize_max` | max(father_gpchild_f, father_gpchild_m) [one-side fill if other missing] |
| `mother_famsize_max` | max(mother_gpchild_f, mother_gpchild_m) [one-side fill] |
| `parent_famsize_max` | max(father_famsize_max, mother_famsize_max) [one-side fill] |
| `parent_multisib` | **MAIN DiD treatment.** 1 if parent_famsize_max ≥ 2; 0 if = 1; . if missing |

**Rationale for max:**
- Avoids undercounting when one grandparent is deceased/non-reporting
- Uses whichever side has the most complete information
- Acknowledges potential remarriage/step-family effects

**Renamed two-hop variables (robustness only):**

| Old name | New name |
|---|---|
| `father_sibship` | `father_sibship_2hop` |
| `mother_sibship` | `mother_sibship_2hop` |
| `father_multisib` | `father_multisib_2hop` |
| `mother_multisib` | `mother_multisib_2hop` |
| `parent_multisib` (2-hop) | `parent_multisib_2hop` |

**Files changed:**
- `do/03_parent_sibship.do` — complete rewrite (family-size approach added; 2-hop kept as robustness)
- `do/04_make_analysis_panel.do` — keepusing, labels, order, and sample report updated
- `CLAUDE.md` — treatment variable status updated
- `docs/data_notes.md` — this entry

**Downstream note:**
`05_analysis.do` should use `parent_multisib` (family-size) as primary treatment and `parent_multisib_2hop` as robustness check.

---

---

## Session: 2026-04-20 — Identification Strategy Change (03_parent_sibship.do, third rewrite)

**Old strategy abandoned:** All grandparent-based / GP-reported / two-hop reconstruction removed.

**Reason:** The entire grandparent-based approach (both the two-hop backbone count and the GP-reported total-children lookup) was discarded in favour of a direct, simpler measure with no multi-hop attrition.

**New strategy: qb1 from 2010 adult dataset**

`qb1` = "number of siblings" as self-reported by the respondent in the 2010 CFPS adult interview. This variable:
- Does NOT include the respondent themselves (no subtraction needed).
- Is directly available in `cfps2010adult_201906.dta`.
- Applies to parents: look up `qb1` for `father_pid` and `mother_pid` in the backbone.

**Data flow:**
1. Load 2010 adult → keep `pid`, `qb1` → recode sentinels (negative codes → .; 77/78/79 → .) → `isid pid` → save as `qb1_lookup`.
2. Load backbone → merge `qb1_lookup` on `father_pid` (gen/merge/drop pattern) → `father_sib`.
3. Merge `qb1_lookup` on `mother_pid` → `mother_sib`.
4. Construct binary indicators and main treatment.

**New treatment variable definitions:**

| Variable | Definition |
|---|---|
| `father_sib` | Father's reported sibling count (qb1 from 2010 adult, keyed by father_pid) |
| `mother_sib` | Mother's reported sibling count (qb1 from 2010 adult, keyed by mother_pid) |
| `father_multisib` | 1 if father_sib ≥ 1; 0 if = 0; . if missing |
| `mother_multisib` | 1 if mother_sib ≥ 1; 0 if = 0; . if missing |
| `parent_multisib` | **MAIN DiD treatment.** 1 if either parent = 1; 0 if both = 0; . otherwise |

**`parent_multisib` logic:**
- `replace parent_multisib = 1 if father_multisib == 1 | mother_multisib == 1` — one-side fill for treated
- `replace parent_multisib = 0 if father_multisib == 0 & mother_multisib == 0` — both must confirm control
- Mixed 0/missing → stays . (cannot confirm treatment or control without both sides)

**Sentinel recodes for qb1:**
- All negative values → . (standard CFPS: −1 不适用, −2 拒绝回答, −8 不知道)
- 77, 78, 79 → . (CFPS non-substantive codes sometimes used in count variables)

**Files changed:**
- `do/03_parent_sibship.do` — complete rewrite (qb1-based; all grandparent/two-hop/GP-reported code removed)
- `do/04_make_analysis_panel.do` — keepusing, labels, order, sample report updated to new variable names
- `CLAUDE.md` — Core Variables and Current Status updated
- `docs/data_notes.md` — this entry

**Downstream note:**
`05_analysis.do` should use `parent_multisib` (qb1-based) as the sole DiD treatment. No robustness variants from `03` remain; robustness at analysis stage can use `father_multisib` and `mother_multisib` separately.

---

## Next steps

1. ~~Run all 01_clean_*.do~~ ✓ complete
2. ~~02_build_kinship_backbone.do~~ ✓ complete
3. ~~03_parent_sibship.do~~ ✓ complete (qb1-based, 2026-04-20)
4. ~~04_make_analysis_panel.do~~ ✓ complete → `$ANLY/did_panel.dta`
5. **05_analysis.do**: baseline DiD (`xtreg`/`reghdfe`), then event study. Main treatment: `parent_multisib` (qb1). Load `did_panel.dta`. Omit wave 2014 as reference in event study.

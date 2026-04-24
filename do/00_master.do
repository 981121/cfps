*******************************************************
* Project: CFPS Fertility Project
* File:    00_master.do
* Purpose: Master script to run the full data workflow
* Author:  Yueqian Zhang
* Notes:   This version is a first-stage scaffold.
*          It assumes raw CFPS .dta files are stored by wave.
*******************************************************

clear all
set more off
capture log close

*******************************************************
* 1. Set project root
*******************************************************

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
* 2. Start log
*******************************************************

log using "$LOG/00_master.log", replace text

display "========================================"
display "Running CFPS Fertility Project Master Do"
display "Project root: $PROJ"
display "Start time: $S_DATE $S_TIME"
display "========================================"

*******************************************************
* 3. Check folders
*******************************************************

cap mkdir "$CLEAN"
cap mkdir "$CONS"
cap mkdir "$ANLY"
cap mkdir "$LOG"
cap mkdir "$OUT"

*******************************************************
* 4. Run wave-specific cleaning scripts  (7 waves: 2010–2022)
*******************************************************

display "Cleaning 2010 wave..."
do "$DO/01_clean_2010.do"

display "Cleaning 2012 wave..."
do "$DO/01_clean_2012.do"

display "Cleaning 2014 wave..."
do "$DO/01_clean_2014.do"

display "Cleaning 2016 wave..."
do "$DO/01_clean_2016.do"

display "Cleaning 2018 wave..."
do "$DO/01_clean_2018.do"

display "Cleaning 2020 wave..."
do "$DO/01_clean_2020.do"

display "Cleaning 2022 wave..."
do "$DO/01_clean_2022.do"

*******************************************************
* 5. Build pooled kinship backbone
*******************************************************

display "Building pooled kinship backbone..."
do "$DO/02_build_kinship_backbone.do"

*******************************************************
* 6. Build parental sibship variables
*******************************************************

display "Building parental sibship variables..."
do "$DO/03_parent_sibship.do"

*******************************************************
* 7. Build final analysis panel
*******************************************************

display "Building final analysis panel..."
do "$DO/04_make_analysis_panel.do"

*******************************************************
* 8. Optional checks
*******************************************************

capture noisily do "$DO/99_checks.do"

*******************************************************
* 9. End log
*******************************************************

display "========================================"
display "Master do-file completed successfully."
display "End time: $S_DATE $S_TIME"
display "========================================"

log close
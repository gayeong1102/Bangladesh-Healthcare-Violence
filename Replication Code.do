*----------------------------------------------------------
* Replication code for --
* Does Violence Hurt Healthcare Availability and Readiness?
* Econ 80 Paper
* 11/24/2021
* Gayeong Song, Dartmouth College
*----------------------------------------------------------

*----------------------------------------------------------
* STEP 1: Prepare SPA for Grid Merge and Create Variables
*----------------------------------------------------------

* STEP 1 Setup
*----------------------------------------------------------
clear
set more off
cap log close
cap clear matrix
clear mata
set maxvar 8000

* Store Working Directory
global dir "/Users/gayeongsong/Desktop/Econ 80 Paper/Bangladesh SPA"
log using "$dir/Grid", text replace
*----------------------------------------------------------

/// Step 1: Create and Assign Grids for 2014 and 2017 SPA ///
/* Extract GPS */
cd "$dir"

/* Create a loop to go through all shp file to dta file */
foreach year in "2014" "2017" {
	shp2dta using "$dir/`year'/Bangladesh_`year'.shp", ///
	database("$dir/`year'/`year'_GPS") coordinates("$dir/`year'/`year'_coord") replace
}

/* Change some variable names to year-specific ones */
* 2014
use "$dir/2014/2014_GPS.dta", clear

rename SPAFACID SPAFACID_2014
rename LATNUM LATNUM_2014
rename LONGNUM LONGNUM_2014
drop if LATNUM_2014==0 | LONGNUM_2014==0

save "$dir/2014/2014_GPS.dta", replace

* 2017
use "$dir/2017/2017_GPS.dta", clear

rename SPAFACID SPAFACID_2017
rename LATNUM LATNUM_2017
rename LONGNUM LONGNUM_2017
drop if LATNUM_2017==0 | LONGNUM_2017==0

save "$dir/2017/2017_GPS.dta", replace


/* Make 25km grids */
* 2014
use "$dir/2014/2014_GPS.dta", clear

gen grid_lat=floor(LATNUM_2014*4)
gen grid_long=floor(LONGNUM_2014*4)

egen grid_id = group(grid_lat grid_long)

save "$dir/2014/Grid_2014_25km.dta", replace

* 2017
use "$dir/2017/2017_GPS.dta", clear

gen grid_lat=floor(LATNUM_2017*4)
gen grid_long=floor(LONGNUM_2017*4)

merge m:m grid_lat grid_long using "$dir/2014/Grid_2014_25km.dta", keepusing(grid_id) nogenerate

duplicates drop SPAFACID_2017, force

save "$dir/2017/Grid_2017_25km.dta", replace


/// Step 2: Merge Grid Dataset to Each SPA ///
use "$dir/2014/Bangladesh_Facility_2014.dta"
rename facil SPAFACID_2014
merge 1:1 SPAFACID_2014 using "$dir/2014/Grid_2014_25km", keepusing(grid_id) nogenerate
drop if grid_id==.

save "$dir/2014/Facility_2014_grid_id.dta", replace

use "$dir/2017/Bangladesh_Facility_2017.dta"
rename facil SPAFACID_2017
merge 1:1 SPAFACID_2017 using "$dir/2017/Grid_2017_25km", keepusing(grid_id) nogenerate
drop if grid_id==.

save "$dir/2017/Facility_2017_grid_id.dta", replace


/// Step 3: Create a Bangladesh Panel ///
use "$dir/2014/Facility_2014_grid_id.dta"

append using "$dir/2017/Facility_2017_grid_id.dta", force

save "$dir/Bangladesh_Panel.dta", replace



/// Step 4: Clean the data using Questionnaire ///
/* https://dhsprogram.com/pubs/pdf/SPAQ1/INVENTORY_06012012_SPAQ1.pdf */
/* https://dhsprogram.com/pubs/pdf/SPAQ6/SPA_Questionnaires_Combined_English_09_11_2020.pdf */
use "$dir/Bangladesh_Panel.dta", clear

/* NUMBER 1: Create rarity weights for each service */
* Generate means for each facility's service usage
forval i=1/9 {
	replace q102_0`i'=0 if q102_0`i'!=1
	egen mean_`i' = mean(q102_0`i')
	gen weight_service_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

forval i=10/19 {
	replace q102_`i'=0 if q102_`i'!=1
	egen mean_`i' = mean(q102_`i')
	gen weight_service_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

* Create a variable called service index, set it to 0 because that is the lowest value
gen service_index=0

* Construct service index based on weights
forval i=1/9 {
	gen temp = weight_service_`i' * q102_0`i'
	replace service_index = service_index + temp
	drop temp
}

forval i=10/19 {
	gen temp = weight_service_`i' * q102_`i'
	replace service_index = service_index + temp
	drop temp
}

/* NUMBER 2: Count how many services available */
egen service_count = anycount(q102_01-q102_19), values(1)


/* NUMBER 3: Create rarity weights for each basic supplies */
* Generate means for each facility's basic equipment
forval i=1/9 {
	replace q700a_0`i'=0 if q700a_0`i'!=1
	egen mean_`i' = mean(q700a_0`i')
	gen weight_equip_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

forval i=10/21 {
	replace q700a_`i'=0 if q700a_`i'!=1
	egen mean_`i' = mean(q700a_`i')
	gen weight_equip_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

* Create a variable called equip index, set it to 0 because that is the lowest value
gen equip_index=0

* Construct service index based on weights
forval i=1/9 {
	gen temp = weight_equip_`i' * q700a_0`i'
	replace equip_index = equip_index + temp
	drop temp
}

forval i=10/21 {
	gen temp = weight_equip_`i' * q700a_`i'
	replace equip_index = equip_index + temp
	drop temp
}

/* NUMBER 4: Count how many equipments available */
egen equip_count = anycount(q700a_01-q700a_21), values(1)


/* NUMBER 5: Create rarity weights for in-vitro diagnostics */
/* The necessity is evaluated by WHO guideline on in-vitro diagnostics */
foreach n of numlist 801 803 830 832 848 852 854 859 861 880 {
	replace q`n'=0 if q`n'!=1
	egen mean_`n' = mean(q`n')
	gen weight_diag_`n' = 100 - (mean_`n' * 100)
	drop mean_`n'
}

* Create a variable called diagonistics index, set it to 0 because that is the lowest value
gen diag_index=0

* Construct diagnostics index based on weights
foreach n of numlist 801 803 830 832 848 852 854 859 861 880 {
	gen temp = weight_diag_`n' * q`n'
	replace diag_index = diag_index + temp
	drop temp
}

/* NUMBER 6: Count how many diagnostics available */
egen diag_count = anycount (q801 q803 q830 q832 q848 q852 q854 q859 q861 q880), values(1)


/* NUMBER 7: Create rarity weights for medicine */
/* The necessity is evaluated by WHO guideline on medicine */
* Generate means for each medicine
foreach n of numlist 901 903 904 906 908 {
	forval i=1/9 {
		replace q`n'_0`i'=0 if q`n'_0`i'!=1
		egen mean_`n'_`i' = mean(q`n'_0`i')
		gen weight_med_`n'_`i' = 100 - (mean_`n'_`i' * 100)
		drop mean_`n'_`i'
	}
}

foreach n of numlist 901 903 904 906 908 {
	forval i=10/26 {
		capture tab q`n'_`i'
		if _rc!=0 {
			display "no observations"
		}
		else {
			replace q`n'_`i'=0 if q`n'_`i'!=1
			egen mean_`n'_`i' = mean(q`n'_`i')
			gen weight_med_`n'_`i' = 100 - (mean_`n'_`i' * 100)
			drop mean_`n'_`i'
		}
	}
}

* Create a variable called medicine index, set it to 0 because that is the lowest value
gen med_index=0

* Construct medicine index based on weights
foreach n of numlist 901 903 904 906 908 {
	forval i=1/9 {
		gen temp = weight_med_`n'_`i' * q`n'_0`i'
		replace med_index = med_index + temp
		drop temp
	}
}

foreach n of numlist 901 903 904 906 908 {
	forval i=10/26 {
		capture tab q`n'_`i'
		if _rc!=0 {
			display "no observations"
		}
		else {
			gen temp = weight_med_`n'_`i' * q`n'_`i'
			replace med_index = med_index + temp
			drop temp
		}
	}
}

/* NUMBER 8: Count available kinds of medicines */
egen med_count = anycount(q901_* q903_* q904_* q906_* q908_*), values(1)


/* NUMBER 9: Create rarity-weighted index for family planning */
forval i=1/9 {
	replace q1302_0`i'=0 if q1302_0`i'!=1
	egen mean_`i' = mean(q1302_0`i')
	gen weight_fp_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

forval i=10/13 {
	replace q1302_`i'=0 if q1302_`i'!=1
	egen mean_`i' = mean(q1302_`i')
	gen weight_fp_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

* Create a variable called family planning index, set it to 0 because that is the lowest value
gen fp_index=0

* Construct service index based on weights
forval i=1/9 {
	gen temp = weight_fp_`i' * q1302_0`i'
	replace fp_index = fp_index + temp
	drop temp
}

forval i=10/13 {
	gen temp = weight_fp_`i' * q1302_`i'
	replace fp_index = fp_index + temp
	drop temp
}


/* NUMBER 10: Count available kinds of family planning */
egen fp_count = anycount(q1302_01-q1302_13), values(1)


/* NUMBER 11: Create rarity-weighted index for delivery-specific equipment */
forval i=1/9 {
	replace q1622a_0`i'=0 if q1622a_0`i'!=1
	egen mean_`i' = mean(q1622a_0`i')
	gen weight_deliv_`i' = 100 - (mean_`i' * 1)
	drop mean_`i'
}

forval i=10/15 {
	replace q1622a_`i'=0 if q1622a_`i'!=1
	egen mean_`i' = mean(q1622a_`i')
	gen weight_deliv_`i' = 100 - (mean_`i' * 100)
	drop mean_`i'
}

* Create a variable called delivery index, set it to 0 because that is the lowest value
gen deliv_index=0

* Construct service index based on weights
forval i=1/9 {
	gen temp = weight_deliv_`i' * q1622a_0`i'
	replace deliv_index = deliv_index + temp
	drop temp
}

forval i=10/15 {
	gen temp = weight_deliv_`i' * q1622a_`i'
	replace deliv_index = deliv_index + temp
	drop temp
}

/* NUMBER 12: Count available kinds of delivery-specific equipment */
egen deliv_count = anycount(q1622a_01-q1622a_15), values(1)


/// Step 5: Standardize the quantity variables & index variables ///

/* Convert quantity variables to percentage */
* Count all services in the dataset
egen total_service_count = anycount(q102_01-q102_19), values(0 1)
egen total_equip_count = anycount(q700a_01-q700a_21), values(0 1)
egen total_diag_count = anycount (q801 q803 q830 q832 q848 q852 q854 q859 q861 q880), values(0 1)
egen total_med_count = anycount(q901_* q903_* q904_* q906_* q908_*), values(0 1)
egen total_fp_count = anycount(q1302_01-q1302_13), values(0 1)
egen total_deliv_count = anycount(q1622a_01-q1622a_15), values(0 1)

* Generate percentages for number of services
gen service_pc = (service_count / total_service_count) * 100
gen equip_pc = (equip_count / total_equip_count) * 100
gen diag_pc = (diag_count / total_diag_count) * 100
gen med_pc = (med_count / total_med_count) * 100
gen fp_pc = (fp_count / total_fp_count) * 100
gen deliv_pc = (deliv_count / total_deliv_count) * 100


/* Find z score for each weighted index */
foreach index of varlist *_index {
	egen `index'_mean = mean(`index')
	egen `index'_z = sd(`index')
	replace `index'_z = (`index'-`index'_mean)/`index'_z
}


/// Step 6: Disposable Supplies ///
* Count available disposable supplies
egen sanitation = anycount(q710_02 q710_03 q710_04 q710_07-q710_12), values(1)

* Generate percentages for number of disposable supplies
gen sanitation_pc = (sanitation / 9) * 100

save "$dir/Bangladesh_Panel_Cleaned.dta", replace


log close


*----------------------------------------------------------
* STEP 2: Prepare ACLED for Grid Merge and Create Variables
*----------------------------------------------------------

* STEP 2 Setup
*----------------------------------------------------------
clear
set more off
cap log close
cap clear matrix
clear mata
set maxvar 8000

* Store Working Directory
global dir "/Users/gayeongsong/Desktop/Econ 80 Paper/ACLED" 
log using "$dir/ACLED", text replace
*----------------------------------------------------------

/// Step 1: Clean, merge, collapse ///

* Import ACLED Dataset
import delimited "$dir/ACLED_all.csv", case(preserve) clear

* Only keep Bangladesh
keep if country=="Bangladesh" 

* Separate the current date observation into day, month, and year
split event_date, parse(" ") gen(temp_date)
rename temp_date1 day
rename temp_date2 month

* Make day into numeric
destring day, replace

* Make month into numeric months
replace month="1" if month=="January"
replace month="2" if month=="February"
replace month="3" if month=="March"
replace month="4" if month=="April"
replace month="5" if month=="May"
replace month="6" if month=="June"
replace month="7" if month=="July"
replace month="8" if month=="August"
replace month="9" if month=="September"
replace month="10" if month=="October"
replace month="11" if month=="November"
replace month="12" if month=="December"

destring month, replace

* Create my own date variable
gen date = mdy(month, day, year)

* Merge with Grid from "Create Bangladesh Grid Panel.do"
gen grid_lat=floor(latitude*4)
gen grid_long=floor(longitude*4)

merge m:m grid_lat grid_long using "/Users/gayeongsong/Desktop/Econ 80 Paper/Bangladesh SPA/2014/Grid_2014_25km.dta", keepusing(grid_id) nogenerate

drop if grid_id==.

save "$dir/Grid_ACLED.dta", replace

* Count events by grid by year
gen event=1

collapse(sum) event, by(grid_id year month)


save "$dir/Violence_Collapse.dta", replace 

/// Step 2: Main analysis - Manipulate to the data structure with t-1, t-2, t-3 ///
*** NOTE ***
* Based on tab month year, most of the 2014 interviews were done in may, june, july &
* most of the 2017 interviews were done in august, september, and october.
* Therefore, I want a data structure that has a 12 month lag and 24 month lag
* tm1violence2014 = May 2013-April 2014
* tm2violence2014 = May 2012-April 2013
* tm3violence2014 = May 2011-April 2012
* tm1violence2017 = Aug 2016-July 2017
* tm2violence2017 = Aug 2015-July 2016
* tm3violence2017 = Aug 2014-July 2015

* Create date clusters of month and year as above
gen date_cluster=.
replace date_cluster=1 if month>4 & year==2013 | month<5 & year==2014
replace date_cluster=2 if month>4 & year==2012 | month<5 & year==2013
replace date_cluster=3 if month>4 & year==2011 | month<5 & year==2012
replace date_cluster=4 if month>7 & year==2016 | month<8 & year==2017
replace date_cluster=5 if month>7 & year==2015 | month<8 & year==2016
replace date_cluster=6 if month>7 & year==2014 | month<8 & year==2015

* Collapse by grid id and date cluster
collapse(sum) event, by(grid_id date_cluster)

* Drop dates that were not used
drop if date_cluster==.

* Reshape!
reshape wide event, i(grid_id) j(date_cluster)

* Generate independent variables for regression: violence at t-1, t-2, t-3
gen tm1violence2014=.
gen tm2violence2014=.
gen tm3violence2014=.
gen tm1violence2017=.
gen tm2violence2017=.
gen tm3violence2017=.

replace tm1violence2014=event1
replace tm2violence2014=event2
replace tm3violence2014=event3
replace tm1violence2017=event4
replace tm2violence2017=event5
replace tm3violence2017=event6

drop event*

* Reshape again!
reshape long tm1violence tm2violence tm3violence, i(grid_id) j(year)

* Generate independent variables for secondary regression: change of violence between t-1 and t-2
replace tm1violence=0 if tm1violence==.
replace tm2violence=0 if tm2violence==.
replace tm3violence=0 if tm3violence==.

gen delta_tm1_tm2_violence=tm1violence-tm2violence

save "$dir/Violence_Final.dta", replace


/// Step 3: Secondary anaysis - Drop peaceful protests ///
use "$dir/Grid_ACLED.dta", clear

drop if sub_event_type=="Peaceful protest"

* Repeat the process above
* Count events by grid by year
gen event=1

collapse(sum) event, by(grid_id year month)

* Create date clusters of month and year
gen date_cluster=.
replace date_cluster=1 if month>4 & year==2013 | month<5 & year==2014
replace date_cluster=2 if month>4 & year==2012 | month<5 & year==2013
replace date_cluster=3 if month>4 & year==2011 | month<5 & year==2012
replace date_cluster=4 if month>7 & year==2016 | month<8 & year==2017
replace date_cluster=5 if month>7 & year==2015 | month<8 & year==2016
replace date_cluster=6 if month>7 & year==2014 | month<8 & year==2015

* Collapse by grid id and date cluster
collapse(sum) event, by(grid_id date_cluster)

* Drop dates that were not used
drop if date_cluster==.

* Reshape!
reshape wide event, i(grid_id) j(date_cluster)

* Generate independent variables for regression: violence at t-1, t-2, t-3
gen tm1violence2014=.
gen tm2violence2014=.
gen tm3violence2014=.
gen tm1violence2017=.
gen tm2violence2017=.
gen tm3violence2017=.

replace tm1violence2014=event1
replace tm2violence2014=event2
replace tm3violence2014=event3
replace tm1violence2017=event4
replace tm2violence2017=event5
replace tm3violence2017=event6

drop event*

* Reshape again!
reshape long tm1violence tm2violence tm3violence, i(grid_id) j(year)

* Generate independent variables for secondary regression: change of violence between t-1 and t-2
replace tm1violence=0 if tm1violence==.
replace tm2violence=0 if tm2violence==.
replace tm3violence=0 if tm3violence==.

gen delta_tm1_tm2_violence=tm1violence-tm2violence

save "$dir/Violence_Final_No_Protests.dta", replace

log close

*----------------------------------------------------------
* STEP 3: Merge, Visualizations, and Regressions
*----------------------------------------------------------

* STEP 3 Setup
*----------------------------------------------------------
clear
set more off
cap log close
cap clear matrix
clear mata
set maxvar 8000

* Store Working Directory
global dir "/Users/gayeongsong/Desktop/Econ 80 Paper"
log using "$dir/Main", text replace
*----------------------------------------------------------

/// Step 1: Merge to make the full dataset ///
use "$dir/Bangladesh SPA/Bangladesh_Panel_Cleaned.dta", clear

merge m:1 grid_id year using "$dir/ACLED/Violence_Final.dta", nogenerate

save "$dir/Full_Panel.dta", replace

order grid_id year
sort grid_id year


/// Step 2: Produce Descriptive Figures, Tables, and Maps ///
/* OUTCOME VAR - Summary Statistic of Facilities */
foreach y of numlist 2014 2017 {
	preserve
	keep if year==`y'
	foreach var of varlist factype mga ftype ipd_opd {
		tabulate `var', matcell(freq_`var') matrow(names_`var')
		putexcel set "$dir/Results/Facility_Descriptive", sheet("`y'_`var'") modify
		putexcel A1=("Facility type") B1=("Frequency") 
		putexcel A2=matrix(names_`var') B2=matrix(freq_`var') 
	}
	restore
}


/* OUTCOME VAR - Distribution of Service Availability and Readiness */
* Percent of offerings a hospital carries
graph hbox service_pc, title("Medical Services") name(graph1, replace)
graph hbox equip_pc, title("Equipment") name(graph2, replace)
graph hbox med_pc, title("Medicine") name(graph3, replace)
graph hbox diag_pc, title("Diagnostics") name(graph4, replace)
graph hbox fp_pc, title("Family Planning") name(graph5, replace)
graph hbox deliv_pc, title("Routine Delivery Supply") name(graph6, replace)

graph combine graph1 graph2 graph3 graph4 graph5 graph6
graph export "$dir/Figures/Percent.png", replace

* Z score of weighted indices
graph hbox service_index_z, title("Medical Services") name(graph7, replace)
graph hbox equip_index_z, title("Equipment") name(graph8, replace)
graph hbox med_index_z, title("Medicine") name(graph9, replace)
graph hbox diag_index_z, title("Diagnostics") name(graph10, replace)
graph hbox fp_index_z, title("Family Planning") name(graph11, replace)
graph hbox deliv_index_z, title("Routine Delivery Supply") name(graph12, replace)

graph combine graph7 graph8 graph9 graph10 graph11 graph12
graph export "$dir/Figures/Z_Score.png", replace


/* OUTCOME VAR - Map of Bangladesh & Health Facilities Surveyed */
* Acquire dataset of Bangladesh country boundaries
shp2dta using "$dir/Bangladesh Shapefile/adm0", ///
		replace database("$dir/Bangladesh Shapefile/bangdb") ///
		coordinates("$dir/Bangladesh Shapefile/bangcoord") genid("id") 

foreach y of numlist 2014 2017 {
	preserve
	use "$dir/Bangladesh Shapefile/bangcoord.dta", clear
	rename _X _Xshp
	rename _Y _Yshp

	append using "$dir/Bangladesh SPA/`y'/`y'_coord.dta"
	
	drop if _X==0
	drop if _Y==0

	graph twoway (scatter _Yshp _Xshp, yscale(off) xscale(off) msize(vtiny) aspectratio(1)) ///
				 (scatter _Y _X, yscale(off) xscale(off) msize(tiny) msymbol(T)), ///
				 title("Surveyed in `y'") legend(off) ///
				 name(graph`y', replace)
	restore
}

graph combine graph2014 graph2017
graph export "$dir/Figures/Facilities_Map.png", replace


/* OUTCOME VAR - Example Grid */
* As an example, I show 16 grids between X coordinate 90-91 degrees and Y coordinate 22-23 degrees
* Keep the specifications I want from shapefile
use "$dir/Bangladesh Shapefile/bangcoord.dta", clear
rename _X _Xshp
rename _Y _Yshp
keep if 22 < _Yshp & _Yshp < 23
keep if 90 < _Xshp & _Xshp < 91
save "$dir/Bangladesh Shapefile/bangcoord_sample_grid.dta", replace

* Keep the specifications I want from 2014 facility locations
use "$dir/Bangladesh SPA/2014/2014_coord.dta", clear
rename _X _X2014
rename _Y _Y2014
keep if 22 < _Y2014 & _Y2014 < 23
keep if 90 < _X2014 & _X2014 < 91
save "$dir/Bangladesh SPA/2014/2014_coord_sample_grid.dta", replace

* Keep the specifications i want from 2017 facility locations
use "$dir/Bangladesh SPA/2017/2017_coord.dta", clear
rename _X _X2017
rename _Y _Y2017
keep if 22 < _Y2017 & _Y2017 < 23
keep if 90 < _X2017 & _X2017 < 91
save "$dir/Bangladesh SPA/2017/2017_coord_sample_grid.dta", replace

* Append all
use "$dir/Bangladesh Shapefile/bangcoord_sample_grid.dta", clear
append using "$dir/Bangladesh SPA/2014/2014_coord_sample_grid.dta"
append using "$dir/Bangladesh SPA/2017/2017_coord_sample_grid.dta"

* Graph!
graph twoway (scatter _Yshp _Xshp, yscale(off) xscale(off) msize(vtiny) aspectratio(1)) ///
			 (scatter _Y2014 _X2014, yscale(off) xscale(off) msize(small) msymbol(T) mcolor(navy)) ///
			 (scatter _Y2017 _X2017, yscale(off) xscale(off) msize(small) msymbol(T) mcolor(orange)), ///
			 title("Sample 25km-by-25km Grids") legend(off) ///
			 note("16 grids between X coordinate 90-91 degrees and Y coordinate 22-23 degrees") ///
			 yline(22 22.25 22.5 22.75 23, lcolor(black)) ///
			 xline(90 90.25 90.5 90.75 91, lcolor(black))
graph export "$dir/Figures/Sample_Grid.png", replace


/* TREATMENT VAR - Summary Statistic of Violence Using Stacked Bar (Partial, for paper) */
use "$dir/ACLED/Grid_ACLED.dta", clear

* Generate a count for all events
gen event=1

* Collapse by year and sub event type
collapse(sum) event, by(sub_event_type year)
* Create a variable that contains total events that year
bysort year: egen total_event = sum(event)
* Keep only the top 4 event types
keep if sub_event_type=="Mob violence" | sub_event_type=="Peaceful protest" | ///
		sub_event_type=="Attack" | sub_event_type=="Armed clash"

* Assign numeric values for each event type
encode sub_event_type, gen(n_sub_event_type)

* Running count variable will be the main variable for overlayed bar graph.
* I will make my stacked bar by calculating a cumulative event count
gen running_count=.

* Generate 4 variables that contain number of events in each of the 4 types of violence
gen temp_count_1=event if n_sub_event_type==1
gen temp_count_2=event if n_sub_event_type==2
gen temp_count_3=event if n_sub_event_type==3
gen temp_count_4=event if n_sub_event_type==4

sort year n_sub_event_type

* Replace missing values
replace temp_count_1=temp_count_1[_n-1] if n_sub_event_type==2
replace temp_count_1=temp_count_1[_n-2] if n_sub_event_type==3
replace temp_count_1=temp_count_1[_n-3] if n_sub_event_type==4

replace temp_count_2=temp_count_2[_n+1] if n_sub_event_type==1
replace temp_count_2=temp_count_2[_n-1] if n_sub_event_type==3
replace temp_count_2=temp_count_2[_n-2] if n_sub_event_type==4

replace temp_count_3=temp_count_3[_n+2] if n_sub_event_type==1
replace temp_count_3=temp_count_3[_n+1] if n_sub_event_type==2
replace temp_count_3=temp_count_3[_n-1] if n_sub_event_type==4

replace temp_count_4=temp_count_4[_n+3] if n_sub_event_type==1
replace temp_count_4=temp_count_4[_n+2] if n_sub_event_type==2
replace temp_count_4=temp_count_4[_n+1] if n_sub_event_type==3

* Cumulative event count 
egen temp_sum_2 = rowtotal(temp_count_1 temp_count_2)
egen temp_sum_3 = rowtotal(temp_count_1 temp_count_2 temp_count_3)
egen temp_sum_4 = rowtotal(temp_count_1 temp_count_2 temp_count_3 temp_count_4)

* Organize the above to the running_count var
replace running_count=temp_count_1 if n_sub_event_type==1
replace running_count=temp_sum_2 if n_sub_event_type==2
replace running_count=temp_sum_3 if n_sub_event_type==3
replace running_count=temp_sum_4 if n_sub_event_type==4
		
* Graph!
graph twoway (bar total_event year) ///
			 (bar running_count year if sub_event_type=="Peaceful protest") ///
			 (bar running_count year if sub_event_type=="Mob violence") ///
			 (bar running_count year if sub_event_type=="Attack") ///
			 (bar running_count year if sub_event_type=="Armed clash"), ///
			 title("Types of Violent Events Per Year") ///
			 xtitle("Year") ytitle("Events") ///
			 xlabel(2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021) ///
			 legend(label(1 "Other") label(2 "Peaceful Protest") ///
			 label(3 "Mob Violence") label(4 "Attack") label(5 "Armed Clash"))
			 
graph export "$dir/Figures/Violence_Stacked_bar.png", replace


/* TREATMENT VAR - Summary Statistic of Violence (Total, for Supp. Appendix) */
use "$dir/ACLED/Grid_ACLED.dta", clear

encode sub_event_type, gen(n_sub_event_type)

forval y=2010/2021 {
	preserve
	
	keep if year==`y'
	tabulate n_sub_event_type, matcell(freq_`y') matrow(names_`y')
	putexcel set "$dir/Results/Violence_Descriptive", sheet("`y'_eventtype") modify
	putexcel A1=("Violence Type") B1=("Frequency") C1=("Percent")
	putexcel A2=matrix(names_`y') B2=matrix(freq_`y') C2=matrix((freq_`y'/r(N))*100)
	
	restore
}


/* TREATMENT VAR - Distribution of Violence */
use "$dir/ACLED/Violence_Collapse.dta", clear

* Create graph that shows violence over year
preserve
collapse(sum) event, by(year)
graph bar event, over(year) title("Violence in Bangladesh") ///
		ytitle("Violent Events")
graph export "$dir/Figures/Violence_Per_Year.png", replace
restore

* Create box plot to show more detailed distribution of violence per year
drop if event > 60
label variable event "Violent Events Per Grid"
graph hbox event, by(year) 
graph export "$dir/Figures/Violence_Per_Grid.png", replace


/* Binscatter */
use "$dir/Full_Panel.dta", clear

binscatter service_pc tm1violence, n(100) name(bin_1, replace) title("Medical Services")
binscatter equip_pc tm1violence, n(100) name(bin_2, replace) title("Equipment")
binscatter med_pc tm1violence, n(100) name(bin_3, replace) title("Medicine")
binscatter diag_pc tm1violence, n(100) name(bin_4, replace) title("Diagnostics")
binscatter fp_pc tm1violence, n(100) name(bin_5, replace) title("Family Planning")
binscatter deliv_pc tm1violence, n(100) name(bin_6, replace) title("Routine Delivery Supply")

graph combine bin_1 bin_2 bin_3 bin_4 bin_5 bin_6
graph export "$dir/Figures/Binscatter.png", replace


/// Step 3: Regression 1 -- violence at t-1 & t-2 ///
use "$dir/Full_Panel.dta", clear

* Create and rename controls
replace q440=0 if q440!=1
rename q440 quality_assurance

replace q430=0 if q430!=1
rename q430 client_opinions

* Define control list for the two regressions below in Step 3 and Step 4
global control_list "i.factype i.ftype i.mga ipd_opd i.month i.region quality_assurance client_opinions"

* Weights must be divided by 1,000,000 for use, according to dataset documentation
gen weight = facwt / 1000000


/* Percent Index of Provision */
areg service_pc tm1violence tm2violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/quantity_reg.xls", replace ctitle(service_pc) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_pc {
	areg `var' tm1violence tm2violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/quantity_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, No, Grid FE, Yes, Year FE, No)
			
	areg `var' tm1violence tm2violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/quantity_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/* Rarity-Weighted Index of Provision */
areg service_index_z tm1violence tm2violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/index_reg.xls", replace ctitle(service_z) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, No)

foreach var of varlist *_index_z {
	areg `var' tm1violence tm2violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/index_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, No, Grid FE, Yes, Year FE, No)
	areg `var' tm1violence tm2violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/index_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/// Step 4: Regression 2 -- violence at t-1 & level change between t-1 and t-2 ///

/* Percent Index of Provision */
areg service_pc tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/delta_quantity_reg.xls", replace ctitle(service_pc) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_pc {
	areg `var' tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/delta_quantity_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)
			
	areg `var' tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/delta_quantity_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/* Rarity-Weighted Index of Provision */
areg service_index_z tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/delta_index_reg.xls", replace ctitle(service_z) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_index_z {
	areg `var' tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/delta_index_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)
	areg `var' tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/delta_index_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/// Step 5: Regressions after dropping peaceful protests
use "$dir/Bangladesh SPA/Bangladesh_Panel_Cleaned.dta", clear

merge m:1 grid_id year using "$dir/ACLED/Violence_Final_No_Protests.dta", nogenerate

order grid_id year
sort grid_id year

save "$dir/Full_Panel_No_Protests.dta", replace

* Create and rename controls
replace q440=0 if q440!=1
rename q440 quality_assurance

replace q430=0 if q430!=1
rename q430 client_opinions

* Weights must be divided by 1,000,000 for use, according to dataset documentation
gen weight = facwt / 1000000

* Define control list for the two regressions below in Step 3 and Step 4
global control_list "i.factype i.ftype i.mga ipd_opd i.month i.region quality_assurance client_opinions"

/* Percent Index of Provision */
areg service_pc tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/no_protests_delta_quantity_reg.xls", replace ctitle(service_pc) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_pc {		
	areg `var' tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/no_protests_delta_quantity_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}
	
/* Rarity-Weighted Index of Provision */
areg service_index_z tm1violence delta_tm1_tm2_violence i.year [aw=weight], absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/no_protests_delta_index_reg.xls", replace ctitle(service_z) ///
		addtext (Facility Controls, No, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_index_z {
	areg `var' tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
			absorb(grid_id) cluster(grid_id)
	outreg2 using "$dir/Results/no_protests_delta_index_reg.xls", append ctitle(`var') ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/// Step 6: ACPR Plot to detect nonlinearity in data ///
use "$dir/Full_Panel.dta", clear

* Create and rename controls
replace q440=0 if q440!=1
rename q440 quality_assurance

replace q430=0 if q430!=1
rename q430 client_opinions

* Define control list for the two regressions below in Step 3 and Step 4
global control_list "i.factype i.ftype i.mga ipd_opd i.month i.region quality_assurance client_opinions"

* Weights must be divided by 1,000,000 for use, according to dataset documentation
gen weight = facwt / 1000000

* Drop outliers 
preserve

drop if tm1violence > 100

* ACPR Plot!
quietly reg service_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_1, replace) title("Medical Services")

quietly reg equip_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_2, replace) title("Equipment")

quietly reg med_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_3, replace) title("Medicine")

quietly reg diag_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_4, replace) title("Diagnostics")

quietly reg fp_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_5, replace) title("Family Planning")

quietly reg deliv_pc tm1violence i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
acprplot tm1violence, mspline name(acprplot_6, replace) title("Routine Delivery Supply")

graph combine acprplot_1 acprplot_2 acprplot_3 acprplot_4 acprplot_5 acprplot_6
graph export "$dir/Figures/ACPR.png", replace

restore


/// Step 7: Spline ///
* Make kink around the 90th percentile 
summ tm1violence, d
mkspline tm1violence_1 24 tm1violence_2 = tm1violence

* Loop and regress
reg service_pc delta_tm1_tm2_violence tm1violence_1 tm1violence_2 ///
	i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
outreg2 using "$dir/Results/spline_quantity_reg.xls", replace ctitle(service_pc) ///
		keep (delta_tm1_tm2_violence tm1violence_1 tm1violence_2) ///
		addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)

foreach var of varlist *_pc {		
	reg `var' delta_tm1_tm2_violence tm1violence_1 tm1violence_2 ///
			i.year i.grid_id $control_list [aw=weight], cluster(grid_id)
	outreg2 using "$dir/Results/spline_quantity_reg.xls", append ctitle(`var') ///
			keep (delta_tm1_tm2_violence tm1violence_1 tm1violence_2) ///
			addtext (Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
}


/// Step 8: Sanitation ///
* Including peaceful protests
areg sanitation_pc tm1violence tm2violence i.year $control_list [aw=weight], ///
	 absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/sanitation_reg.xls", replace ctitle(With Protest) ///
		addtext(Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
		
areg sanitation_pc tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
	 absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/sanitation_reg.xls", append ctitle(With Protest) ///
		addtext(Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)

* Excluding peaceful protests
use "$dir/Full_Panel_No_Protests.dta", clear

* Create and rename controls
replace q440=0 if q440!=1
rename q440 quality_assurance

replace q430=0 if q430!=1
rename q430 client_opinions

* Define control list for the two regressions below in Step 3 and Step 4
global control_list "i.factype i.ftype i.mga ipd_opd i.month i.region quality_assurance client_opinions"

* Weights must be divided by 1,000,000 for use, according to dataset documentation
gen weight = facwt / 1000000

areg sanitation_pc tm1violence tm2violence i.year $control_list [aw=weight], ///
	 absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/sanitation_reg.xls", append ctitle(No Protest) ///
		addtext(Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)
		
areg sanitation_pc tm1violence delta_tm1_tm2_violence i.year $control_list [aw=weight], ///
	 absorb(grid_id) cluster(grid_id)
outreg2 using "$dir/Results/sanitation_reg.xls", append ctitle(No Protest) ///
		addtext(Facility Controls, Yes, Grid FE, Yes, Year FE, Yes)

log close

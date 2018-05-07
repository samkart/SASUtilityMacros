
/*column sorter*/

%macro colsort (lib		/*SAS Library where table is stored*/,
				tab		/*Table name*/,
				drop	/*OPTIONAL - Columns to not consider in sorting; used as per like operator with single quotes; e.g. 'N%'*/,
				keep	/*OPTIONAL - Columns to consider in sorting; used as per like operator with single quotes; e.g. 'N%'*/,
				order	/*OPTIONAL - Sorting order - asc or desc*/,
				date	/*OPTIONAL - If date sort reqd. Types supported: no, mm/dd/yyyy, dd/mm/yyyy, mmmyy, etc. PLEASE TYPE EXACT FORMAT*/);

%global cols;

%if &lib eq %str( ) %then %let lib = work;

%if &keep ne %str( ) and &drop ne %str( ) %then %do;
	%put ERROR: DROP and KEEP can not be specified together;
	%abort; %end;
%else %if &drop ne %str( ) and &keep eq %str( ) %then %let statement = and upcase(name) not like %upcase(&drop.);
%else %if &keep ne %str( ) and &drop eq %str( ) %then %let statement = and upcase(name) like %upcase(&keep.);
%else %if &keep eq %str( ) and &drop eq %str( ) %then %let statement = %str( );

%if &order ne %str( ) and %lowcase(&order) ne asc and %lowcase(&order) ne desc %then %do;
	%put ERROR: Cannot decipher your sort order;
	%abort; %end;

%if &date eq %str( ) %then %do;
	%put WARNING: DATE parameter is blank | Assuming no date sorts required;
	%let date = no; %end;

/*regular expression sorting*/
%if %lowcase(&date) eq no %then %do;

proc sql;
select cats("'",name,"'n") as cols into:cols separated by ','
from dictionary.columns
where libname = %upcase("&lib.") and memname = %upcase("&tab.") &statement.
order by 1 &order.;
quit;

%end;

/*date sorting*/
%else %do;

%if %lowcase(&date) ne no %then %do;

/*checking start index for mdy and character counts from date type provided*/
%let m_cnt = %sysfunc(count(%lowcase(&date),m)); %let m_ = %index(%lowcase(&date),m);
%let d_cnt = %sysfunc(count(%lowcase(&date),d)); %let d_ = %index(%lowcase(&date),d);
%let y_cnt = %sysfunc(count(%lowcase(&date),y)); %let y_ = %index(%lowcase(&date),y);

%if &m_cnt ne 0 %then %let mon = substr(compress(name),&m_,&m_cnt.);

%if &d_cnt ne 0 %then %let day = substr(compress(name),&d_,&d_cnt.);
%else %if &d_cnt eq 0 %then %let day = 01;

%if &y_cnt ne 0 and y_cnt eq 4 %then %let year = substr(compress(name),&y_,&y_cnt.);
%else %if &y_cnt ne 0 and y_cnt eq 2 %then %let year = cats('20',substr(compress(name),&y_,&y_cnt.));

%if &m_cnt le 1 or &y_cnt le 1 or &y_cnt eq 3 or &y_cnt gt 4 %then %do;
	%put ERROR: Could not understand your date format;
	%put NOTE: In case you feel this is not correct, please reach out to the concerned team;
	%abort; %end;

/*date sort by creating date9. formats -- if char count for mon is 2 (01)*/
%if &m_cnt eq 2 %then %do;

proc sql noprint;
create table _temp_date_sort_ as 
select cats("'",name,"'n") as cols, mdy(input(&mon,2.),input(&day,2.),input(&year,4.)) as dt format=date9.
from dictionary.columns
where libname = %upcase("&lib.") and memname = %upcase("&tab.") &statement.
order by 2 &order.;
select cols into:cols separated by ','
from _temp_date_sort_;
drop table _temp_date_sort_;
quit;

%end;

/*date sort by creating date9. formats -- if char count for mon is 3 (JAN)*/
%else %if m_cnt eq 3 %then %do;

data _temp_date_sort_;
set sashelp.vcolumn (keep=name libname memname where=(libname = %upcase("&lib.") and memname = %upcase("&tab.") &statement.));
_dt_ = cats(&day,&mon,&year);
dt = input(_dt_,date9.);
format dt date9.;
cols = cats("'",name,"'n");
keep dt cols;
run;

%if %lowcase(&order) eq desc %then %let dsord = descending;
%else %let dsord = %str( );

proc sort data=_temp_date_sort_;
by &dsord. dt;
run;

proc sql noprint;
select cols into:cols separated by ','
from _temp_date_sort_;
drop table _temp_date_sort_;
quit;

%end;

%else %do;
	%put ERROR: Specified month format not supported. Please reach out to concerned team for required updates.;
	%abort; %end;

%end;

%put |&cols|;

%mend colsort;

%colsort(,temp,'reg%',,,);

/*SQL*/
proc sql;
create table temp as 
select reg_grp, &cols. from temp;
quit;

/*DATA STEP*/
%let dscols = %sysfunc(tranwrd(%superq(cols),%str(,),%str( )));

data temp;
retain reg: &dscols. ;
set temp;
run;

%symdel cols dscols; /*deleting the macro after use, to avoid accidental use in other tables; potential error*/

/*
%if &date eq mm/dd/yyyy %then %do;
		%let mon = input(substr(compress(name),1,2),2.);
		%let day = input(substr(compress(name),4,2),2.);
		%let year = input(substr(compress(name),7,4),2.);
	%end;
	%else %if &date eq dd/mm/yyyy %then %do;
		%let mon = input(substr(compress(name),4,2),2.);
		%let day = input(substr(compress(name),1,2),2.);
		%let year = input(substr(compress(name),7,4),2.);
	%end;

mm/dd/yyyy
*/
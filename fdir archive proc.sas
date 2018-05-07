/*DIR Archive Procedure*/

%macro darchive(libin/*Input Library*/,
				libout/*Output Library*/,
				force/*OPTIONAL, will force a binary transfer for SAS datasets |Leave blank if not reqd|*/);

options nonotes lrecl=32767;

filename inlib "%sysfunc(pathname(&libin))";

data dir_&libin;
length filenm $64;
dop=dopen('inlib');
mx=dnum(dop);
do i = 1 to mx;
filenm = compress(dread(dop,i));
if index(filenm,".")>0  /*change this to eq 0 if folder*/
    then output;
end;
dc=dclose(dop);
keep filenm;
run;

data sas_ds_&libin rest_files_&libin;
set dir_&libin;
if index(filenm,".sas7bdat")>0
    then output sas_ds_&libin;
else if index(filenm,".sas7bdat")=0 
	then output rest_files_&libin;
run;

filename inlib;

proc sql noprint;
select count(filenm) into:sasdscnt from sas_ds_&libin;
select count(filenm) into:restfscnt from rest_files_&libin;
quit;

%put |%sysfunc(strip(&sasdscnt. SAS datasets))|;
%put |%sysfunc(strip(&restfscnt. External files))|;

%if &force ^= %str( ) %then %do;
%put |OPTION FORCE in place. Will initiate Binary Transfer for all files.|;

data rest_files_&libin;
set sas_ds_&libin rest_files_&libin;
run;

proc sql noprint;
select count(filenm) into:restfscnt from rest_files_&libin;
quit;

%goto override;
%end;

%if &sasdscnt ^= 0 %then %do;
%put |SAS Datasets Available|;

proc sql;
title "SAS Files";
select substr(filenm,1,length(trim(filenm))-length(".sas7bdat")) as file into:sasfs separated by ','
from sas_ds_&libin
order by 1;
quit;

%put |&sasfs|;

%let i = 1;
%do %while (%scan(%superq(sasfs),&i,%str(,)) ne %str( ));
%let ds = %trim(%scan(%superq(sasfs),&i,%str(,)));
%put |Archiving &ds.|;

data &libout..&ds.;
set &libin..&ds.;
run;

%let i = %sysevalf(&i + 1);
%end;

%end;

%else %put |No SAS Dataset Found|;

%override:
%if &restfscnt ^= 0 %then %do;
%put |External Files Found! Will initiate Binary Transfer|;

proc sql;
title "External Files";
select trim(filenm) as file into:restfs separated by ','
from rest_files_&libin
order by 1;
title;
quit;

%put |&restfs|;

%let j = 1;
%do %while (%bquote(%scan(%superq(restfs),&j,%str(,))) ne %str( ));
%let fs = %bquote(%sysfunc(trim(%scan(%superq(restfs),&j,%str(,)))));

filename prevfl "%sysfunc(pathname(&libin))/&fs." recfm=n;
filename copyloc "%sysfunc(pathname(&libout))/&fs." recfm=n;

data _null_;
put "|Archiving &fs.|";
fcop = fcopy("prevfl","copyloc");
if fcop = 0 /*Success code*/ then do;
	put '|Successfully copied source to DEST!|';
end;
else do;
	msg = sysmsg();
	put fcop= msg=;
end;
run;

%let j = %sysevalf(&j + 1);
%end;

%end;

%else %put |No External Files Found|;

options notes;

%mend darchive;

libname dmtest "//MktSci3/Projects/Immunology/Esbriet/Cross_Year/Esbriet_DM_Dashboard/esb_dm_trans_test/03_Output";

options dlcreatedir;
libname dmarchf "//MktSci3/Projects/Immunology/Esbriet/Cross_Year/Esbriet_DM_Dashboard/esb_dm_trans_test/03_Output/archf";
libname dmarch "//MktSci3/Projects/Immunology/Esbriet/Cross_Year/Esbriet_DM_Dashboard/esb_dm_trans_test/03_Output/arch";
options nodlcreatedir;

%darchive(dmtest,dmarch,)
%darchive(dmtest,dmarchf,force)

/*-------------------------------------------------------------------------------------------------------------------------*/
/*File Archive Procedure*/

%macro farchive(libin/*Input Library*/,
				libout/*Output Library*/,
				fname/*Name of the file to be copied including extension*/);


filename prevfl "%sysfunc(pathname(&libin))/&fname." recfm=n;
filename copyloc "%sysfunc(pathname(&libout))/&fname." recfm=n;

data _null_;
put "|Archiving &fname.|";
fcop = fcopy("prevfl","copyloc");
if fcop = 0 /*Success code*/ then do;
	put "|Successfully copied &fname. to DEST!|";
end;
else do;
	msg = sysmsg();
	put fcop= msg=;
end;
run;

%mend farchive;

libname dmtest "//MktSci3/Projects/Immunology/Esbriet/Cross_Year/Esbriet_DM_Dashboard/esb_dm_trans_test/03_Output";

options dlcreatedir;
libname dmarchf "//MktSci3/Projects/Immunology/Esbriet/Cross_Year/Esbriet_DM_Dashboard/esb_dm_trans_test/03_Output/archf";
options nodlcreatedir;

%farchive(dmtest,dmarchf,mydataset.sas7bdat);
%farchive(dmtest,dmarchf,myfile.xlsx);
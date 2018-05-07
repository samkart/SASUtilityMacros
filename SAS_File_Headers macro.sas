


%macro CodeHeader(libname/*libname where file should be saved, OPTIONAL*/,
                    filename/*desired name of the file (no arithmatic notations), OPTIONAL*/,
                    process/*name of the process*/,
                    freq/*refresh frequency of the process*/,
                    code/*name of the code, OPTIONAL*/,
                    author/*Author Name*/);

options nonotes lrecl=32767;

%let process = %bquote(&process);
%let freq = %bquote(&freq);
%let code = %bquote(&code);
%let author = %bquote(&author);

%if &filename = %str( ) %then %let filename = &code; /*If filename var is left blank it will take the value of code var*/
%if &code = %str( ) %then %let code = &filename; /*If code var is left blank it will take the value of filename var*/

%if &libname ^= %str( ) and &filename ^= %str( ) %then %do; /*A file will be created only if you have specified a valid SAS library and a filename/codename*/
%put %sysfunc(trim(%sysfunc(putc(session %lowcase(&author),$base64x64.))));
%put |Your file \\dnafiles\mktsci3%substr(%sysfunc(tranwrd(%sysfunc(pathname(&libname))/&filename..sas,/,\)),%length(/MktSci3/),%sysevalf(%length(%sysfunc(pathname(&libname))/&filename..sas)-%length(/MktSci3)))|; /*Change this for your server locations*/
%let libflflag = Y;
filename txt "%sysfunc(pathname(&libname))/&filename..sas" mod termstr=crlf; %end; /*You will be able to append your outputs (iterations) to your file*/

%else %if (&libname = %str( ) or &filename = %str( )) %then %do;
%let libflflag = N;
filename txt temp;
%put |%sysfunc(trim(%sysfunc(putc(sup %lowcase(&author),$base64x64.)))) ERR;
%put ||DONT KNOW WHERE TO CREATE WHAT FILE||ROUTING OUTPUT TO SASLOG||; %end;

data _null_;
proclen = length("Process Name:")+length("&process");
freqlen = length("Frequency:")+length("&freq");
codelen = length("Code:")+length("&code");
authlen = length("Author:")+length("&author");
datelen = length("Date:")+length("&sysdate");
maxlen = max(proclen,freqlen,codelen,authlen,datelen);

call symputx('len', maxlen);
call symputx('proclen', proclen);
call symputx('freqlen', freqlen);
call symputx('codelen', codelen);
call symputx('authlen', authlen);
call symputx('datelen', datelen);
run;

%if &process = %str( ) and &freq = %str( ) and &code = %str( ) and &author = %str( ) %then %let len = 32; /*Override for a Dummy header*/ 

data _null_;
libflflag = symget('libflflag');
codename = symget('code');

if compress(libflflag) = 'Y' then do;
put "|Writing to file|";
file txt;
end;

sten = cat("/*",repeat("*",&len),"**/");
pname = cat("/*","Process Name: ",trim(propcase("&process")),repeat(' ',%sysevalf(&len-&proclen)),"*/");
freq = cat("/*","Frequency: ",trim(propcase("&freq")),repeat(' ',%sysevalf(&len-&freqlen)),"*/");
if not missing(codename) then 
cname = cat("/*","Code: ",trim(propcase("&code")),repeat(' ',%sysevalf(&len-&codelen)),"*/");
auth = cat("/*","Author: ",trim(propcase("&author")),repeat(' ',%sysevalf(&len-&authlen)),"*/");
dt = cat("/*","Date: ",trim("&sysdate"),repeat(' ',%sysevalf(&len-&datelen)),"*/");

put sten;
put pname;
put freq;
if not missing(codename) then put cname;
put auth;
put dt;
put sten;

run;

filename txt;
options notes;

%mend CodeHeader;

/*No libname No filename*/
%codeheader(,,Xolair AA CIU Vial Split,Weekly,a01 something,yuwraj bajaj);
%codeheader(,,code header,ad-hoc,,);

/*Dummy*/
%codeheader(,,,,,); 

/*Creating a file*//*SASlog will have the full path to your file*/
libname mkpr "/MktSci3/Projects";
%codeheader(mkpr,00_CodeHeader_Trial,persistency,Ad-hoc,a02 persistency,YUWRAJ BAJAJ); /*with libname and filename*/
%codeheader(mkpr,,persistency 2,Ad-hoc,00_CodeHeader_Trial,YUWRAJ bajaj); /*without filename, it uses the code var as the filename*//*If given same filename, it will append your output to the same file*/
libname mkpr;
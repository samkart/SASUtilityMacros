options mprint;

%macro prefixvar(lib/*libname*/,tab/*table*/,char/*character to prefix*/,macronm/*name of the macro to create*/);
%global m&macronm.;
proc sql;
select cats('"',name,'"n="',"&&char.",name,'"n') into:m&macronm. separated by " "
from dictionary.columns
where libname="%upcase(&lib.)" and memname="%upcase(&tab.)" and upcase(name) not like "%QTR%";
quit;
%put |Your global macro var is m&macronm.|;
%put |&&m&macronm.|;
%mend prefixvar;
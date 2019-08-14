/*----------------------------------------------------------------------
  Program:      MkTable_V1.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to create a table in SAS format based on column
                and row control files designed by %COLCNTL and %ROWCNTL
                macros using CALL EXECUTE
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  OUT     = Desired name for SAS dataset containing the table text
  
  COLCNTL = Name of the column control file for this table
  
  ROWCNTL = Name of the row control file for this table
  ----------------------------------------------------------------------*/
%macro mktable_v1(out     = ,
                  colcntl = ,
                  rowcntl = ,
                  );

  %local _ncol _nrow _c _r;

  %* Combine information from the column and row control files ;
  proc sql noprint;
       create table _tcntl (drop = rdata) as
       select * from
       &colcntl as c full join &rowcntl (rename = (data=rdata)) as r
       on c.data = r.rdata
       order by colnum, rownum;
       quit;

  %* Get the number of columns and rows in the table ;
  proc sql noprint;
       select max(colnum), max(rownum) 
       into :_ncol trimmed, :_nrow trimmed 
       from _tcntl;
       quit;

  %* Data step to run the macros that calculate and format descriptive 
     statistics ;
  data _null_;
       set _tcntl;
       length runstats $ 1000;

       %* Choose the descriptive statistics macro based on the row type ;
       if rowstats = "Continuous" then macro = '%contstats';
       else if rowstats = "Categorical" then macro = '%catstats';
       else if rowstats = "Indicator" then macro = '%flagstats';

       %* Mask any special characters in the column and row labels ;
       collbl = cats('%bquote(',collbl,')');
       rowlbl = cats('%bquote(',rowlbl,')');

       %* Construct the macro call for each column and row combination 
          based on the information in the control file ;
       runstats = cats(macro,
                       "(data=",   data,
                       ",colnum=", colnum,
                       ",colvar=", colvar,
                       ",colval=", colval,
                       ",collbl=", collbl,
                       ",rownum=", rownum,
                       ",rowvar=", rowvar,
                       ",rowlbl=", rowlbl,
                       ",rowfmt=", rowfmt,
                       ",neval=",  neval,
                       ")");

       %* Use CALL EXECUTE to run the macro calls enclosed within %NRSTR
          to prevent any macro variable definitions using CALL SYMPUTX 
          or INTO with PROC SQL from resolving prematurely ;
       call execute(cats('%nrstr(',runstats,')'));
       run;

  %* Combine all rows for each column ;
  %do _c = 1 %to &_ncol;
      data col&_c;
           set %do _r = 1 %to &_nrow;
                   col&_c.row&_r
               %end;
               ;
           run;
  %end;

  %* Combine all columns to create the final table ;
  data &out;
       merge %do _c = 1 %to &_ncol;
                 col&_c
             %end;
             ;
       by rownum statnum rowlabel;
       run;

  %* Delete intermediate data sets ;
  proc datasets nolist;
       delete _tcntl
              %do _c = 1 %to &_ncol;
                  col&_c
                  %do _r = 1 %to &_nrow;
                      col&_c.row&_r
                  %end;
              %end;
              ;
       run;
       quit;

%mend mktable_v1;


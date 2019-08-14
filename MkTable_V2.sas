/*----------------------------------------------------------------------
  Program:      MkTable_V2.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to create a table in SAS format based on column
                and row control files designed by %COLCNTL and %ROWCNTL
                macros using PROC TABULATE
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  OUT     = Desired name for SAS dataset containing the table text
  
  COLCNTL = Name of the column control file for this table
  
  ROWCNTL = Name of the row control file for this table
  ----------------------------------------------------------------------*/
%macro mktable_v2(out     = , 
                  colcntl = , 
                  rowcntl = 
                  );

  %local _i _data _colvars _null _nrow _ncol _contvars _catvars
         _ncont _contvar _contstats;

  %* Extract needed information for creating the table from the column
     and row control files ;
  proc sql noprint;
       %* Name of the analysis data set ;
       select distinct(data) into :_data from &colcntl;

       %* Column variable names, ordered as in the column control file ;
       select distinct(colvar), colvarnum 
       into :_colvars separated by " ", :_null separated by " " 
       from &colcntl order by colvarnum;

       %* Column labels, ordered as in the column control file ;
       select collbl, colnum into :_collbl1-, :_null 
       from &colcntl order by colnum;

       %* Row variables and requested statistics (save the number of rows) ;
       select rowvar, rowstats into :_rowvar1-, :_rowstats1- from &rowcntl;
       %let _nrow = &sqlobs;

       %* Row variables names by analysis type ;
       select rowvar into :_contvars separated by " " from &rowcntl 
       where upcase(rowstats) = "CONTINUOUS";
       select rowvar into :_catvars separated by " " from &rowcntl 
       where upcase(rowstats) = "CATEGORICAL";
       select rowvar into :_flagvars separated by " " from &rowcntl 
       where upcase(rowstats) = "INDICATOR";

       quit;

  %* Use PROC TABULATE to calculate all continuous/categorical statistics
     simultaneously -- The MISSING option here is important to make sure 
     that no observations are dropped from the analytic data set ;
  ods listing close;

  proc tabulate data=&_data missing;

       %* Class variables include column, categorical and indicator 
          variables -- PRELOADFMT option makes sure all possible row 
          variable category values are reported, even if missing/zero 
          value (with the PRINTMISS option below) ;
        class &_colvars;
        class &_catvars &_flagvars / preloadfmt;

       %* Continuous variables (where means/SD/median are needed) ;
       var &_contvars;

       %* Construct a "table" for each variable, based on its row type ;
       %do _i = 1 %to &_nrow;
           %if %upcase(&&_rowstats&_i) = CONTINUOUS %then %do;
               table &_colvars, &&_rowvar&_i, n mean std median min max 
                     / printmiss;
           %end;
           %else %do;
               table &_colvars, &&_rowvar&_i, n colpctn / printmiss;
           %end;
       %end;

       %* Output the raw statistics for formatting ;
       ods output table = _stats0;

       run;

  ods listing;

  %* Create a list of continuous variable names with "_:" appended to each
     for array processing ;
  %let _contstats = %str();
  %let _ncont = %sysfunc(countw(&_contvars));

  %do _i = 1 %to &_ncont;
      %let _contvar = %scan(&_contvars,&_i);
      %let _contstats =  &_contstats &_contvar._:;
  %end;

  %* Condense the PROC TABULATE output statistics ;
  data _stats1 (keep = colvar colval rowvar statnum n pct mean std 
                       median min max);
       set _stats0;
       length colvar rowvar revname $ 200;

       array colvars{*} &_colvars;
       array contvars{*} &_contstats;
       array catvars{*} &_catvars &_flagvars;
       array pctn{*} pctn:;

       %* Get the column variable names ;
       do i = 1 to dim(colvars);
          if colvars{i} ne . then do;
             colvar = vname(colvars{i});
             colval = colvars{i};
          end;
       end;

       %* Get categorical variable names and statistic number (for each
          category value) ;
       do i = 1 to dim(catvars);
          if catvars{i} ne . then do;
             rowvar = vname(catvars{i});
             statnum = catvars{i};
          end;
       end;

       %* Condense percentages for categorical/indicator variables into
          one percentage variable called PCT ;
       do i = 1 to dim(pctn);
          if pctn{i} ne . then pct = pctn{i};
       end;

       %* Condense continuous variable statistics creating one variable
          for each statistic ;
       do i = 1 to dim(contvars);
          revname = upcase(reverse(vname(contvars{i})));
          if contvars{i} ne . then do;
             if revname =: reverse("_N") then do;
                rowvar = strip(lowcase(reverse(substr(revname,3))));
                n = contvars{i};
             end;
             else if revname =: reverse("_MEAN") then mean = contvars{i};
             else if revname =: reverse("_STD") then std = contvars{i};
             else if revname =: reverse("_MEDIAN") 
                then median = contvars{i};
             else if revname =: reverse("_MIN") then min = contvars{i};
             else if revname =: reverse("_MAX") then max = contvars{i};
          end;
       end;

       %* if N is missing then set to zero ;
       if n = . then n = 0;
       
       run;

  %* Get the number of decimal places for continuous variable ;
  proc contents data = &_data (keep = &_contvars) 
                out  = _fmtd (keep = name formatd)
                noprint;
       run;

  %* Combine information from the column and row control files ;
  proc sql noprint;
       create table _tcntl0 (drop = rdata) as select *
       from &colcntl as c full join 
            &rowcntl (rename = (data=rdata)) as r
       on c.data = r.rdata;

       %* Add format decimals to the control file information ;
       create table _tcntl (drop = name) as select *
       from _tcntl0 as t left join _fmtd  as f
       on upcase(t.rowvar) = upcase(f.name)
       order by colnum, rownum;

       quit;

  %* Combine table control file information with the table statistics ;
  proc sql noprint;
       create table _stats (drop = cvar cval rvar) as
       select * from
       _tcntl as t join 
       _stats1 (rename = (colvar=cvar colval=cval rowvar=rvar)) as s
       on upcase(t.colvar) = upcase(s.cvar) and 
          t.colval = s.cval and 
          upcase(t.rowvar) = upcase(s.rvar)
       order by rownum, statnum, colnum;
       quit;

  %* Get the number of columns reported ;
  proc sql noprint;
       select max(colnum) into :_ncol trimmed from _stats;
       quit;

  %* Create the final table ;
  data &out (keep = rowlabel rownum statnum col1-col&_ncol);
       set _stats (where = (not (upcase(rowstats) = "INDICATOR" and 
                                 statnum = 9)));
       by rownum statnum colnum;

       label rowlabel = "Row Label"
             rownum   = "Row Number"
             statnum  = "Statistic Number"
             %do _i = 1 %to &_ncol;
                 col&_i = "&&_collbl&_i"
             %end;
             ;

       length rowlabel col1-col&_ncol mean_std1-mean_std&_ncol 
              median_rng1-median_rng&_ncol n_pct1-n_pct&_ncol $ 200
              ;

       retain n_eval1-n_eval&_ncol mean_std1-mean_std&_ncol 
              median_rng1-median_rng&_ncol n_pct1-n_pct&_ncol;

       %* Arrays for column building ;
       array col{&_ncol} $;
       array n_eval{&_ncol};
       array mean_std{&_ncol} $;
       array median_rng{&_ncol} $;
       array n_pct{&_ncol} $;

       %* Use COMMA format for unformatted continuous variables and
          add number of decimal places from PROC CONTENTS ;
       if rowfmt = "" then rowfmt = "COMMA20.";
       if upcase(rowstats) = "CONTINUOUS" then rowfmt = cats(rowfmt,formatd);

       %* Initialize statistics arrays at the start of each new row 
          variable ;
       if first.rownum then do;
          call missing(of n_eval{*});
          call missing(of mean_std{*});
          call missing(of median_rng{*});
          call missing(of n_pct{*});
       end;

       %* Calculate column N for each row variable ;
       n_eval{colnum} + n;

       %* Recalculate percentages for indicator variables after
          eliminating "Unknown" responses (see WHERE clause in
          SET statement for this data set);
       if upcase(rowstats) = "INDICATOR" 
          then pct = n / n_eval{colnum} * 100;

       %* Get statistics for each column for continuous row variables ;
       if upcase(rowstats) = "CONTINUOUS" then do;
          %* Use DOLLAR format instead of AUTODEC for cost variables ;
          if upcase(rowfmt) =: "DOLLAR" then 
             mean_std{colnum} = cat(strip(putn(mean,rowfmt))," (",
                                    strip(putn(std,rowfmt)),")"
                                    );
          %* Otherwise use AUTODEC to automatically determine appropriate
             decimal places ;
          else mean_std{colnum} = cat(strip(put(mean,autodec.))," (",
                                      strip(put(std,autodec.)),")"
                                      );
          %* Use format from the data (or COMMA if missing) with original
             decimal places for median and range measures ;
          median_rng{colnum} = cat(strip(putn(median,rowfmt))," (",
                                   strip(putn(min,rowfmt))," - ",
                                   strip(putn(max,rowfmt)),")"
                                   );
       end;

       %* Get statistics for each column for categorical and indicator
          row variables ;
       else do;
          if upcase(rowstats) = "INDICATOR" and 
             upcase(neval) = "YES" then
             n_pct{colnum} = cat(strip(put(n,comma20.))," / ",
                                 strip(put(n_eval{colnum},comma20.))," (",
                                 strip(put(pct,autopct.)),")"
                                 );
          else n_pct{colnum} = cat(strip(put(n,comma20.))," (",
                                   strip(put(pct,autopct.)),")"
                                   );
       end;

       %* Create the final output columns ;
       if upcase(rowstats) = "CONTINUOUS" and last.rownum then do;
          * Row variable label ;
          statnum = .l;
          rowlabel = rowlbl;
          output;
          
          * N evaluated row ;
          if upcase(neval) = "YES" then do;
             statnum = .n;
             rowlabel = 'A0A0A0A0'x || "N evaluated";
             do i = 1 to &_ncol;
                col{i} = strip(put(n_eval{i},comma20.));
             end;
             if last.rownum then output;
          end;

          * Mean and standard deviation ;
          statnum = 1;
          rowlabel = 'A0A0A0A0'x || "Mean (SD)";
          do i = 1 to &_ncol;
             col{i} = mean_std{i};
          end;
          output;

          * Median and range (min - max) ;
          statnum = 2;
          rowlabel = 'A0A0A0A0'x || "Median (range)";
          do i = 1 to &_ncol;
             col{i} = median_rng{i};
          end;
          output;
       end;

       else if upcase(rowstats) = "CATEGORICAL" then do;
          if last.statnum then do;
             %* Count and percentage ;
             rowlabel = 'A0A0A0A0'x || strip(putn(statnum,rowfmt));
             do i = 1 to &_ncol;
                col{i} = n_pct{i};
             end;

             %* If all columns for the unknown/missing value for a
                categorical variable have zero count then suppress the 
               output ;
             if not (find(rowlabel,"Missing","i") or 
                     find(rowlabel,"Unknown","i"))
                     %do _i = 1 %to &_ncol;
                         or n_pct&_i ^=: "0"
                     %end;
                     then output;
          end;

          if last.rownum then do;
             * Row variable label ;
             statnum = .l;
             call missing(of col{*});
             rowlabel = rowlbl;
             output;
          
             * N evaluated row ;
             if upcase(neval) = "YES" then do;
                statnum = .n;
                rowlabel = 'A0A0A0A0'x || "N evaluated";
                do i = 1 to &_ncol;
                   col{i} = strip(put(n_eval{i},comma20.));
                end;
                output;
             end;
          end;
       end;

       else if upcase(rowstats) = "INDICATOR" and last.statnum then do;
          %* Count and percentage for "Yes" values only ;
          rowlabel = rowlbl;
          do i = 1 to &_ncol;
             col{i} = n_pct{i};
          end;
          if statnum = 1 then output;
       end;

       run;

  %* Sort the output data set by the order specified in the row control 
     file ;
  proc sort data=&out;
       by rownum statnum;
       run;

  %* Delete intermediate data sets ;
  proc datasets nolist;
       delete _stats:
              _tcntl:
              _fmtd
              ;
       run;
       quit;

%mend mktable_v2;

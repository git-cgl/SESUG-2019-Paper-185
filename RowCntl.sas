/*----------------------------------------------------------------------
  Program:      RowCntl.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to create a row control file to be used in
                conjunction with an associated column control file to
                dynamically create study tables

  Macros Used:  %GETLABEL
                %GETFORMAT
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  DATA    = SAS data set containing the table analysis variables
  
  OUT     = Desired name for SAS dataset containing row control 
            information
  
  ROWVARS = Space-delimited list of row variables
  ----------------------------------------------------------------------*/
%macro rowcntl(data    = ,
               out     = ,
               rowvars = ,
               );

  %local _i _j _nrowvars _rowvar;

  %* Get the number of row variables ;
  %let _nrowvars = %sysfunc(countw(&rowvars));

  %* Loop through each row variable ;
  %do _i = 1 %to &_nrowvars;
      %let _rowvar = %scan(&rowvars,&_i);

      %* Get the non-missing count for this variable ;
      proc sql noprint;
           select count(&_rowvar) into :_count&_i trimmed from &data
           %if %getformat(var=&_rowvar, data=&data) = YESNO. 
               %then where &_rowvar in (0 1);;
           quit;

      %* Construct the initial control file data for this variable ;
      data _rowcntl&_i;
           rownum = &_i;
           rowvar = "&_rowvar";
           rowcnt = &&_count&_i;
           run;
  %end;

  %* Get the observation count for the full data set;
  proc sql noprint;
       select count(*) into :_allcnt from &data;
       quit;

  %* Combine the control information for all row variables ;
  data &out (drop = rowcnt);
       length data $ 50
              rownum 8
              rowvar rowfmt $ 32
              rowlbl $ 200
              rowstats $ 32
              neval $ 3
              ;
       set _rowcntl:;
       label data      = "Analysis Data Set"
             rownum    = "Row Number"
             rowvar    = "Row Variable"
             rowfmt    = "Row Format"
             rowlbl    = "Row Label"
             rowstats  = "Row Statistics"
             neval     = "N Evaluated Row"
             ;

       %* Define additional row information, using %GETFORMAT and 
          %GETLABEL macros to retrieve the row variable format and label 
          from the analysis data set ;
       data   = "&data";
       rowfmt = resolve(cats('%getformat(var=',rowvar,", data=",data,")"));
       rowlbl = resolve(cats('%getlabel(var=',rowvar,", data=",data,")"));

       %* Assign row type based on the variable format to determine the 
          type of analysis
         ---------------------------------------------------------------
          Continuous  = missing, COMMA, DOLLAR or BEST format
          Indicator   = YESNO format
          Categorical = all other formats
         ---------------------------------------------------------------;
       if upcase(rowfmt) in: ("" "COMMA" "DOLLAR" "BEST") 
          then rowstats = "Continuous";
       else if upcase(rowfmt) =: "YESNO" then rowstats = "Indicator";
       else rowstats = "Categorical";

       %* If the non-missing count for the variable is less than the 
          total count for the data set, then set the option to print 
          "N evaluated" row to "Yes";
       if rowcnt < &_allcnt then neval = "Yes";
       else neval = "No";

       run;

  proc sort data=&out;
       by rownum;
       run;

  %* Delete intermediate data sets ;
  proc datasets nolist;
       delete _rowcntl:;
       run;
       quit;

%mend rowcntl;

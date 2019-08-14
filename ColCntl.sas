/*----------------------------------------------------------------------
  Program:      ColCntl.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to create a column control file to be used in
                conjunction with an associated row control file to
                dynamically create study tables

  Macros Used:  %GETLABEL
                %GETFORMAT
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  DATA    = SAS data set containing the table analysis variables
  
  OUT     = Desired name for SAS dataset containing column control 
            information
  
  COLVARS = Space-delimited list of column variables
  
  PVARS   = Optional parameter for space-delimited list of column 
            variables for which P-values should be calculated, 
            or specify "all" for all column variables
  ----------------------------------------------------------------------*/
%macro colcntl(data    = ,
               out     = ,
               colvars = ,
               pvars   = ,
               );

  %local _i _j _ncolvars _npvars _colvar _pvar _pval _nvals;

  %* Get the number of column variables and number of variables where
     P-values  are requested ;
  %let _ncolvars = %sysfunc(countw(&colvars));
  %let _npvars   = %sysfunc(countw(&pvars));

  %* Loop through each column variable ;
  %do _i = 1 %to &_ncolvars;
      %let _colvar = %scan(&colvars,&_i);

      %* Get values of the column variable present in the data 
         and the sample size for each column;
      proc sql noprint;
           select distinct &_colvar format=8. into :_val1- from &data;
           select count(&_colvar) into :_n1- from &data
           group by &_colvar;
           %let _nvals = &sqlobs;
           quit;

      %* Determine whether P-value column is requested ;
      %* Initialize P-value indicator to zero ;
      %let _pval = 0;

      %* Only include P-value column if the variable has at least 2 
         values ;
      %if &_nvals > 1 %then %do;

          %* If the ALL option is given, then set the P-value indicator 
             to one ;
          %if %upcase(&pvars) = ALL %then %let _pval = 1;

          %* Otherwise search the PVARS parameter for this column 
             variable name ;
          %else %do;
              %let _j = 1;
              %do %until(_pval = 1 or &_j > &_npvars);
                  %let _pvar = %scan(&pvars,&_j);
                  %if &_colvar = &_pvar %then %let _pval = 1;
                  %let _j = %eval(&_j+1);
              %end;
          %end;

      %end;

      %* Construct the initial control file information for this variable ;
      data _colcntl&_i;
           length colvar $ 32;

           colvarnum = &_i;
           colvar = "&_colvar";

           %* Create a record for each value of the column variables ;
           %do _j = 1 %to &_nvals;
               colval = &&_val&_j;
               coln = &&_n&_j;
               output;
           %end;

           %* Create a record for P-value column if requested ; 
           %if &_pval %then %do;
               colval = .p;
               output;
           %end;

           run;
  %end;

  %* Combine the control information for all column variables ;
  data &out (drop = coln);
       length data $ 50
              colnum colvarnum colval 8
              colvar colfmt $ 32
              collbl colhdr $ 200
              ;

       set _colcntl:;

       label data      = "Analysis Data Set"
             colnum    = "Column Number"
             colvarnum = "Column Variable Number"
             colval    = "Column Variable Value"
             colvar    = "Column Variable"
             colfmt    = "Column Variable Format"
             collbl    = "Column Label"
             colhdr    = "Column Header"
             ;

       * Define additional column information, using %GETFORMAT and 
         %GETLABEL macros to retrieve the column variable format and 
         label from the analysis data set ;
       colnum + 1;
       data   = "&data";
       colfmt = resolve(cats('%getformat(var=',colvar,", data=",data,")"));
       colhdr = resolve(cats('%getlabel(var=',colvar,", data=",data,")"));
       if colval ne .p then collbl = cat(strip(putn(colval,colfmt)),
                                         "~N = ",
                                         strip(put(coln,comma20.)));
       else collbl = catx(" ","P-value for ",colhdr);

       run;

  proc sort data=&out;
       by colnum;
       run;

  %* Delete intermediate data sets ;
  proc datasets nolist;
       delete _colcntl:;
       run;
       quit;

%mend colcntl;


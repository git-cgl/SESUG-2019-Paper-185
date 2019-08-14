/*----------------------------------------------------------------------
  Program:      SESUG 185-2019 Demo.sas
  
  Platform:     SAS 9.4
  
  Description:  Prepares the SASHELP.HEART data set for table creation 
                by:
                 - Adding/modifying labels to match text in the table
                 - Converting character to numeric variables to preserve 
                   desired order in the output table
                 - Applying formats to variables with the same text as 
                   the table
                Demostrates use of the included macros to create an Excel
                table based on the modified version of SASHELP.HEART

  Macros Used:  %GETLABEL
                %COLCNTL
                %ROWCNTL
                %MKTABLE_V1
                %MKTABLE_V2
                %ADDLABEL
                %MKREPORT

  Input:        SASHELP.HEART
  
  Output:       SESUG 185-2019 Demo Table.XLSX
  ----------------------------------------------------------------------*/
%let projloc = C:\Users\Mercalk\Documents\My SAS Files\Katie Mercaldi\Projects\SESUG 2019 Paper 185;
%let fmtloc = &projloc\SASFormats;
%let macloc = &projloc\SASMacros;
%let rptloc = &projloc\Reports;

libname projfmt "&fmtloc";
filename mac "&macloc";
filename xltables "&rptloc\SESUG 185-2019 Demo Table.xlsx";

options msglevel = i nodate minoperator mprint mautosource 
        sasautos = ("." mac sasautos) fmtsearch = (projfmt work);


*** Formats needed for table creation ***;
proc format library = projfmt;
  value allpt  1 = "All Patients"
               ;
  value yesno  1 = "Yes"
               0 = "No"
               9 = "Unknown"
               ;
  value status 0 = "Dead"
               1 = "Alive"
               9 = "Unknown"
               ;
  value gender 1 = "Male"
               2 = "Female"
               9 = "Unknown"
               ;
  value chol   1 = "Desirable"
               2 = "Borderline"
               3 = "High"
               9 = "Unknown"
               ;
  * Format for P-values ;
  picture pvalfmt (round)
             . = ""
             low-<0.0001 = "<0.0001" (noedit)
             0.0001-<0.000995 = "9.9999"
             0.000995-<0.00995 = "9.999"
             0.00995-<0.995 = "9.99"
             0.995-1.0 = "1.00" (noedit)
             ;
  * Percentage formats that automatically assigns decimal places ;
  picture autopct (round)
             . = ""
          low      - -99.95  = "0,000,000,000,000,009%" (prefix='-')
          -99.95<  -  -0.095 = "09.9%" (prefix='-')
           -0.095< -  -0.01  = "9.99%" (prefix='-')
           -0.01<  -  <0     = "-<0.01%" (noedit)
            0                = "0%" (noedit)
            0<     -  <0.01  = "<0.01%" (noedit)
            0.01   -  <0.095 = "9.99%"
            0.095  - <99.95  = "09.9%" 
           99.95   - high     = "0,000,000,000,000,009%" (mult=1)
             ;
  * Decimal format that automatically assigns significant figures ;
  picture autodec (round)
             . = ""
          low        - -99.95    = "0,000,000,000,000,009" (prefix='-')
          -99.95<    -  -0.095   = "09.9" (prefix='-')
           -0.095<   -  -0.0095  = "9.99" (prefix='-')
           -0.0095<  -  -0.00095 = "9.999" (prefix='-')
           -0.00095< -  -0.0001  = "9.9999" (prefix='-')
           -0.0001<  -  <0       = "-<0.0001" (noedit)
            0                    = "0" (noedit)
            0<       -  <0.0001  = "<0.0001" (noedit)
            0.0001   -  <0.00095 = "9.9999"
            0.00095  -  <0.0095  = "9.999"
            0.0095   -  <0.095   = "9.99"
            0.095    - <99.95    = "09.9"
           99.95     - high      = "0,000,000,000,000,009"
             ;
  run;


*** Prepare the analytic data set ***;

* Reformat the SASHELP Framingham Heart Study data set to work with table
  creation macros ;
data heart;
  set sashelp.heart;

  * Add or relabel variables with text desired in the final table ;
  label  allpt        = "All Patients"
         nstatus      = "Patient Status"
         gender       = "Gender"
         cholesterol  = "Cholesterol, mg/dL"
         nchol_status = "%getlabel(var=chol_status, data=sashelp.heart)"
         abn_chol     = "Abnormal Cholesterol"
         ;

  * Apply formats with table text to the numeric categorical variables ;
  format allpt        allpt.
         nstatus      status.
         gender       gender.
         nchol_status chol.
         abn_chol     yesno.
         ;

  * Variable for "All Patients" column ;
  allpt = 1;

  *** Recode existing character variables in the table as numeric ***;

  * Patient status is used as a column stratification variable ;
  nstatus = sum(0*(status = "Dead"),
                1*(status = "Alive"),
                9*(status = "")
                );

  * Categorical row variables ;
  gender = sum(1*(sex = "Male"),
               2*(sex = "Female"),
               9*(sex = "")
               );

  nchol_status = sum(1*(chol_status = "Desirable"),
                     2*(chol_status = "Borderline"),
                     3*(chol_status = "High"),
                     9*(chol_status = "")
                     );

  * Create an indicator variable for abnormal cholesterol ;
  abn_chol = sum(1*(nchol_status = 3),
                 9*(nchol_status = 9)
                 );
  run;


*** Create the control files for the table ***;

* Run the macro to create the column control file
 -------------------------------------------------------------------
  DATA    = Name of the analytic data set
  OUT     = Desired name for the column control data set
  COLVARS = Space-delimited list of column variable names
  PVARS   = Space-delimited list of variables for statistical tests
            (optional)
 -------------------------------------------------------------------;
%colcntl(data    = heart,
         out     = colcntl,
         colvars = allpt nstatus,
         pvars   = nstatus
         );

* Modify the column control file as desired ;
data t01_colcntl;
     set colcntl;

     * Change column header for "All Patients" column ;
     if colvar = "allpt" then colhdr = "Overall";

     * Swap order for patient status values ;
     if collbl =: "Alive" then colnum = 2;
     else if collbl =: "Dead" then colnum = 3;

     run;

proc sort data=t01_colcntl;
     by colnum;
     run;

proc print data=t01_colcntl noobs label;
     run;

* Run the macro to create the row control file
 --------------------------------------------------------
  DATA    = Name of the analytic data set
  OUT     = Desired name for the column control data set
  ROWVARS = Space-delimited list of row variable names
 --------------------------------------------------------;
%rowcntl(data    = heart,
         out     = rowcntl,
         rowvars = agechddiag gender cholesterol nchol_status abn_chol 
         );

* Modify the row control file as needed ;
data t01_rowcntl;
     set rowcntl;
     if upcase(rowvar) = "AGECHDDIAG" then rowlbl = cats(rowlbl,", years");
     run;

proc print data=t01_rowcntl noobs label;
     run;


 *** Make the table specified by the control files ***;

* Create the table
 --------------------------------------------------------------------------
  OUT     = Desired name for the output data set containing the table text
  COLCNTL = Name of the column control data set
  ROWCNTL = Name of the row control data set
 --------------------------------------------------------------------------;

* Using CALL EXECUTE ;
* %MKTABLE_V1 only works with access to %CONTSTATS, %CATSTATS, and %FLAGSTATS
   which are not included in this paper, so this code is commented out:
%mktable_v1(out     = t01_v1,
            colcntl = t01_colcntl,
            rowcntl = t01_rowcntl
            );

* Using PROC TABULATE ;
%mktable_v2(out     = t01_v2,
            colcntl = t01_colcntl,
            rowcntl = t01_rowcntl
            );

* Add custom row label 
-----------------------------------------------------------------------
  DATA     = Name of the data set containing the table text
  OUT      = Desired name for the output table data set (optional, uses 
             DATA parameter if missing)
  ROWCNTL  = Name of the row control data set
  LABEL    = Label text
  STARTVAR = First row variable name under the new label
  STOPVAR  = Last row variable name under the new label (optional, only 
             applies to the START parameter if missing)
 -----------------------------------------------------------------------;
%addlabel(data     = t01_v2,
          out      = t01,
          rowcntl  = t01_rowcntl,
          label    = Cholesterol Measurements,
          startvar = cholesterol,
          stopvar  = abn_chol
          );


*** Print the table in an Excel workbook ***;

ods escapechar = "^";
ods listing close;

ods excel file = xltables 
    options(fittopage = 'no'
            embedded_titles = 'yes'
            embedded_footnotes = 'yes'
            flow = 'tables'
            zoom = '100'
            orientation='Landscape'
            row_repeat = 'header'
            pages_fitheight = '100'
            center_horizontal = 'yes'
            center_vertical = 'no'
            frozen_headers = "yes"
            frozen_rowheaders = "1"
            );

* Print the table with PROC REPORT
 -----------------------------------------------------------------------
  DATA    = Name of the data set containing the table text
  COLCNTL = Name of the column control data set
  SHEET   = Desired Excel sheet name
  ROWHDR  = Header text for the row label column (default is "Measure")
  BOLDROW = Row label levels to bold ("all" for all, 1 for top level 
            labels, 2 for top and second level labels and so on)
 -----------------------------------------------------------------------;
title1 "SESUG 185-2019 Demo Table";
footnote1 "Results are based on a modified version of the SASHELP.HEART data set";
%mkreport(data    = t01, 
          colcntl = t01_colcntl, 
          sheet   = Table 1, 
          boldrow = 1
          );

ods excel close;
ods listing;

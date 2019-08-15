/*----------------------------------------------------------------------
  Program:      MkReport.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to generate PROC REPORT syntax for printing
                study tables in an Excel workbook
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  DATA    = Name of the data set containing the table text
  
  COLCTNL = Name of column control file for the table to get column
            header information
  
  SHEET   = Excel worksheet name for the table
  
  ROWHDR  = Header text for the row label column (default = "Measure")
  
  BOLDROW = Indentation level for bold row labels. Default is all row
            labels are bolded ("all"). Use integers (1, 2, 3...) to
            change which labels are bolded.
  ----------------------------------------------------------------------*/
%macro mkreport(data    = ,
                colcntl = ,
                sheet   = ,
                rowhdr  = Measure,
                boldrow = all
                );

  %local _i _colnames _coldefs _ncol _col _rlen _slen _plen;

  %* Replace >= and <= with unicode characters in the row label column ;
  data _temp;
       set &data;
       rowlabel = tranwrd(rowlabel,"<=","^{unicode '2264'x}");
       rowlabel = tranwrd(rowlabel,">=","^{unicode '2265'x}");
       run;

  %* Get names of columns included in the final table ;
  proc contents data=&data (keep=col:) out=_colnames (keep=name) noprint;
       run;

  proc sql noprint;
       select quote(upcase(name)) into :_colnames separated by " " 
       from _colnames;
       quit;

  %* Get column information from the column control file ;
  data _null_;
       set &colcntl (where = (cats("COL",colnum) in (&_colnames))) end = eof;
       by colvarnum colhdr;
       length coldef $ 1000;
       retain coldef;

       %* Identify P-value columns ;
       call symputx(cats("_colval",colnum),colval);

       %* Build the REPORT column definition from the column header text and
          column variable names ;
       if first.colhdr then do;
          coldef = strip(cat(strip(coldef)," (",
                             quote(strip(colhdr))," (",
                             cats("col",colnum)));
          if last.colhdr then coldef = cats(coldef,"))");
       end;
       else if last.colhdr 
          then coldef = cat(strip(coldef)," ",cats("col",colnum),"))");
       else coldef = cat(strip(coldef)," ",cats("col",colnum));

       %* Put the column definitions into a macro variable to insert
          in the PROC REPORT syntax ;
       if eof then do;
          call symputx("_coldefs",coldef);
          call symputx("_ncol",colnum);
       end;

       run;

  %* Determine column lengths based on the table data ;
  data _collength;
       set _temp;
       array col{&_ncol} $ col:;

       %* Row label character length ;
       rlen = length(rowlabel);

       %* Text may wrap >90 characters so use 0 to "autofit" row height which
          may need some adjustment in Excel--otherwise set row height to 15 ;
       if rlen > 90 then call symputx("_rowht","0");
       else call symputx("_rowht","15");

       %* Statistic and P-value column character lengths ;
       do i = 1 to &_ncol;
          if symget(cats("_colval",i)) = "P" 
             then plen = max(length(col{i}),plen);
          else slen = max(length(col{i}),slen);
       end;

       run;

  %* Get maximum column length for row label, stats and P-value columns ;
  proc sql noprint;
       select min(max(rlen),90), max(max(slen),10), max(max(plen),10)
       into :_rlen trimmed, :_slen trimmed, :_plen trimmed
       from _collength;
       quit;

  %* Set the sheet name, row height and title/footnote width ;
  ods excel options(sheet_name = "&sheet"
                    row_heights = "0,&_rowht,0,0,0,0,0"
                    title_footnote_width = "%eval(&_ncol+1)"
                    );

  %* Create the table report ;
  proc report data = _temp nowindows split = "~" missing
              style(header) = {font_weight = bold 
                               font_size   = 10pt 
                               just        = center 
                               vjust       = m
                               protectspecialchars = off
                               }
              style(column) = {font_size = 10pt 
                               just      = center 
                               vjust     = m
                               };
       column rownum rowlabel &_coldefs c;
          
       %* Column definitions ;
       define rownum   / order noprint;
       define rowlabel / display "&rowhdr" 
                         style(column) = {cellwidth = &_rlen.em 
                                          just      = left
                                          };
       %* Assign width for each data column as calculated above ;
       %do _i = 1 %to &_ncol;
           %if &&_colval&_i = P %then %let _len = &_plen;
           %else %let _len = &_slen;
           define col&_i / display style = {cellwidth = &_len.em};
       %end;
       define c / noprint;

       compute c;
       %* Bold row labels at the requested level ;
       %if %upcase(&boldrow) = ALL or &boldrow > 0 %then %do;
           if col1 = "" 
           %if %upcase(&boldrow) ne ALL %then %do;
              and index(rowlabel, 
                        %do _i = 1 %to &boldrow;
                            'A0A0A0A0'x %if &_i ne &boldrow %then ||;
                        %end;
                        ) ne 1
           %end;
           then call define(_row_,"style","style = [font_weight = bold]");
       %end;
       endcomp;
        
       run;

  %* Delete intermediate data sets ;
  proc datasets nolist;
       delete _temp
              _colnames
              _collength
              ;
       run;
       quit;

%mend mkreport;

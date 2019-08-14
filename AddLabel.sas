/*----------------------------------------------------------------------
  Program:      AddLabel.sas
  
  Platform:     SAS 9.4
  
  Description:  Macro to add row labels to existing table data sets
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  DATA     = Name of the data set containing the table text
  
  OUT      = Optional name for the output data -- If blank then the DATA 
             parameter will be used
  
  LABEL    = New row label text
  
  STARTVAR = The table row variable name above which the label will be 
             placed
  
  STOPVAR  = The last row variable where the added label applies for
             adjusting indentation -- If blank, only the STARTROW will
             be adjusted
  ----------------------------------------------------------------------*/
%macro addlabel(data     = ,
                out      = ,
                rowcntl  = ,
                label    = ,
                startvar = ,
                stopvar  = 
                );

       %* If no output data set name is given, use the original data set 
          name ;
       %if not %length(&out) %then %let out = &data;
       %if not %length(&stopvar) %then %let stopvar = &startvar;

       %* Get the row numbers associated with the starting and ending
          row variables for which the label applies ;
       proc sql noprint;
            select rownum into :startnum trimmed from &rowcntl 
            where rowvar = "&startvar";
            select rownum into :stopnum trimmed from &rowcntl 
            where rowvar = "&stopvar";
            quit;

       %* Assign special missing characters to order labels ;
       data _null_;
            set &data (keep = rownum statnum where = (rownum = &startnum));
            by rownum statnum;
            if first.rownum;

            %* Determine the first statistic value for the row -- If a 
               label already exists then set the special missing character 
               to one letter before ;
            statchar = strip(lowcase(put(statnum,4.)));
            if anyalpha(statchar) then 
               call symputx("statnum",cats(".",byte(rank(statchar)-1)));

            %* Otherwise use .L to represent the label ;
            else call symputx("statnum",".l");

            run;

       %* Add the label to the table ;
       data &out (drop = i);
            set &data;
            by rownum statnum;
            array col $ col: pval:;

            %* Increase the indentation by one for all rows included
               under the new label ;
            if &startnum <= rownum <= &stopnum then 
               rowlabel = cat('A0A0A0A0'x,strip(rowlabel));
            output;

            %* Create the new label based on the first observation for 
               the row and output ;
            if first.rownum and rownum = &startnum then do;
               statnum = &statnum;
               rowlabel = "&label";
               do i = 1 to dim(col);
                  col{i} = "";
               end;
               output;
            end;
            run;

       proc sort data=&out;
            by rownum statnum;
            run;

%mend addlabel;

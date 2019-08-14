/*----------------------------------------------------------------------
  Program:      GetLabel.sas
  
  Platform:     SAS 9.4
  
  Description:  Returns the label of a variable in a given data set
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  VAR     = Variable name for retrieving format
  
  DATA    = Data set name containing VAR
  ----------------------------------------------------------------------*/
%macro getlabel(var=, data=);

       %let dsid = %sysfunc(open(&data,i));
       %let varnum = %sysfunc(varnum(&dsid,&var));
       %if &varnum > 0 %then %qsysfunc(varlabel(&dsid,&varnum));
       %let rc = %sysfunc(close(&dsid));

%mend getlabel;


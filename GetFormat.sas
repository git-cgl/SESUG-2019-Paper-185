/*----------------------------------------------------------------------
  Program:      GetFormat.sas
  
  Platform:     SAS 9.4
  
  Description:  Returns the format of a variable in a given data set
  ----------------------------------------------------------------------
  Parameter Definitions:
  ----------------------------------------------------------------------
  VAR     = Variable name for retrieving format
  
  DATA    = Data set name containing VAR
  ----------------------------------------------------------------------*/
%macro getformat(var=, data=);

       %let dsid = %sysfunc(open(&data,i));
       %let varnum = %sysfunc(varnum(&dsid,&var));
       %if &varnum > 0 %then %qsysfunc(varfmt(&dsid,&varnum));
       %let rc = %sysfunc(close(&dsid));

%mend getformat;


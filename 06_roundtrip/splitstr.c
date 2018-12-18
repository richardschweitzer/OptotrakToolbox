/* splitstr.c: MEX file that splits a string based an arbitrary character
 *
 * C = SPLITSTR(S) splits the string S at newlines and returns a cell
 * array where each element is a word.
 *
 * C = SPLITSTR(S, DELIM) uses the character DELIM as the delimiter.
 * The strings '\n' and '\t' can be used to represent newline and tab
 * characters, respectively.
 *
 * Peter Boettcher <boettcher@ll.mit.edu>
 * Copyright 2002
 * Last modified: <Tue Jul 30 11:32:13 2002 by pwb>
 */

#include "mex.h"

void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[])
{
  int numlines, line;
  int len, i;
  char *buf;
  char **strarray;
  char delimiter = '\n';
  char delimbuf[10];

  if(nrhs < 1) 
    mexErrMsgTxt("One input required.");  
  
  if(!mxIsChar(prhs[0]))
    mexErrMsgTxt("First argument must be character array");

  if(nrhs > 1) {
    if(!mxIsChar(prhs[1]))
      mexErrMsgTxt("Optional second argument must be a character");
    mxGetString(prhs[1], delimbuf, 10);
    if(delimbuf[0] == '\\') {
      if(mxGetNumberOfElements(prhs[1]) != 2)
	mexErrMsgTxt("Must be a single character or \\n or \\t");
      switch(delimbuf[1]) {
      case 'n':
	delimiter = '\n';
	break;
      case 't':
	delimiter = '\t';
	break;
      default:
	mexErrMsgTxt("Unknown escape character");
      }
    } else {
      if(mxGetNumberOfElements(prhs[1]) != 1)
	mexErrMsgTxt("Must be a single character or \\n or \\t");
      delimiter = delimbuf[0];
    }
  }
  
  len = mxGetNumberOfElements(prhs[0]);
  buf = mxMalloc(sizeof(char) * (len+1));
  mxGetString(prhs[0], buf, len+1);

  numlines = 1;
  for(i=0; i<len; i++)
    numlines += (buf[i] == delimiter);
  
  line = 0;
  strarray = mxMalloc(sizeof(char *) * numlines);
  strarray[line++] = buf;
  for(i=0; i<len; i++) {
    if(buf[i] == delimiter) {
      buf[i] = '\0';
      strarray[line++] = &buf[i+1];
    }
  }
  
  plhs[0] = mxCreateCellMatrix(numlines, 1);
  for(line = 0; line < numlines; line++)
    mxSetCell(plhs[0], line, mxCreateString(strarray[line]));

  mxFree(strarray);
  mxFree(buf);
}

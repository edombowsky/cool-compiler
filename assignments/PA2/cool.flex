/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

/* DECLARATIONS
 * ======================================================================== */

/* Given
 * ------------------------------------------------------------------------ */

/* to assemble string constants */
char string_buf[MAX_STR_CONST];
char *string_buf_ptr;
extern int curr_lineno;
extern int verbose_flag;
extern YYSTYPE cool_yylval;

/* Custom
 * ------------------------------------------------------------------------ */

/* ensures that we properly handle nested comments */
int comment_depth = 0;

/* ensures that we do not go over Cool's 1024 char limit */ 
int string_length;

/* forward declarations */
bool strTooLong();
void resetStr();
void setErrMsg(char* msg);
void exitStrState(char* msg);
int strLenErr();
void addToStr(char* str);

%}

/* DEFINITIONS
 * ======================================================================== */

/* State declarations, which are syntactic sugar for global variables that
 * keep track of state.
 */
%x COMMENT
%x S_LINE_COMMENT
%x STRING
%x STRING_ERR

NUMBER          [0-9]
ALPHANUMERIC    [a-zA-Z0-9_]
TYPEID          [A-Z]{ALPHANUMERIC}*
OBJECTID        [a-z]{ALPHANUMERIC}*
DARROW          =>
LE              <=
ASSIGN          <-
%%

 /* RULES
  * flex.sourceforge.net/manual/Patterns.html
  * ======================================================================== */

 /* Comments
  * ------------------------------------------------------------------------ */

"(*"                {
                        comment_depth++;
                        BEGIN(COMMENT);
                    }
<COMMENT>"(*"       {   comment_depth++; }
<COMMENT>.          {}
<COMMENT>\n         {   curr_lineno++; }
<COMMENT>"*)"       {
                        comment_depth--;
                        if (comment_depth == 0) {
                            BEGIN(INITIAL);
                        }
                    }
<COMMENT><<EOF>>    {
                        setErrMsg("EOF in comment");
                        BEGIN(INITIAL);
                        return ERROR;
	                }
"*)"                {
                        setErrMsg("Unmatched *)");
                        BEGIN(INITIAL);
                        return ERROR;
	                }
"--"                {   BEGIN(S_LINE_COMMENT); }
<S_LINE_COMMENT>.   {}
<S_LINE_COMMENT>\n  {
                        curr_lineno++;
                        BEGIN(INITIAL);
                    }

 /* Numbers and operators
  * ------------------------------------------------------------------------ */

{NUMBER}+       {
                    cool_yylval.symbol = inttable.add_string(yytext);
                    return INT_CONST;
	            }
{DARROW}		{   return DARROW; }
{LE}            {   return LE; }
{ASSIGN}        {   return ASSIGN; }
"+"             {   return '+'; }
"/"             {   return '/'; }
"-"             {   return '-'; }
"*"             {   return '*'; }
"="             {   return '='; }
"<"             {   return '<'; }
"."             {   return '.'; }
"~"             {   return '~'; }
","             {   return ','; }
";"             {   return ';'; }
":"             {   return ':'; }
"("             {   return '('; }
")"             {   return ')'; }
"@"             {   return '@'; }
"{"             {   return '{'; }
"}"             {   return '}'; }


 /* Keywords
  * 
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  * ------------------------------------------------------------------------ */

(?i:class)      {   return (CLASS); }
(?i:else)       {   return (ELSE); }
(?i:fi)         {   return (FI); }
(?i:if)         {   return (IF); }
(?i:in)         {   return (IN); }
(?i:inherits)   {   return (INHERITS); }
(?i:let)        {   return (LET); }
(?i:loop)       {   return (LOOP); }
(?i:pool)       {   return (POOL); }
(?i:then)       {   return (THEN); }
(?i:while)      {   return (WHILE); }
(?i:case)       {   return (CASE); }
(?i:esac)       {   return (ESAC); }
(?i:of)         {   return (OF); }
(?i:new)        {   return (NEW); }
(?i:not)        {   return (NOT); }
(?i:isvoid)     {   return (ISVOID); }


 /* "For boolean constants, the semantic value is stored in the field
  * `cool_yylval.boolean`. */
t(?i:rue)       {   
	                cool_yylval.boolean = true;
	                return (BOOL_CONST);
	            }
f(?i:alse)      {   
	                cool_yylval.boolean = false;
	                return (BOOL_CONST);
	            }


 /* Identifiers
  * ------------------------------------------------------------------------ */
{TYPEID}        {
                    cool_yylval.symbol = stringtable.add_string(yytext);
                    return (TYPEID);
	            }
{OBJECTID}      {
                    cool_yylval.symbol = stringtable.add_string(yytext);
                    return (OBJECTID);
	            }


 /* String constants (C syntax)
  * Escape sequence \c is accepted for all characters c. Except for 
  * \n \t \b \f, the result is c.
  * ------------------------------------------------------------------------ */

\"              {
                    BEGIN(STRING);
                    string_length = 0;
	            }
<STRING>\"      {
                    cool_yylval.symbol = stringtable.add_string(string_buf);
                    resetStr();
                    BEGIN(INITIAL);
                    return (STR_CONST);
	            }
<STRING>\0      {
                    setErrMsg("String contains null character");
                    resetStr();
                    BEGIN(STRING_ERR);
                    return ERROR;
	            }
<STRING>\\\0    {
                    setErrMsg("String contains escaped null character.");
                    resetStr();
                    BEGIN(STRING_ERR);
                    return ERROR;
	            }
<STRING>\n      {
                    setErrMsg("Unterminated string constant");
                    resetStr();

                    /* Begin lexing at the next line */
                    curr_lineno++;
                    BEGIN(INITIAL);
                    return ERROR;
	            }
  /* this is an escaped backslash '\' followed by an 'n'*/
<STRING>\\n     {
	                /* Manually change check to handle when we are adding two to string */
                    if (string_length + 2 >= MAX_STR_CONST) { return strLenErr(); }
                    string_length = string_length + 2;
                    addToStr("\n");
	            }
 /* this is an escaped newline character  */
<STRING>\\\n    {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    curr_lineno++;
                    addToStr("\n");
                }
<STRING>\\t     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\t");
                }
<STRING>\\b     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\b");
	            }
<STRING>\\f     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr("\f");
	            }

 /* All other escaped characters should just return the character. */
<STRING>\\.     {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr(&strdup(yytext)[1]);
	            }
<STRING><<EOF>> {
	                setErrMsg("EOF in string constant");
	                curr_lineno++;
                    BEGIN(INITIAL);
                    return ERROR;
	            }
<STRING>.       {
                    if (strTooLong()) { return strLenErr(); }
                    string_length++;
                    addToStr(yytext);
	            }

<STRING_ERR>\"  {
                    BEGIN(INITIAL);
	            }
<STRING_ERR>\n  {
	                curr_lineno++;
                    BEGIN(INITIAL);
	            }
<STRING_ERR>.   {}

 /* eat up everything else
  * ------------------------------------------------------------------------ */

\n              {   curr_lineno++; }
 /* Note this is *not* the same list of whitespace chars that can be escaped
  * in a string */
[ \f\r\t\v]     {}
.               {   
	                setErrMsg(yytext);
                    return ERROR;
                }

%%


 /* USER SUBROUTINES
  * ======================================================================== */

bool strTooLong() {
	if (string_length + 1 >= MAX_STR_CONST) {
		BEGIN(STRING_ERR);
        return true;
    }
    return false;
}

void resetStr() {
    string_buf[0] = '\0';
}

void setErrMsg(char* msg) {
    cool_yylval.error_msg = msg;
}

int strLenErr() {
	resetStr();
    setErrMsg("String constant too long");
    return ERROR;
}

void addToStr(char* str) {
    strcat(string_buf, str);
}

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

/* to assembl string constants */
char string_buf[MAX_STR_CONST];

/* I think this is to find the last position in the array */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/* DECLARATIONS
 * ======================================================================== */

/* `comment_depth` ensures that we properly handle nested comments */
int comment_depth = 0;

/* `string_length` ensures that we do not go over Cool's 1024 char limit 
 * I think we can just compare this to MAX_STR_CONST */
int string_length;


%}

/* DEFINITIONS
 * ======================================================================== */

/* State declarations, which are syntactic sugar for a global variable that
 * keeps track of the state.
 */
%x COMMENT
%x S_LINE_COMMENT
%x STRING

NUMBER          [0-9]
ALPHANUMERIC    [a-zA-Z0-9_]

DARROW          =>
LE              <=
ASSIGN          <-

/* space, backspace, tab, newline, formfeed */
WHITESPACE      [ \t]

TYPEID          [A-Z]{ALPHANUMERIC}*
OBJECTID        [a-z]{ALPHANUMERIC}*

%%

 /* RULES
  *
  * TODO:
  * COMMENT - EOF
  * S_LINE_COMMENT - EOF
  * NOT
  * ISVOID
  *
  * TONO:
  * Why () around DARROW?
  * When do we use a string table?
  * Why use inttable rather than string table?
  * ======================================================================== */

 /*
  * Comments
  * ------------------------------------------------------------------------ */

"(*"                {
	                    /* `BEGIN` changes the global state variable. Now we can
	                     * predicate on the COMMMENT rule.
	                     */
                        comment_depth++;
                        BEGIN(COMMENT);
                    }
<COMMENT>.          {   /* eat everything but newline */ }
<COMMENT>\n         {   curr_lineno++; }
<COMMENT>"*)"       {
                        comment_depth--;
                        if (comment_depth == 0) {
                            BEGIN(INITIAL);
                        }
                    }
<COMMENT><<EOF>>    {
                        BEGIN(INITIAL);
                        cool_yylval.error_msg = "EOF in comment";
                        return (ERROR);
	                }
"*)"                {
                        BEGIN(INITIAL);
                        cool_yylval.error_msg = "Unmatched *)";
                        return (ERROR);
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
	                /* From the Flex manual:
	                 * "yytext points to the first character of the match in the input buffer."
	                 *
	                 * From the PA1 assignment PDF:
	                 * "To save space and time, a common compiler practice is to store lexemes in a string table."
	                 * This line of that when we encounter a character that matches the regular expression [0-9],
	                 * we add that character (yytext), to the inttable as a string. This ensure that every integer
	                 * is only added once.
	                 */
                    cool_yylval.symbol = inttable.add_string(yytext);

                    /* See ./utilities.cc for a list of constants you can return.
                     */
                    return INT_CONST;
	            }

{DARROW}		{   return (DARROW); }
{LE}            {   return (LE); }
{ASSIGN}        {   return (ASSIGN); }

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
  *
  * Flex documentation on patterns:
  * flex.sourceforge.net/manual/Patterns.html
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

 /* "For boolean constants, the semantic value is stored in the field
  * `cool_yylval.boolean`.
  */
t(?i:rue)       {   
	                cool_yylval.boolean = true;
	                return (BOOL_CONST);
	            }
f(?i:false)     {   
	                cool_yylval.boolean = false;
	                return (BOOL_CONST);
	            }


 /* Identifiers
  * TONO: Do we need to check if each identifier is in the string table first?
  * ------------------------------------------------------------------------ */
{TYPEID}        {
                    cool_yylval.symbol = inttable.add_string(yytext);
                    return (TYPEID);
	            }
{OBJECTID}      {
                    cool_yylval.symbol = inttable.add_string(yytext);
                    return (OBJECTID);
	            }


 /* String constants (C syntax)
  * Escape sequence \c is accepted for all characters c. Except for 
  * \n \t \b \f, the result is c.
  *
  * TODO: Handle errors
  * ------------------------------------------------------------------------ */

\"              {
                    BEGIN(STRING);
                    /* char string_buf[MAX_STR_CONST]; */
                    /* char *string_buf_ptr; */
                    string_length = 0;
	            }
<STRING>\"      {
                    BEGIN(INITIAL);
                    cool_yylval.symbol = inttable.add_string(string_buf);
                    string_buf[0] = '\0';
                    return (STR_CONST);
	            }
<STRING>\0      {
                    BEGIN(INITIAL);
                    cool_yylval.error_msg = "String contains null character";
                    string_buf[0] = '\0';
                    return (ERROR);
	            }
<STRING>\n      {
                    BEGIN(INITIAL);
                    cool_yylval.error_msg = "Unterminated string constant";
                    /* Do not stop lexing */
                    return (ERROR);
	            }
<STRING>\\n     {
                    string_length = string_length + 2;
                    if (string_length >= MAX_STR_CONST) {
                        string_buf[0] = '\0';
                        cool_yylval.error_msg = "String constant too long";
                        return (ERROR);
                    } else {
                        strcat(string_buf, "\n");
                    }
	            }
<STRING>\\t     {
                    string_length = string_length + 2;
                    if (string_length >= MAX_STR_CONST) {
                        string_buf[0] = '\0';
                        cool_yylval.error_msg = "String constant too long";
                        return (ERROR);
                    } else {
                        strcat(string_buf, "\t");
                    }
	            }
<STRING>\\b     {
                    string_length = string_length + 2;
                    if (string_length >= MAX_STR_CONST) {
                        string_buf[0] = '\0';
                        cool_yylval.error_msg = "String constant too long";
                        return (ERROR);
                    } else {
                        strcat(string_buf, "\b");
                    }
	            }
<STRING>\\f     {
                    string_length = string_length + 2;
                    if (string_length >= MAX_STR_CONST) {
                        string_buf[0] = '\0';
                        cool_yylval.error_msg = "String constant too long";
                        return (ERROR);
                    } else {
                        strcat(string_buf, "\f");
                    }
	            }
<STRING>.       {
                    string_length += 1;
                    if (string_length >= MAX_STR_CONST) {
                    	/* TODO: Not sure this actually works */
                        string_buf[0] = '\0';
                        cool_yylval.error_msg = "String constant too long";
                        return (ERROR);
                    } else {
                        /* www.cplusplus.com/reference/cstring/strcat/ */
                        strcat(string_buf, yytext);
                    }
	            }


 /* eat up everything else
  * ------------------------------------------------------------------------ */

\n              {   curr_lineno++; }
[ \t]           {}
.               {   
	                cool_yylval.error_msg = yytext;
                    return (ERROR);
                }

%%


 /* USER SUBROUTINES
  * ======================================================================== */


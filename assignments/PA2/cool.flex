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

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/* DECLARATIONS
 *
 * "Add Your own definitions here"
 * ======================================================================== */

/* `comment_depth` ensures we do not leave the COMMENT state too early,
 * i.e. that we properly handle nested comments.
 */
int comment_depth = 0;

%}

/* DEFINITIONS
 *
 * Define names for regular expressions here.
 * e.g. DIGIT  [0-9]
 * ======================================================================== */

/* State declarations, which are syntactic sugar for a global variable that
 * keeps track of the state.
 */
%Start COMMENT
%Start S_LINE_COMMENT

DARROW          =>
ASSIGN          <-
DIGIT           [0-9]

%%

 /* THE RULES
  *
  * "A rule in Flex specifies an action to perform if the input matches the
  * regular expression or definition at the beginning of the rule. The action
  * to perform is specified by writing regular C source code.
  *
  * The value of the input is stored in the global variable
  * `cool_yylval.symbol`. The block of code returns the appropriate token code.
  *
  * e.g.
  * // {DIGIT} is a regular expression, defined in the DEFINITIONS section.
  * {DIGIT} {
  *   // `cool_yylval.symbol` stores the value of the input character.
  *   // We add it to the inttable using `yytext`, which is the next character
  *   // read into the lexer. The int table returns the value added to it. 
  *   cool_yylval.symbol = inttable.add_string(yytext);
  *
  *   // We return `DIGIT_TOKEN`, the token code. A list of token codes can be
  *   // found in utilities.cc
  *   return DIGIT_TOKEN;
  * }
  * 
  * A few additional notes:
  * Note 1: Flex throws an error when these comment blocks are not proceeded by white space.
  * Note 2: Flex throws an error when you explicitly provide the initial state, i.e. "<INITIAL>".
  * Note 3: Flex throws an error when any rule is proceeded by whitespace.
  * ======================================================================== */


 /*
  * Comments
  * ------------------------------------------------------------------------ */

"(*"            {
	                /* `BEGIN` changes the global state variable. Now we can
	                 * predicate on the COMMMENT rule.
	                 */
	                comment_depth++;
	                BEGIN(COMMENT);
	            }
<COMMENT>"*)"   {
                    comment_depth--;
                    if (comment_depth == 0) {
                        BEGIN(INITIAL);
                    }
	            }

 /* Handling unmatched "*)" input
  */
"\*)"           {
                    cool_yylval.error_msg = "Unmatched *)";
                    return ERROR;
	            }
"--"            {
                    BEGIN(S_LINE_COMMENT);
	            }
<S_LINE_COMMENT>.     {}
<S_LINE_COMMENT>\n    {
                    BEGIN(INITIAL);
                }
 /* TODO: <S_LINE>COMENT><<EOF>> */


 /* Miscellaneous
  * ------------------------------------------------------------------------ */

\n              {   curr_lineno++; }
{DIGIT}+        {
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
 

 /* The multiple-character operators.
  * ------------------------------------------------------------------------ */

{DARROW}		{   return DARROW; }
{ASSIGN}        {   return ASSIGN; }


 /* Keywords
  * 
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  *
  * Flex documentation on patterns:
  * flex.sourceforge.net/manual/Patterns.html
  *
  * We do not have to add them to a string table because they are constants to
  * the compiler. A string table is for things like identifiers.
  * ------------------------------------------------------------------------ */

(?i:class)      {   return CLASS; }
(?i:else)       {   return ELSE; }
(?i:fi)         {   return FI; }
(?i:if)         {   return IF; }
(?i:in)         {   return IN; }
(?i:inherits)   {   return INHERITS; }
(?i:let)        {   return LET; }
(?i:loop)       {   return LOOP; }
(?i:pool)       {   return POOL; }
(?i:then)       {   return THEN; }
(?i:while)      {   return WHILE; }
(?i:case)       {   return CASE; }
(?i:esac)       {   return ESAC; }
(?i:of)         {   return OF; }
(?i:new)        {   return NEW; }
t(?i:rue)       {   return BOOL_CONST; }
f(?i:false)     {   return BOOL_CONST; }
    
    /* TODO: handle... */
    /* LE, NOT, ISVOID */

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%

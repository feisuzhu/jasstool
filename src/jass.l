%{
#include <stdio.h>

#define YYSTYPE_IS_DECLARED 1
typedef struct JASSSTYPE YYSTYPE;

#include "src/jass.h"
#include "jass.tab.h"

extern YYSTYPE *handle;

int jasswrap(void)
{
    return 1;
}


void cpstr()
{
    //printf("%s\n", yytext);
    memset(&jasslval, 0, sizeof(YYSTYPE));
    jasslval.str = strdup(jasstext);
    // strcpy(yylval.str, yytext);
}


int TOKEN(int i)
{
    cpstr();
    jasslval.type = i;
    jasslval.lineno = jasslineno;
    return i;
}

%}

%option yylineno

COMMENT "//".*\r*\n
NEWLINE (\r*\n)+|\r+
OCTDIGIT [0-7]
DIGIT [0-9]
HEXDIGIT [0-9a-fA-F]
IDENT [a-zA-Z][a-zA-Z0-9_]*
SPACE [ \t]
TABS [\x01-\x09\x0B\x0C\x0E-x1F]
STRING ["]([^"\\]|\\["btrnf\\])*?["]
UNITTYPELIT (['][\x01-\x26\x29-\x5B\x5D-\x7F]([\x01-\x26\x29-\x5B\x5D-\x7F][\x01-\x26\x29-\x5B\x5D-\x7F][\x01-\x26\x29-\x5B\x5D-\x7F])?['])

%x IN_BIGCOMMENT

%%

<INITIAL>{
{COMMENT} return TOKEN(COMMENT);

{NEWLINE} { 
    jasslval.str = strdup("\n"); 
    jasslval.type = LINEFEED; 
    return LINEFEED; 
}
{DIGIT}+"."{DIGIT}*|{DIGIT}*"."{DIGIT}+ return TOKEN(REALLIT);
"0"{OCTDIGIT}*|{DIGIT}*|"0x"{HEXDIGIT}* {
    unsigned int i, t;
    struct {
        char l;
        unsigned int num:32;
        char t;
        char nul;
    } __attribute__((packed)) cvt;

    t = i = atoi(yytext);
    t = (t>>16) | (t & 0xFFFF);
    t = (t>>8) | (t & 0xFF);
    if(i >= 0x30303030 /* '0000' */  && i <= 0x7a7a7a7a /* zzzz */ && t <= 0x7F) {
        cvt.l = cvt.t = '\'';
        cvt.nul = 0;

        __asm__("bswap %%eax;" : "=a"(i) : "a"(i) );

        cvt.num = i;
        
        memset(&jasslval, 0, sizeof(YYSTYPE));

        jasslval.type = UNITTYPELIT;
        jasslval.lineno = jasslineno;

        jasslval.str = strdup(&cvt.l);

        return UNITTYPELIT;

    } else {
        return TOKEN(INTLIT);
    }
}
"/*"    BEGIN(IN_BIGCOMMENT);

{STRING} return TOKEN(STRINGLIT);

{UNITTYPELIT}    return TOKEN(UNITTYPELIT);


"true"|"false"    return TOKEN(BOOLLIT);
"if"              return TOKEN(IF);
"not"             return TOKEN(NOT);
"then"            return TOKEN(THEN);
"type"            return TOKEN(TYPE);
"extends "        return TOKEN(EXTENDS);
"handle"          return TOKEN(HANDLE);
"globals"         return TOKEN(GLOBALS);
"endglobals"      return TOKEN(ENDGLOBALS);
"constant"        return TOKEN(CONSTANT);
"native"          return TOKEN(NATIVE);
"takes"           return TOKEN(TAKES);
"returns"         return TOKEN(RETURNS);
"function"        return TOKEN(FUNCTION);
"endfunction"     return TOKEN(ENDFUNCTION);
"local"           return TOKEN(LOCAL);
"array"           return TOKEN(ARRAY);
"set"             return TOKEN(SET);
"call"            return TOKEN(CALL);
"else"            return TOKEN(ELSE);
"elseif"          return TOKEN(ELSEIF);
"endif"           return TOKEN(ENDIF);
"loop"            return TOKEN(LOOP);
"exitwhen"        return TOKEN(EXITWHEN);
"return"          return TOKEN(RETURN);
"debug"           return TOKEN(DEBUG);
"endloop"         return TOKEN(ENDLOOP);
"null"            return TOKEN(TNULL);
"code"            return TOKEN(CODE);
"string"          return TOKEN(STRING);
"integer"         return TOKEN(INTEGER);
"real"            return TOKEN(REAL);
"boolean"         return TOKEN(BOOLEAN);
"nothing"         return TOKEN(NOTHING);
"and"             return TOKEN(AND);
"or"              return TOKEN(OR);

","               return TOKEN(COMMA);
"<="              return TOKEN(LEQ);
">="              return TOKEN(GEQ);
"<"               return TOKEN(LESS);
">"               return TOKEN(GREATER);
"["               return TOKEN(LBRACKET);
"]"               return TOKEN(RBRACKET);
"="               return TOKEN(EQUALS);
"=="              return TOKEN(EQCOMP);
"!="              return TOKEN(NEQ);
"*"               return TOKEN(MULTIPLY);
"-"               return TOKEN(MINUS);
"("               return TOKEN(LPAREN);
")"               return TOKEN(RPAREN);
"/"               return TOKEN(DIVIDE);
"+"               return TOKEN(ADD);


{IDENT}           return TOKEN(IDENT);

{SPACE}           /* toss */

. {
    printf("For Spring Brother's sake, the character '%c' at line %d makes my balls hurt -_-\n", jasstext[0], jasslineno);
    yyterminate();
}

}

<IN_BIGCOMMENT>{
"*/"    BEGIN(INITIAL);
[^*]+
"*"
}

%%

void whatever_this_is_absolutly_crap(void)
{
    input(); // just let gcc shut up
    yyunput(84065234, "Proton rocks");
    whatever_this_is_absolutly_crap();
}

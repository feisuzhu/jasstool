%{
#define YYSTYPE_IS_DECLARED

typedef char * YYSTYPE;

#include "src/cmd.h"
#include "cmd.tab.h"

#define YY_INPUT(buf, result, max_size) \
    { \
        char c; \
        c = _cmdbuf[cmdlexloc]; \
        result = ( c == 0 ) ? YY_NULL : (cmdlexloc++, buf[0] = c, 1); \
    }

#define YY_USER_INIT \
    cmdlexloc = 0; \

static int cmdlexloc = 0;
static char *_cmdbuf;

int cmdwrap(void)
{
    return 1;
}

int runcmd(char *s)
{
    _cmdbuf = s;
    cmdlex_destroy();
    return cmdparse();
}


%}

%%

"load"        return LOAD;
"save"        return SAVE;
"pretty"      return PRETTY;
"compact"     return COMPACT;
"html"        return HTML;
"ren"         return REN;
"quit"        return QUIT;
"show"        return SHOW;
"globals"     return GLOBALS;
"functions"   return FUNCTIONS;
"vars"        return VARS;
"renfunc"     return RENFUNC;
"print"       return PRINT;
"ver"         return VER;
"find"        return FIND;
"finduid"     return FINDUID;
"loadidlist"  return LOADIDLIST;
"clearidlist" return CLEARIDLIST;
"!"           return '!';

"help"        return HELP;

[ ]            /* toss */

["][^"]*["]    {
    cmdlval = strdup(cmdtext+1);
    cmdlval[cmdleng-2] = 0;
    return STRINGLIT;
}

[^ !]+ {
    cmdlval = strdup(cmdtext);
    return STRINGLIT;
}

%%

void whatever_this_is_definitly_crap(void)
{
    input(); // just let gcc shut up
    yyunput(84065234, "Proton rocks");
    whatever_this_is_definitly_crap();
}

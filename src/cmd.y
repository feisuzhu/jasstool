%{
#define YYSTYPE_IS_DECLARED

typedef char * YYSTYPE;


#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <malloc.h>
#include <stdlib.h>
#include <stdarg.h>

#include "src/cmd.h"
#include "src/misc.h"
#include "src/jass.h"

#include "jass.tab.h" // SO DO NOT #include "cmd.tab.h" NOW

int cmderror(char *s);
static int cmdparse_emptycount = 0;
static int cmdparse_succeed = 1;
extern void notimpl();

void printfunction(struct hashnode *hn);
void printline(struct JASSSTYPE *n);

int global_filter(struct JASSSTYPE *n);
int local_filter(struct JASSSTYPE *n);
int func_filter(struct JASSSTYPE *n);

int findident_filter(struct JASSSTYPE *n, void *arg);
int printident_filter(struct JASSSTYPE *n, void *arg);
int printuid_filter(struct JASSSTYPE *n, void *arg);

void var_rename(struct JASSSTYPE *n, char *from, char *to, int (*filter)(struct JASSSTYPE *));
void func_rename(struct JASSSTYPE *n, char *from,  char *to);

int confirm(char *s);

/* Command functions >>>>> */
void fail(char *f, ...)
{
    va_list l;
    cmdparse_succeed = 0;
    va_start(l, f);
    vprintf(f, l);
    va_end(l);
}



void load(char *f) {
    if(tkstatus == STATUS_PARSED || tkstatus == STATUS_MODIFIED) {
        printf(":: Cleanup...\n");
        destroyjasstree();
        tkstatus = STATUS_INITIAL;
    }

    if(parsefile(f)) {
        tkstatus = STATUS_PARSED;
    }
}

void savepretty(char *f) {
    if(tkstatus != STATUS_INITIAL) {
        FILE *fp;
        printf(":: Save result to '%s'...\n", f);
        fp = fopen(f, "w");
        if(!fp) {
            fail("!! Unable to open file '%s' !\n", f);
        } else {
            prettyprint(fp, handle);
            fclose(fp);
            printf(":: Done. \n");
            tkstatus = STATUS_PARSED;
        }
    }
}

/* <<<<< */

%}

%debug
%error-verbose

/* Tokens >>>>> */
%token LOAD
%token SAVE
%token PRETTY
%token COMPACT
%token HTML
%token REN
%token QUIT
%token HELP
%token SHOW
%token GLOBALS
%token FUNCTIONS
%token RENFUNC
%token VARS
%token VER
%token EXCLAM '!'
%token PRINT
%token FINDUID
%token FIND
%token LOADIDLIST
%token CLEARIDLIST

%token STRINGLIT

%token END 0

/* <<<<< */

%destructor { if($$) { free($$); $$ = 0; } } STRINGLIT strlist

%initial-action {
    cmdparse_succeed = 1;
}


%%

goal: /* empty */ {/*>>>>>*/
        cmdparse_emptycount++;
        if(cmdparse_emptycount >= 30) {
            cmdparse_emptycount = 0;
            printf(
                "Hey are you too bored, too tired, or too sleepy to go on doing your work?\n"
                "Working deadly hard is not approval, Proton suggests you to have a good rest...zzz...ZZZ\n"
                "Halt for 30 seconds :P\n"
            );
            sleep(30);
        }
    }/*<<<<<*/
    | command {/*>>>>>*/
        struct JASSSTYPE *p, r;
        char s[256];
        
        cmdparse_emptycount = 0;

        if(cmdparse_succeed && tkstatus != STATUS_INITIAL) {
            // append cmdline to end
            p = handle;
            while(p->rch)
                p = p->rch;
            
            sprintf(s, "// %s\n", commandstring);
            r.str = strdup(s);
            r.lch = r.rch = 0;
            r.pch = p;
            r.type = COMMENT;
            r.lineno = 0;

            p->rch = semdup(&r);

            p->rch->spc = NOSPC;
            p->rch->lfeed = NOLF;
            p->rch->indent = 0;
        }

    }/*<<<<<*/
;

command: LOAD STRINGLIT {/*>>>>>*/
        if(tkstatus == STATUS_MODIFIED) {
            fail("!! Script modified but not saved, use 'load %s !' to override.\n", $2);
        } else {
            load($2);
        }

        free($2);
    }/*<<<<<*/
    | LOAD STRINGLIT '!' {/*>>>>>*/
        load($2);
        free($2);
    }/*<<<<<*/
    | SAVE {/*>>>>>*/
        savepretty(filename);
    }/*<<<<<*/
    | SAVE PRETTY {/*>>>>>*/
        savepretty(filename);
    }/*<<<<<*/
    | SAVE PRETTY STRINGLIT {/*>>>>>*/
        savepretty($3);
        if(filename) 
            free(filename);
        filename = $3;
    }/*<<<<<*/
    | SAVE COMPACT {/*>>>>>*/
        notimpl();
    }/*<<<<<*/
    | SAVE COMPACT STRINGLIT {/*>>>>>*/
        notimpl();
        free($3);
    }/*<<<<<*/
    | SAVE HTML {/*>>>>>*/
        notimpl();
    }/*<<<<<*/
    | SAVE HTML STRINGLIT {/*>>>>>*/
        notimpl();
        free($3);
    }/*<<<<<*/
    | REN STRINGLIT STRINGLIT {/*>>>>>*/
        char c[256];

        if(tkstatus == STATUS_INITIAL) {
            fail("!! Load a script first *_*\n");
        } else {
            if(!lookup(&jassglobals, $2)) {
                fail("!! Global variable named '%s' does not exist.\n", $2);
            } else if(allname_lookup($3)) {
                fail("!! Can't rename due to name conflict.\n");
            } else {
                sprintf(c, "Rename global variable '%s' to '%s' ?", $2, $3);
                if(confirm(c)) {
                    struct hashnode *n;

                    var_rename(handle, $2, $3, global_filter);

                    /* for dbg */
                    treewalk(handle, printident_filter, $2);
                    /* */
                    n = lookup(&jassglobals, $2);
                    put(&jassglobals, $3, n->handle, NULL);
                    hashremove(&jassglobals, $2);

                    allname_add($3);
                    allname_remove($2);
                    
                    tkstatus = STATUS_MODIFIED;
                }
            }
        }

        free($2);
        free($3);
    }/*<<<<<*/
    | REN STRINGLIT STRINGLIT STRINGLIT {/*>>>>>*/
        if(tkstatus == STATUS_INITIAL) {
            fail("!! Load a script first *_*");
        } else {
            struct hashnode *n,*n1;
            char c[256];
            n = lookup(&jassfuncs, $4);

            if(!n) {
                fail("!! Function named '%s' does not exist.\n", $4);
            } else if(!lookup(n->vars, $2)) {
                fail("!! Local variable '%s' in function '%s' does not exist.\n", $2, $4);
            } else if(lookup(&jassglobals, $3)) {
                fail("!! Can't rename due to name conflict.\n");
            } else {
                sprintf(c, "Rename local variable '%s' in function '%s' to '%s' ?", $2, $4, $3);
                if(confirm(c)) {
                    var_rename(n->handle, $2, $3, local_filter);
                    
                    /* for dbg */
                    treewalk(n->handle, printident_filter, $2);
                    /* */

                    n1 = lookup(n->vars, $2);
                    put(n->vars, $3, n->handle, NULL);
                    hashremove(n->vars, $2);

                    allname_add($3);
                    allname_remove($2);
                    
                    tkstatus = STATUS_MODIFIED;
                }
            }
        }
        free($2);
        free($3);
        free($4);
    }/*<<<<<*/
    | RENFUNC STRINGLIT STRINGLIT {/*>>>>>*/
        if(tkstatus == STATUS_INITIAL) {
            fail("!! Load a script first *_*\n");
        } else {
            struct hashnode *n;
            char c[256];

            n = lookup(&jassfuncs, $2);
            if(!n) {
                fail("!! Function named '%s' does not exist.\n", $2);
            } else if(allname_lookup($3)) {
                fail("!! Can't rename due to name conflict.\n");
            } else {
                sprintf(c, "Rename function '%s' to '%s' ?", $2, $3);
                if(confirm(c)) {
                    func_rename(handle, $2, $3);

                    /* for dbg */
                    treewalk(handle, printident_filter, $2);
                    /* */

                    put(&jassfuncs, $3, n->handle, n->vars);
                    hashremove(&jassfuncs, n->name);

                    allname_add($3);
                    allname_remove($2);
                
                    tkstatus = STATUS_MODIFIED;
                }
            }
        }

        free($2);
        free($3);
    }/*<<<<<*/
    | FIND STRINGLIT {/*>>>>>*/
        if(tkstatus != STATUS_INITIAL) {
            treewalk(handle, printident_filter, $2);
        } else {
            fail("!! Load a script first *_*\n");
        }
        free($2);
    }/*<<<<<*/
    | FINDUID STRINGLIT {/*>>>>>*/
        char s[256];
        if(tkstatus != STATUS_INITIAL) {
            sprintf(s, "'%s'", $2);
            treewalk(handle, printuid_filter, s);
        } else {
            fail("!! Load a script first *_*\n");
        }

        free($2);
    }/*<<<<<*/
    | QUIT {/*>>>>>*/
        printf("\n");
        exit(0);
    }/*<<<<<*/
    | HELP {/*>>>>>*/
        printf(
            "This is the manual you are looking for ^_^\n"
            "Generally, your instructions will look like this:\n"
            "\n"
            "   jtool> load war3map.j\n"
            "   jtool> print func1\n"
            "   jtool> ren varname_nonsense thisIsAMeaningfulVarname func1\n"
            "   jtool> ren GLOBALVAR1 global_MeaningfulName\n"
            "   jtool> renfunc func1 FunctionWithMeaningfulName\n"
            "   jtool> save\n"
            "\n"
            "These instructions mean:\n"
            "   1 -> Load a script named 'war3map.j'\n"
            "   2 -> Print the function named func1\n"
            "   3 -> Rename a local variable in function func1\n"
            "   4 -> Rename a global var\n"
            "   5 -> Rename a function\n"
            "   6 -> Save result\n"
            "\n"
            "You can get help of each instruction by this:\n"
            "\n"
            "   jtool> help print\n"
            "\n"
            "This will show you the usage of 'print' instruction.\n"
            "\n"
            "Incomplete list of instructions:\n"
            "   load        ->  Load a script(Open a script)\n"
            "   save        ->  Save modified script\n"
            "   print       ->  Print a function or entire script\n"
            "   ren         ->  Rename a variable\n"
            "   renfunc     ->  Rename a function\n"
            "   show        ->  Show something\n"
            "   find        ->  Find specific identifier(varname, funcname, whatever you want, but not a language keyword)\n"
            "   finduid     ->  Find specific unittypeid('ANcl' things)\n"
            "   loadidlist  ->  Load an unittypelist\n"
            "   clearidlist ->  Clear loaded unittypelist\n"
            "\n"
            "Note that this is NOT a Jass checker! It will do with the script if it can be parsed, "
            "and won't notice semantic errors! eg: 'call FuncNotExist(\"string\" + 123 + true)' will silently pass the parser!\n"
            "\n"
            "Mail feisuzhu@163.com if you got any advice or bug!\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP SAVE {/*>>>>>*/
        printf(
            "Save your script.\n"
            "\n"
            "   save                ->  Replace original script with modified version\n"
            "   save <filename>     ->  Save modified script to a new location\n"
            "   save pretty         ->  Same as above.\n"
            "   save pretty <file>  ->  Same as above.\n"
            "   save compact        ->  Save using compact form(*)\n"
            "   save html           ->  Save as syntax highlighted HTML(*)\n"
            "(* marked are not implemented)\n"
            "-------------------\n"
            "   jtool> save\n"
            "   jtool> save copy.j\n"
            "\n"
            "ATTENTION: Overwrite without prompt!\n" 
            "Quite easy to use ^_^\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP LOAD {/*>>>>>*/
        printf(
            "Load a script.\n"
            "\n"
            "   load <filename> -> Load a script\n"
            "------------------\n"
            "   jtool> load war3map.j\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP REN {/*>>>>>*/
        printf(
            "Rename a variable."
            "\n"
            "   ren <a> <b>     ->  Rename a global varible 'a' to 'b'\n"
            "   ren <a> <b> <c> ->  Rename a local variable 'a' to 'b' in function 'c'\n"
            "-------------\n"
            "   jtool> print\n"
            "   globals\n"
            "   endglobals\n"
            "\n"
            "   function a takes nothing returns nothing\n"
            "       local integer d\n"
            "       call FuncNotExist(\"string\" + 123 + true)\n"
            "       set d = ((c + 1)*2)\n"
            "   endfunction\n"
            "\n"
            "   jtool> ren d haha a\n"
            "   Rename local variable 'd' in function 'a' to 'haha' ? (y/n)y\n"
            "   Affected line: 5 -> local integer haha\n"
            "   Affected line: 7 -> set haha = ((c + 1)*2)\n"
            "   jtool>\n"
            "\n"

        );
    }/*<<<<<*/
    | HELP QUIT {/*>>>>>*/
        printf("Well, run it and I will quit....\n");
    }/*<<<<<*/
    | HELP RENFUNC {/*>>>>>*/
        printf(
            "Rename a function.\n"
            "\n"
            "   renfunc <a> <b> ->  Rename a function 'a' to 'b'\n"
            "-------------\n"
            "   jtool> print a\n"
            "   // Line 7\n"
            "   function a takes nothing returns nothing\n"
            "       local string func = \"hahaha\"\n"
            "       call hahaha()\n"
            "       call ExecuteFunc(\"hahaha\")\n"
            "   endfunction\n"
            "\n"
            "   jtool> renfunc hahaha hehe\n"
            "   Rename function 'hahaha' to 'hehe' ? (y/n)y\n"
            "   Affected line: 4 -> function hehe takes nothing returns nothing\n"
            "   Guessed rename: 8 -> local string func = \"hehe\"\n"
            "   Affected line: 9 -> call hehe()\n"
            "   Guessed rename: 10 -> call ExecuteFunc(\"hehe\")\n"
            "   jtool> \n"
            "\n"
        );
    }/*<<<<<*/
    | HELP FIND {/*>>>>>*/
        printf(
            "Find specific identifier.\n"
            "List below is what you CAN'T find by this command:\n"
            "   Language keywords:\n"
            "       'function'\n"
            "       'type'\n"
            "       + - * / ( ) [ ] ....\n"
            "       and a lot of....\n"
            "   Literials:\n"
            "       Strings\n"
            "       Integers/Reals/UnitTypeIDs\n"
            "       and so on...\n"
            "\n"
            "   find <ident>    ->  Find all the occurances of specified identifier.\n"
            "---------------\n"
            "   jtool> find hahaha\n"
            "   Try it by your self :)\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP FINDUID {/*>>>>>*/
        printf(
            "Find specific unittypeid.\n"
            "\n"
            "   jtool> finduid ANcl\n"
            "   Try it by your self :)\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP LOADIDLIST {/*>>>>>*/
        printf(
            "Load unittypeid list\n"
            "\n"
            "A unit type id list is used for identifying unittypeids.\n"
            "When doing analysis with obfuscated scripts, these transformed integers "
            "may really 'obfuscate' your head. Especially in DotA, a lot of dummy structures are just used "
            "for storing a string, for I18N. If you made a list and loaded it, "
            "it's name will appear when you use 'print' to view them.\n"
            "-------------------\n"
            "\n"
            "    jtool> print a\n"
            "    // Line 7\n"
            "    function a takes nothing returns nothing\n"
            "        set b = 'Aamk'\n"
            "    endfunction\n"
            "    \n"
            "    jtool> loadidlist idlist.txt \n"
            "    :: Loading unittypeid list...\n"
            "    :: Done.\n"
            "    jtool> print a\n"
            "    // Line 7\n"
            "    function a takes nothing returns nothing\n"
            "        set b = 'Aamk' /* Attribute Bonus */\n"
            "    endfunction\n"
            "    \n"
            "A 'save' here will also write these comments in your script.\n"
            "\n"
            "Note that this comment method is NOT in Jass and won't be accepted by War3, "
            "when you want to put your script into War3, don't preserve them.\n"
            "You can drop them by 'clearidlist' and 'save', or 'save' the next time when you launch jtool.\n"
            "\n"
            "You can load multiple idlists, all of them works, but the latter overwrites the first.\n"
            "\n"
            "An idlist is of the form:\n"
            "   Aamk Attribute Bonus\n"
            "   ANcl The great channel\n"
            "   Amrf Crow Form\n"
            "   .....\n"
            "\n"
            "In regular expression:\n"
            "   ^.{4} .*$\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP CLEARIDLIST {/*>>>>>*/
        printf(
            "Clear idlist.\n"
            "For more info, try 'help loadidlist'\n"
            "\n"
            "   jtool> clearidlist\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP PRINT {
        printf(
            "Print code.\n"
            "\n"
            "   print        ->  Print entire script.\n"
            "   print <func> ->  Print function 'func'\n"
            "\n"
            "Try it by your self :)\n"
            "\n"
        );
    }
    | HELP SHOW {/*>>>>>*/
        printf(
            "Show something.\n"
            "\n"
            "   jtool> show functions\n"
            "   jtool> show globals\n"
            "Try it by your self :)\n"
            "Not that useful.\n"
            "\n"
        );
    }/*<<<<<*/
    | HELP STRINGLIT {/*>>>>>*/
        if(!strcmp($2, "Proton")) {
            printf(
                "Proton is an ordinary college student from China.\n"
                "But he considers himself a half-geek,\n"
                "\n"
                "When he is in non-geek mode, he plays games like xyq, DotA(maybe with cheats), etc.\n"
                "But he only gets so far :(\n"
                "About DotA, he is vulnerable to any of his roommates.\n"
                "He can only use Atropos and Rylai...\n"
                "About mhxy, he has a lvl69 mowangzhai ID taking a pet of his roommate,\n"
                "and a lvl60 fangcunshan ID with no pet and attribute dots added wrong :(\n"
                "\n"
                "Not long ago, he got bored of the routines on xyq, dropped that game,\n"
                "AND ACTIVITED *GEEK MODE*\n"
                "He want to add some new hero and new ability to the DotA map,\n"
                "and found that the whole war3map.j was obfuscated,\n"
                "so this tool poped up.\n"
                "\n"
                "Feel free to contact me -> http://www.renren.com/profile.do?id=253307520\n"
                "                     QQ -> 84065234\n"
                "Have a good time!\n"
                "\n"
                "PS: May god bless Guo Bing! *FUCK* carcinoma\n"
                "\n"
            );
        } else {
            fail("'%s' is not known as any command :P , try 'help'\n", $2);
        }

        free($2);
    }/*<<<<<*/
    | strlist {/*>>>>>*/
        if(!strcmp($1, "Proton"))
            printf("Heard you! Well, what's up?\n");
        else
            fail("'%s' is not known as any command :P , try 'help'\n", $1);
        
        free($1);
    }/*<<<<<*/
    | VER {/*>>>>>*/
        printf(
            "It's now a beta version!\n"
            "It is frequently used by the author in practice,\n"
            "and found no faults.\n"
        );
    }/*<<<<<*/
    | SHOW GLOBALS {/*>>>>>*/
        if(tkstatus != STATUS_INITIAL) {
            prettyprint(stdout, pre_treewalk(handle, findident_filter, (void*)nt_global_var_list)->lch);
        } else {
            fail("!! Load a script first *_*\n");
        }
    }/*<<<<<*/
    | SHOW FUNCTIONS {/*>>>>>*/
        if(tkstatus != STATUS_INITIAL) {
            hashwalk(&jassfuncs, printfunction);
        } else {
            fail("!! Load a script first *_*\n");
        }

    }/*<<<<<*/
    | SHOW VARS STRINGLIT {/*>>>>>*/
        free($3);
        notimpl();
    }/*<<<<<*/
    | PRINT {/*>>>>>*/
        if(tkstatus != STATUS_INITIAL) {
            prettyprint(stdout, handle);
        } else {
            fail("!! Load a script first *_*\n");
        }
    }/*<<<<<*/
    | PRINT STRINGLIT {/*>>>>>*/
        if(tkstatus != STATUS_INITIAL) {
            struct hashnode *p;
            if( (p = lookup(&jassfuncs, $2)) ) {
                printf("// Line %d\n", p->handle->lineno);
                prettyprint(stdout, p->handle);
            } else {
                fail("!! Didn't find a function named '%s' \n", $2);
            }
        } else {
            fail("!! Load a script first *_*\n");
        }

        free($2);
    }/*<<<<<*/
    | LOADIDLIST STRINGLIT {/*>>>>>*/
        FILE *f;
        printf(":: Loading unittypeid list...\n");
        f = fopen($2, "r");
        if(!f) {
            fail("!! Unable to open '%s'.\n");
        } else {
            char buf[1024];
            while(fgets(buf, 1024, f)) {
                buf[strlen(buf)-1] = 0;
                idadd(*((int*)buf), &buf[5]); // Format is --> ^(.{4}) (.*)$ <--, for id and desc
            }
            fclose(f);
            printf(":: Done.\n");
        }

        free($2);
    }/*<<<<<*/
    | CLEARIDLIST {/*>>>>>*/
        idtabledestroy();
        printf(":: Unittypelist cleared.\n");
    }/*<<<<<*/
;

strlist: STRINGLIT 
    | strlist STRINGLIT {
        free($2);
        $$ = $1;
    }
;


%%

int cmderror(char *s)/*>>>>>*/
{
    fail("There is something wrong with your command, try 'help' :)\n%s\n", s);
    return 0;
}/*<<<<<*/

void printfunction(struct hashnode *hn)/*>>>>>*/
{
    printline(hn->handle);
}/*<<<<<*/

static struct hashtable *global_filter_infunc;
int global_filter(struct JASSSTYPE *n) // >>>>>
{
    if(n->type == IDENT) { 
        switch(n->pch->type) {
        case nt_global_var_list_item:
            return 1;

        case nt_set:
        case nt_expr:
        case nt_array_ref:
            if(!global_filter_infunc) {
                fail("?? Internal error: see function '%s'. \n", __PRETTY_FUNCTION__);
                exit(1);
            }
            if(lookup(global_filter_infunc, n->str)) 
                return 0;
            else
                return 1;

        case nt_var_declr:
            if(n->pch->pch->type == nt_global_var_list_item) {
                return 1;
            } else {
                return 0;
            }

        default:
            return 0;
        }
    } else if(n->type == nt_func_declr) {
        global_filter_infunc = lookup(&jassfuncs, n->lch->str)->vars;
        if(!global_filter_infunc) {
            fail("?? Internal error: can't find the record of func '%s'\n", n->lch->str);
            exit(1);
        }
    } else if(n->type == nt_file) {
        global_filter_infunc = NULL;
    }
    return 0;
} // <<<<<
int local_filter(struct JASSSTYPE *n) // >>>>>
{
    if(n->type == IDENT) { 
        switch(n->pch->type) {
        case nt_param_list_item:
        case nt_set:
        case nt_expr:
        case nt_array_ref:
            return 1;

        case nt_var_declr:
            if(n->pch->pch->type == nt_local_var_list_item) {
                return 1;
            } else {
                return 0;
            }

        default:
            return 0;
        }
    }
    return 0;
} // <<<<<
int func_filter(struct JASSSTYPE *n) // >>>>>
{
    switch(n->pch->type) {
    case nt_func_declr:
    case nt_call:
    case nt_func_ref:
    case nt_func_call:
        return 1;

    default:
        return 0;
    }
} // <<<<<

void var_rename(struct JASSSTYPE *n, char *from, char *to, int (*filter)(struct JASSSTYPE *))/*>>>>>*/
{
    if(n) {
        var_rename(n->lch, from, to, filter);
        if(filter(n)) {
            if(!strcmp(from, n->str)) {
                free(n->str);
                n->str = strdup(to);
                printf("Affected line: %d -> ", n->lineno);
                
                printline(n);
            }
        }
        var_rename(n->rch, from, to, filter);
    }
}/*<<<<<*/
void func_rename(struct JASSSTYPE *n, char *from,  char *to)/*>>>>>*/
{
    if(n) {
        func_rename(n->lch, from, to);
        if(n->type == IDENT && func_filter(n)) {
            if(!strcmp(from, n->str)) {
                free(n->str);
                n->str = strdup(to);
                printf("Affected line: %d -> ", n->lineno);
                
                printline(n);
            }
        } else if(n->type == STRINGLIT) {
            char s[256];
            sprintf(s, "\"%s\"", from);
            if(!strcmp(s, n->str)) {
                sprintf(s, "\"%s\"", to);
                free(n->str);
                n->str = strdup(s);
                printf("Guessed rename: %d -> ", n->lineno);

                printline(n);
            }
        }
        func_rename(n->rch, from, to);
    }

}/*<<<<<*/

void printline(struct JASSSTYPE *n) // >>>>>
{
    struct JASSSTYPE *t;
    for( ; n; n = n->pch) {
        switch((int)n->type) {
        case nt_global_var_list_item:
        case nt_func:
        case nt_local_var_list_item:
        case nt_statement:
        case nt_ifthenelse:
        case nt_else_clause:
            goto found;
        }
    }
    found:
    if(!n) {
        fail("?? Can't find target element X_X\n");
        exit(1);
    } 
    
    for( n = n->lch; n && n->type != nt_newlines; n = n->rch) {
        if(n->type > end_of_nt) {
            t = n->rch;
            n->rch = 0;
            prettyprint(stdout, n);
            n->rch = t;
        } else {
            prettyprint(stdout, n->lch);
        }
    }
    printf("\n");
} // <<<<<

int confirm(char *s) /*>>>>>*/
{
    char c[256];

    while(1) {
        printf("%s (y/n)", s);
        if(fgets(c, 256, stdin) && !strcmp(c, "y\n")) {
            return 1;
            break;
        } else if(!strcmp(c, "n\n")) {
            return 0;
            break;
        }
    }
}/*<<<<<*/

int findident_filter(struct JASSSTYPE *n, void *arg)/*>>>>>*/
{
    if(n->type == (long)arg)
        return 1;
    else
        return 0;
}/*<<<<<*/
int printident_filter(struct JASSSTYPE *n, void *arg)/*>>>>>*/
{
    if(n->type == IDENT && !strcmp(n->str, arg)) {
        printf("Found at line %d -> ", n->lineno);
        printline(n);
    }
    return 0;
}/*<<<<<*/

int printuid_filter(struct JASSSTYPE *n, void *arg)/*>>>>>*/
{
    if(n->type == UNITTYPELIT && !strcmp(n->str, arg)) {
        printf("Found at line %d -> ", n->lineno);
        printline(n);
    }
    return 0;
}/*<<<<<*/


// vim: foldmethod=marker foldmarker=>>>>>,<<<<<:


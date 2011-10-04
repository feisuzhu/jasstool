%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "src/jass.h"
#include "src/misc.h"

#define YYSTYPE_IS_DECLARED 1
typedef struct JASSSTYPE YYSTYPE;

/* Function Declarations >>>>> */
void jasserror(char *s);
void setpch(struct JASSSTYPE *c);
struct JASSSTYPE* setrch(struct JASSSTYPE *head, ...);
void setspc(struct JASSSTYPE *head, ...);
void setindent(struct JASSSTYPE *head, ...);
void setlfeed(struct JASSSTYPE *head, ...);
int addlocalvars(struct hashtable *h, struct JASSSTYPE *n);
/* <<<<< */

%}

%error-verbose
%debug

// Tokens >>>>>

%token LINEFEED        // '\n'
%token TYPE            // 'type'
%token IDENT        // <identifier>
%token EXTENDS        // 'extends'
%token HANDLE        // 'handle'
%token GLOBALS        // 'globals'
%token ENDGLOBALS    // 'endglobals'
%token NATIVE        // 'native'
%token COMMA        // ','
%token CONSTANT        // 'constant'
%token ENDFUNCTION    // 'endfunction'
%token FUNCTION        // 'function'
%token TAKES        // 'takes'
%token NOTHING        // 'nothing'
%token RETURNS        // 'returns'
%token TNULL        // 'null'
%token LEQ            // '<='
%token GEQ            // '>='
%token LESS            // '<'
%token GREATER        // '>'
%token LBRACKET        // '['
%token RBRACKET        // ']'
%token EQUALS        // '='
%token EQCOMP        // '=='
%token DEBUG        // 'debug'
%token BOOLEAN        // 'boolean'
%token NOT            // 'not'
%token OR            // 'or'
%token NEQ            // '!='
%token CALL            // 'call'
%token MULTIPLY        // '*'
%token EXITWHEN        // 'exitwhen'
%token REALLIT        // 1.234545
%token ELSEIF        // 'elseif'
%token ELSE            // 'else'
%token REAL            // 'real'
%token LOCAL        // 'local'
%token ENDLOOP        // 'endloop'
%token RETURN        // 'return'
%token INTLIT        // 84065234
%token INTEGER        // 'integer'
%token MINUS        // '-'
%token CODE            // 'code'
%token IF            // 'if'
%token AND            // 'and'
%token LPAREN        // '('
%token LOOP            // 'loop'
%token UNITTYPELIT    // '\'ABCD\''
%token SET            // 'set'
%token RPAREN        // ')'
%token DIVIDE        // '/'
%token ENDIF        // 'endif'
%token STRINGLIT    // '"It is a bison .y file for Jass scripting language written by Proton!"'
%token ADD            // '+'
%token STRING        // 'string'
%token THEN            // 'then'
%token ARRAY        // 'array'
%token BOOLLIT        // 'true' and 'false'
%token COMMENT        // '// whatever'

%right EQUALS        // '='
%right NOT
%left EQCOMP
%left OR
%left AND
%nonassoc NEQ GEQ LEQ GREATER LESS
%left ADD MINUS
%left MULTIPLY DIVIDE

// <<<<<

/* Initial action >>>>> */
%initial-action {
    clear(&jassglobals);
    memset(&jassglobals, 0, sizeof(jassglobals));
    clear(&jassfuncs);
    memset(&jassfuncs, 0, sizeof(jassfuncs));
    clear(&jassallname);
    memset(&jassallname, 0, sizeof(jassallname));
}/*<<<<<*/

%%

/* Global declarations >>>>> */

program: file files {/*>>>>>*/
        $$.type = nt_program;
        $$.lch = setrch(&$1, &$2, NULL);

        handle = setrch(&$$, NULL);
    }/*<<<<<*/
;

files: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | files file {/*>>>>>*/
        $$.type = nt_files;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

file: newlines declrs newlines funcs {/*>>>>>*/
        $$.type = nt_file;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
    }/*<<<<<*/
;

newlines: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | newlines newline {/*>>>>>*/
        $$.type = nt_newlines;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

declrs: declr {/*>>>>>*/
        $$.type = nt_declrs;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | declrs declr {/*>>>>>*/
        $$.type = nt_declrs;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

funcs: func {/*>>>>>*/
        $$.type = nt_funcs;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | funcs func {/*>>>>>*/
        $$.type = nt_funcs;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

declr: typedef {/*>>>>>*/
        $$.type = nt_declr;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | globals {/*>>>>>*/
        $$.type = nt_declr;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | native_func {/*>>>>>*/
        $$.type = nt_declr;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
;

typedef: TYPE IDENT EXTENDS HANDLE {/*>>>>>*/
        $$.type = nt_typedef;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, RSPC, RSPC, RSPC, NOSPC);
    }/*<<<<<*/
    | TYPE IDENT EXTENDS IDENT {/*>>>>>*/
        $$.type = nt_typedef;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, RSPC, RSPC, RSPC, NOSPC);
    }/*<<<<<*/
;

globals: GLOBALS newlines global_var_list ENDGLOBALS {/*>>>>>*/
        $$.type = nt_globals;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, NOSPC, 0, 0, NOSPC);
        setindent($$.lch, 1, 0, -1, 0);
        setlfeed($$.lch, 0, 0, 0, RLF); 
    }/*<<<<<*/
;

global_var_list: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | global_var_list global_var_list_item {/*>>>>>*/
        $$.type = nt_global_var_list;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

global_var_list_item: CONSTANT type IDENT EQUALS expr newlines {/*>>>>>*/
        $$.type = nt_global_var_list_item;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, NULL);
        setspc($$.lch, RSPC, 0, NOSPC, LRSPC, 0, 0);

        allname_add($3.str);
        if(!put(&jassglobals, $3.str, $$.lch, NULL)) { 
            printf("!! It seems that there are more than one global variable called '%s' o_O\n", $3.str);
            YYABORT;
        }
    }/*<<<<<*/
    | var_declr newlines {/*>>>>>*/
        char *s;
        $$.type = nt_global_var_list_item;
        $$.lch = setrch(&$1, &$2, NULL);
        
        if($1.lch->rch->type == IDENT) {
            s = $1.lch->rch->str;
        } else {
            s = $1.lch->rch->rch->str;
        }

        allname_add(s);

        if(!put(&jassglobals, s, $$.lch, NULL)) { 
            printf("!! It seems that there are more than one global variable called '%s' o_O\n", s);
            YYABORT;
        }
    }/*<<<<<*/
;

native_func: CONSTANT NATIVE func_declr {/*>>>>>*/
        $$.type = nt_native_func;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, RSPC, RSPC, 0);
    }/*<<<<<*/
    | NATIVE func_declr {/*>>>>>*/
        $$.type = nt_native_func;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;

func_declr: IDENT TAKES func_takes RETURNS func_returns {/*>>>>>*/
        $$.type = nt_func_declr;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, NULL);
        setspc($$.lch, RSPC, RSPC, 0, LRSPC, 0);
    }/*<<<<<*/
;

func_takes: NOTHING {/*>>>>>*/
        $$.type = nt_func_takes;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | param_list {/*>>>>>*/
        $$.type = nt_func_takes;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
;

func_returns: type {/*>>>>>*/
        $$.type = nt_func_returns;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | NOTHING {/*>>>>>*/
        $$.type = nt_func_returns;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
;

param_list: param_list_item {/*>>>>>*/
        $$.type = nt_param_list;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | param_list param_list_item_with_comma {/*>>>>>*/
        $$.type = nt_param_list;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

param_list_item: type IDENT {/*>>>>>*/
        $$.type = nt_param_list_item;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, 0, NOSPC);
    }/*<<<<<*/
;

param_list_item_with_comma: COMMA param_list_item {/*>>>>>*/
        $$.type = nt_param_list_item_with_comma;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;

func: CONSTANT FUNCTION func_declr newlines local_var_list statement_list ENDFUNCTION newlines {/*>>>>>*/
        struct hashtable *pt;

        $$.type = nt_func;

        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, &$7, &$8, NULL);

        setspc($$.lch, RSPC, RSPC, 0, 0, 0, 0, NOSPC, 0);
        setindent($$.lch, 1, 0, 0, 0, 0, -1, 0, 0);
        setlfeed($$.lch, NOLF, NOLF, 0, 0, 0, 0, RLF, 0);
        
        pt = malloc(sizeof(struct hashtable));
        memset(pt, 0, sizeof(struct hashtable));
    
        allname_add($3.lch->str);

        if(!put(&jassfuncs, $3.lch->str, $$.lch, pt)) { 
            printf("!! It seems that there are more than one function called '%s' o_O\n", $3.lch->str);
            YYABORT;
        }

        if(!addlocalvars(pt, $$.lch)) 
            YYABORT;

    }/*<<<<<*/
    | FUNCTION func_declr newlines local_var_list statement_list ENDFUNCTION newlines {/*>>>>>*/
        struct hashtable *pt;

        $$.type = nt_func;

        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, &$7, NULL);

        setspc($$.lch, RSPC, 0, 0, 0, 0, NOSPC, 0);
        setindent($$.lch, 1, 0, 0, 0, -1, 0, 0);
        setlfeed($$.lch, NOLF, 0, 0, 0, 0, RLF, 0);
        
        pt = malloc(sizeof(struct hashtable));
        memset(pt, 0, sizeof(struct hashtable));
        
        allname_add($2.lch->str);

        if(!put(&jassfuncs, $2.lch->str, $$.lch, pt)) { 
            printf("!! It seems that there are more than one function called '%s' o_O\n", $2.lch->str);
            YYABORT;
        }

        if(!addlocalvars(pt, $$.lch)) 
            YYABORT;

    }/*<<<<<*/
;
// <<<<<

/* Local Declarations >>>>> */

local_var_list: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | local_var_list local_var_list_item {/*>>>>>*/
        $$.type = nt_local_var_list;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

local_var_list_item: LOCAL var_declr newlines {/*>>>>>*/
        $$.type = nt_local_var_list_item;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, RSPC, NOSPC, 0);

    }/*<<<<<*/
;

var_declr: type IDENT var_declr_initval {/*>>>>>*/
        $$.type = nt_var_declr;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, NOSPC, 0);
    }/*<<<<<*/
    | type ARRAY IDENT {/*>>>>>*/
        $$.type = nt_var_declr;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, RSPC, NOSPC);
    }/*<<<<<*/
;

var_declr_initval: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | EQUALS expr {/*>>>>>*/
        $$.type = nt_var_declr_initval;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, LRSPC, 0);
    }/*<<<<<*/
;

// <<<<<

/* Statements >>>>> */

statement_list: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | statement_list statement {/*>>>>>*/
        $$.type = nt_statement_list;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

statement: set newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | call newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | ifthenelse newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | loop newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | exitwhen newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | return newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
    | debug newlines {/*>>>>>*/
        $$.type = nt_statement;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

set: SET IDENT EQUALS expr {/*>>>>>*/
        $$.type = nt_set;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, RSPC, NOSPC, LRSPC, 0);
    }/*<<<<<*/
    | SET IDENT LBRACKET expr RBRACKET EQUALS expr {/*>>>>>*/
        $$.type = nt_set;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, &$7, NULL);
        setspc($$.lch, RSPC, NOSPC, NOSPC, 0, NOSPC, LRSPC, NOSPC);
    }/*<<<<<*/
;

call: CALL IDENT LPAREN args RPAREN {/*>>>>>*/
        $$.type = nt_call;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, NULL);
        /*
        if($4.lch->rch->type == empty) { 
            setspc($$.lch, RSPC, NOSPC, NOSPC, 0, NOSPC);
        } else { 
            setspc($$.lch, RSPC, NOSPC, RSPC, 0, LSPC);
        }
        */
        setspc($$.lch, RSPC, NOSPC, NOSPC, 0, NOSPC);

    }/*<<<<<*/
    | CALL IDENT LPAREN RPAREN {/*>>>>>*/
        $$.type = nt_call;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, RSPC, NOSPC, NOSPC, NOSPC);
    }/*<<<<<*/
;

args: expr args_items {/*>>>>>*/
        $$.type = nt_args;
        $$.lch = setrch(&$1, &$2, NULL);
    }/*<<<<<*/
;

args_items: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | args_items COMMA expr {/*>>>>>*/
        $$.type = nt_args_items;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, RSPC, 0);
    }/*<<<<<*/
;

ifthenelse: IF expr THEN newlines statement_list else_clause ENDIF {/*>>>>>*/
        $$.type = nt_ifthenelse;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, &$7, NULL);
        setspc($$.lch, RSPC, 0, LSPC, 0, 0, 0, NOSPC);
        setindent($$.lch, 1, 0, 0, 0, -1, 0, 0);
    }/*<<<<<*/
;

else_clause: /* empty */ {/*>>>>>*/
        $$.type = empty;
        $$.lch = $$.rch = NULL;
        $$.str = NULL;
    }/*<<<<<*/
    | ELSE newlines statement_list else_clause {/*>>>>>*/
        $$.type = nt_else_clause;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, RSPC, 0, 0, 0);
        setindent($$.lch, 1, 0, -1, 0);
    }/*<<<<<*/
    | ELSEIF expr THEN newlines statement_list else_clause {/*>>>>>*/
        $$.type = nt_else_clause;
        $$.lch = setrch(&$1, &$2, &$3, &$4, &$5, &$6, NULL);
        setspc($$.lch, RSPC, 0, LSPC, 0, 0, 0);
        setindent($$.lch, 1, 0, 0, 0, -1, 0);
    }/*<<<<<*/
;

loop: LOOP newlines statement_list ENDLOOP {/*>>>>>*/
        $$.type = nt_loop;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
         setspc($$.lch, NOSPC, 0, 0, NOSPC);
        setindent($$.lch, 1, 0, -1, 0);
    }/*<<<<<*/
;

exitwhen: EXITWHEN expr {/*>>>>>*/ 
        $$.type = nt_exitwhen; 
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;

return: RETURN {/*>>>>>*/ 
        $$.type = nt_return; $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | RETURN expr {/*>>>>>*/ 
        $$.type = nt_return; 
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;

debug: DEBUG set {/*>>>>>*/ 
        $$.type = nt_debug; 
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
    | DEBUG call {/*>>>>>*/ 
        $$.type = nt_debug;
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
    | DEBUG ifthenelse {/*>>>>>*/ 
        $$.type = nt_debug; 
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
    | DEBUG loop {/*>>>>>*/ 
        $$.type = nt_debug; 
        $$.lch = setrch(&$1, &$2, 0); 
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;

// <<<<<

/* Expressions >>>>> */

expr: binary_op {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
    | unary_op {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
    | func_call {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
    | array_ref {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
    | func_ref {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
    | IDENT {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | const {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, NULL);
    }/*<<<<<*/
    | parens {/*>>>>>*/
        $$.type = nt_expr;
        $$.lch = setrch(&$1, 0); 
    }/*<<<<<*/
;

/* For the Spring Brother's sake, bison's operator precedence won't work if I make it 'expr op expr' (and op for ADD|MINUS|...) */

binary_op: expr ADD expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr MINUS expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr MULTIPLY expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, NOSPC, 0);
    }/*<<<<<*/
    | expr DIVIDE expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, NOSPC, 0);
    }/*<<<<<*/
    | expr GREATER expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr LESS expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr EQCOMP expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr NEQ expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr GEQ expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr LEQ expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr AND expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
    | expr OR expr {/*>>>>>*/
        $$.type = nt_binary_op;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, 0, LRSPC, 0);
    }/*<<<<<*/
;

unary_op: ADD expr {/*>>>>>*/
        $$.type = nt_unary_op;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, NOSPC, 0);
    }/*<<<<<*/
    | MINUS expr {/*>>>>>*/
        $$.type = nt_unary_op;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, NOSPC, 0);
    }/*<<<<<*/
    | NOT expr {/*>>>>>*/
        $$.type = nt_unary_op;
        $$.lch = setrch(&$1, &$2, NULL);
        setspc($$.lch, RSPC, 0);
    }/*<<<<<*/
;


func_call: IDENT LPAREN args RPAREN {/*>>>>>*/
        $$.type = nt_func_call; 
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        //if($3.lch->rch->type == empty) { // FIXME: double space in some circumstances
        setspc($$.lch, NOSPC, NOSPC, 0, NOSPC);
        //} else { 
        //    //setspc($$.lch, NOSPC, RSPC, 0, LSPC);
        //    setspc($$.lch, LSPC, NOSPC, 0, RSPC);
        //} 
    }/*<<<<<*/
    | IDENT LPAREN RPAREN {/*>>>>>*/
        $$.type = nt_func_call;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, NOSPC, NOSPC, NOSPC);
    }/*<<<<<*/
;

array_ref: IDENT LBRACKET expr RBRACKET {/*>>>>>*/
        $$.type = nt_array_ref;
        $$.lch = setrch(&$1, &$2, &$3, &$4, NULL);
        setspc($$.lch, NOSPC, NOSPC, 0, NOSPC);
    }/*<<<<<*/
;

func_ref: FUNCTION IDENT {/*>>>>>*/
        $$.type = nt_func_ref;
        $$.lch = setrch(&$1, &$2, NULL);
         setspc($$.lch, RSPC, NOSPC);
    }/*<<<<<*/
;

const: INTLIT {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | REALLIT {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | BOOLLIT {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | STRINGLIT {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | UNITTYPELIT {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | TNULL {/*>>>>>*/
        $$.type = nt_const;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
;

parens: LPAREN expr RPAREN {/*>>>>>*/
        $$.type = nt_parens;
        $$.lch = setrch(&$1, &$2, &$3, NULL);
        setspc($$.lch, NOSPC, 0, NOSPC);
    }/*<<<<<*/

;

type: IDENT {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | CODE {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | HANDLE {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | INTEGER {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, 0); 
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | REAL {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | BOOLEAN {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, RSPC);
    }/*<<<<<*/
    | STRING {/*>>>>>*/
        $$.type = nt_type;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, RSPC);
    }/*<<<<<*/
;

newline: LINEFEED {/*>>>>>*/ 
        $$.type = nt_newline;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
    | COMMENT {/*>>>>>*/ 
        $$.type = nt_newline;
        $$.lch = setrch(&$1, NULL);
        setspc($$.lch, NOSPC);
    }/*<<<<<*/
;

// <<<<<

%%

void jasserror(char *s)/*>>>>>*/
{
    printf("Parse error: %s, line: %d\n", s, jasslineno);
}/*<<<<<*/

#define INITIAL_SIZE 4096
struct JASSSTYPE *semdup(struct JASSSTYPE *r)/*>>>>>*/ 
{
    static struct JASSSTYPE *pool[30] = {};
    static int pp = -1;
    static int ptr = -1;
    
    if(r == (struct JASSSTYPE*)-1) {
        //destroy all the things
        int i;
        for(i = 0; i <= pp; i++) {
            free(pool[i]);
        }

        pp = ptr = -1;
        return NULL;
    }

    if(pp == -1) {
        pp = 0;
        pool[pp] = malloc(INITIAL_SIZE * sizeof(struct JASSSTYPE));
        memset(pool[pp], 0, INITIAL_SIZE * sizeof(struct JASSSTYPE));
    }
    
    ptr++;
    if(ptr >= INITIAL_SIZE<<pp ) {
        pp++;
        ptr = 0;
        pool[pp] = malloc((INITIAL_SIZE<<pp) * sizeof(struct JASSSTYPE));    
        memset(pool[pp], 0, (INITIAL_SIZE<<pp) * sizeof(struct JASSSTYPE));
    }
    
    pool[pp][ptr].type = r->type;
    pool[pp][ptr].lch = r->lch;
    pool[pp][ptr].rch = r->rch;
    pool[pp][ptr].pch = r->pch;
    pool[pp][ptr].lineno = r->lineno;

    
    if(pool[pp][ptr].type > end_of_nt) // if it is greater than end_of_int, then it is something in [enum yytokentype]
        pool[pp][ptr].str = r->str;

    return &pool[pp][ptr];
    
}/*<<<<<*/
#undef INITIAL_SIZE

void setpch(struct JASSSTYPE *c)/*>>>>>*/ 
{
    struct JASSSTYPE *p;
    if(c->lch) {
        for(p = c->lch; p; p = p->rch) {
            p->pch = c;
        }
    }
}/*<<<<<*/
struct JASSSTYPE* setrch(struct JASSSTYPE *head, ...)/*>>>>>*/
{
    struct JASSSTYPE *c, *n;
    va_list l;    

    head = semdup(head);
    c = head;
    va_start(l, head);
    for(n = va_arg(l, struct JASSSTYPE*); n != NULL; c = n, n = va_arg(l, struct JASSSTYPE*)) {
        c->rch = (n = semdup(n));
        setpch(n);
    }
    c->rch = 0;
    setpch(head);
    va_end(l);

    return head;
    
}/*<<<<<*/
void setspc(struct JASSSTYPE *head, ...)/*>>>>>*/
{
    struct JASSSTYPE *p;
    va_list l;

    va_start(l, head);
    for(p = head; p; p = p->rch) {
        p->spc = va_arg(l, int);
    }
    va_end(l);
}/*<<<<<*/
void setindent(struct JASSSTYPE *head, ...)/*>>>>>*/
{
    struct JASSSTYPE *p;
    va_list l;

    va_start(l, head);
    for(p = head; p; p = p->rch) {
        p->indent = va_arg(l, int);
    }
    va_end(l);
}/*<<<<<*/
void setlfeed(struct JASSSTYPE *head, ...)/*>>>>>*/
{
    struct JASSSTYPE *p;
    va_list l;

    va_start(l, head);
    for(p = head; p; p = p->rch) {
        p->lfeed = va_arg(l, int);
    }
    va_end(l);

}/*<<<<<*/
int addlocalvars(struct hashtable *h, struct JASSSTYPE *n)/*>>>>>*/
{
    int _addlocalvars(struct hashtable *h, struct JASSSTYPE *n, struct JASSSTYPE *o); 
    return _addlocalvars(h, n, n);
}

int _addlocalvars(struct hashtable *h, struct JASSSTYPE *n, struct JASSSTYPE *o) 
{
    static char *funcname;
    if(n && n->type != nt_statement_list) {
        if(n->type == nt_func_declr) {
            funcname = n->lch->str;
        }

        if(!_addlocalvars(h, n->lch, o))
            return 0;
        
        if(n->type == nt_type && n->pch->type != nt_func_returns) {
            struct JASSSTYPE *p;
            if(n->rch->type == IDENT) {
                p = n->rch;
            } else if(n->rch->type == ARRAY && n->rch->rch->type == IDENT) {
                p = n->rch->rch;
            } else {
                printf("?? What? what's the damn thing following a 'type' nonterminal?\n");
                return 0;
            }

            /* There DOES allow parameter and local variable to use a same varname >>>>> 
            if(!put(h, p->str, o, NULL)) {
                printf("!! It seems that there are more than one localvar/parameter called '%s' in function '%s' o_O\n", n->str, funcname);
                return 0;
            }
            <<<<< */

            // And it also holds true for global vars and local vars, oops *_*
            // Local vars have a higher priority than global vars
            if(lookup(&jassglobals, p->str)) {
                printf(">> In function '%s': local var '%s' has a same name with a global var (allowed but should notice).\n", funcname, p->str);
            }

            put(h, p->str, o, NULL);
            allname_add(p->str);
        }
        return _addlocalvars(h, n->rch, o);

    } else {
        return 1;
    }
}/*<<<<<*/

// vim: set tabstop=4 foldmethod=marker foldmarker=>>>>>,<<<<<:

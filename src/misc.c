#include <stdio.h>
#include <malloc.h>
#include <string.h>

#include <unistd.h>

#include "jass.h"
#include "../jass.tab.h"
#include "misc.h"

#include <readline/readline.h>
#include <readline/history.h>

extern FILE *jassin;
char *filename;
char *commandstring;

struct JASSSTYPE *handle;

struct hashtable jassfuncs;
struct hashtable jassglobals;
struct hashtable jassallname;

struct idtable unitidtable;

int runcmd(char *s);
struct JASSSTYPE *semdup(struct JASSSTYPE * r);

enum toolkit_status tkstatus = STATUS_INITIAL;

int hashfunc(const char *name)/*>>>>>*/
{
    int h = 0;
    const char *s;
    for (s = name; *s; ++s)
    h = ((811 * h + (*s)) % 19205861);
    return ((h % BUCKETS) + BUCKETS) % BUCKETS;
}/*<<<<<*/

struct hashnode *lookup(struct hashtable *h, const char *name)/*>>>>>*/
{
    struct hashnode *hn;
    int hf = hashfunc(name);
    hn = h->h[hf];
    while (hn) {
    if (strcmp(hn->name, name) == 0)
        return hn;
    hn = hn->next;
    }
    return NULL;
}/*<<<<<*/

void hashwalk(struct hashtable *h, void (*f) (struct hashnode *))/*>>>>>*/
{
    int i;
    struct hashnode *n;
    for (i = 0; i < BUCKETS; i++) {
    if (h->h[i]) {
        for (n = h->h[i]; n; n = n->next) {
        f(n);
        }
    }
    }
}/*<<<<<*/

extern void hashremove(struct hashtable *h, const char *name)/*>>>>>*/
{
    struct hashnode *hn;

    hn = lookup(h, name);
    if(hn) hn->name[0] = 0; // FIXME: just a hack
}/*<<<<<*/

int put(struct hashtable *h, const char *name, struct JASSSTYPE * p, struct hashtable *vars)/*>>>>>*/
{
    struct hashnode *hn;
    int hf;

    if (lookup(h, name) != NULL) {
    return 0;
    }
    hf = hashfunc(name);
    hn = calloc(sizeof(struct hashnode), 1);
    hn->name = strdup(name);
    hn->handle = p;
    hn->vars = vars;
    hn->next = h->h[hf];
    h->h[hf] = hn;

    return 1;
}/*<<<<<*/

void clear(struct hashtable *h)/*>>>>>*/
{
    int i;
    struct hashnode *hn;
    for (i = 0; i < BUCKETS; ++i) {
    hn = h->h[i];
    while (hn) {
        struct hashnode *tofree = hn;
        hn = hn->next;
        free(tofree->name);

        if (tofree->vars) {
        clear(tofree->vars);
        free(tofree->vars);
        }

        free(tofree);
    }
    h->h[i] = NULL;
    }
}/*<<<<<*/

struct JASSSTYPE *treewalk(struct JASSSTYPE *n, int (*filter)(struct JASSSTYPE *, void *), void *arg)/*>>>>>*/
{
    if(n) {
        struct JASSSTYPE *p;
        if( (p = treewalk(n->lch, filter, arg)) ) {
            return p;
        }
        if(filter(n, arg)) {
            return n;
        }
        return treewalk(n->rch, filter, arg);
    } else {
        return 0;
    }
}/*<<<<<*/

struct JASSSTYPE *pre_treewalk(struct JASSSTYPE *n, int (*filter)(struct JASSSTYPE *, void *), void *arg)/*>>>>>*/
{
    if(n) {
        struct JASSSTYPE *p;
        if(filter(n, arg)) {
            return n;
        }
        if( (p = pre_treewalk(n->lch, filter, arg)) ) {
            return p;
        }
        return pre_treewalk(n->rch, filter, arg);
    } else {
        return 0;
    }
}/*<<<<<*/

static int pp_needindent = 0;
void _prettyprint(FILE * f, struct JASSSTYPE * n, int indent)/*>>>>>*/
{
    if (n) {
        _prettyprint(f, n->lch, indent);

        if (n->type == LINEFEED) {
            fprintf(f, "\n");
            pp_needindent = 1;
        } else if (n->type > end_of_nt && n->str) {
            if (n->lfeed == LLF || n->lfeed == LRLF) {
                int i;
                for (i = 0; i < indent; i++)
                    fprintf(f, "    ");
                fprintf(f, "\n");

            }

            if (pp_needindent) {
                int i;
                for (i = 0; i < indent; i++)
                    fprintf(f, "    ");
                pp_needindent = 0;
            }
            
            if(n->type == COMMENT) {
                pp_needindent = 1;
            }

            switch (n->spc) {
            case NOSPC:
                fprintf(f, "%s", n->str);
                break;

            case LSPC:
                fprintf(f, " %s", n->str);
                break;

            case RSPC:
                fprintf(f, "%s ", n->str);
                break;

            case LRSPC:
                fprintf(f, " %s ", n->str);
                break;

            default:
                fprintf(f, "Sth is wrong...");
                break;
            }

            if(n->type == UNITTYPELIT) {
                char *s;
                s = idlookup(*((int*)(&n->str[1])));
                if(s) {
                    fprintf(f, " /* %s */", s);
                }
            }
            if (n->lfeed == RLF || n->lfeed == LRLF) {
                int i;
                fprintf(f, "\n");
                for (i = 0; i < indent; i++)
                    fprintf(f, "    ");
            }
        }

        _prettyprint(f, n->rch, indent + n->indent);
            
    }
}

void prettyprint(FILE * f, struct JASSSTYPE * n)
{
    pp_needindent = 1;
    _prettyprint(f, n, 0);
}/*<<<<<*/

void _destroyjasstree(struct JASSSTYPE * p)/*>>>>>*/
{
    if (p) {
    _destroyjasstree(p->lch);
    if (p->str) {
        free(p->str);
        p->str = 0;
    }
    _destroyjasstree(p->rch);
    }
}

void destroyjasstree()
{
    _destroyjasstree(handle);
    semdup((void *) -1);
}/*<<<<<*/

int postparse_filter(struct JASSSTYPE *n, void *arg)/*>>>>>*/
{
    struct JASSSTYPE *n1;
    if(n->type == nt_parens) { // wipe unnecessary parentheses
        n1 = n->lch->rch->lch; // first child of the '(' [expr] <- this ')'
        if(n1->type != nt_binary_op &&
            n1->type != nt_unary_op ) { // if there is only one elem in paren
            free(n->lch->str); // LPAREN
            free(n->lch->rch->rch->str); // RPAREN
            n->lch->rch->pch = n->pch;
            n->lch->rch->rch = n->rch;
            *n = *(n->lch->rch);  // Replace parens with it's only child
        }
    } else if(n->type == nt_func_call) { // additional space for nested func_calls
        if((n1 = n->pch)->pch->type == nt_args) { // func_call -> expr -> args
            if(n1->rch->type == empty &&
            n->lch->rch->rch->type != RPAREN && // for short circuit, expr below will crash without this. [ foo() ] <- without param
            n->lch->rch->rch->lch->rch->type == nt_args_items) { // got these by ddd, really impressive tool
                // Yeah, it sucks :(
                // it means the circumstance below
                // a(b(x,y)) -> a( b(x,y) )
                // a(b()) a(b(x)) a(b(x,y), z) does not include
                n1 = n->lch;   // first child of func_call
                n1->spc = LSPC; // the IDENT
                n1->rch->rch->rch->spc = RSPC; // the RPAREN
            }
        }
   }
   return 0;
}/*<<<<<*/

int postparse_trimming(void)/*>>>>>*/
{
    return treewalk(handle, postparse_filter, 0) ? 0 : 1;
}/*<<<<<*/

int parsefile(char *file)/*>>>>>*/
{
    jasslex_destroy();
    printf(":: Opening file '%s'...\n", file);
    jassin = fopen(file, "r");
    if (!jassin) {
        printf("!! Unable to open '%s'.\n", file);
        return 0;
    } else {
        printf(":: Parsing...\n");
        if (!jassparse()) {
            printf(":: Post parse trimming...\n");
            fclose(jassin);
            if(!postparse_trimming()) {
                printf("!! Trim failed (WTF?!)\n");
                return 0;
            }
            printf(":: Done.\n");
            if (filename)
                free(filename);
            filename = strdup(file);
            return 1;
        } else {
            printf("!! Parse failed.\n");
            fclose(jassin);
            return 0;
        }
    }
}/*<<<<<*/

void notimpl()/*>>>>>*/
{
    printf("Sorry, but this feature is not yet implemented :(\n");
}/*<<<<<*/

void allname_add(const char *s)/*>>>>>*/
{
    struct hashnode *n;

    n = lookup(&jassallname, s);
    if(!n) {
        put(&jassallname, s, (void *)1, NULL);
    } else {
        n->handle = (void *)((long)(n->handle) + 1);
    }

}

void allname_remove(const char *s)
{
    struct hashnode *n;
    n = lookup(&jassallname, s);
    if(!n) return;
    
    n->handle = (void*)((long)(n->handle) - 1);
}

struct hashnode *allname_lookup(const char *s)
{
    struct hashnode *n;
    n = lookup(&jassallname, s);
    if(n && n->handle)
        return n;
    else
        return NULL;
}/*<<<<<*/

int main(int argc, char *argv[])/*>>>>>*/
{
    char *c;

    printf("Proton's Jass Scripting Toolkit V1.0\n"
       "Written by Proton, 2010\n"
       "If you have any questions, please mail feisuzhu@163.com\n"
       "\n"
       "If you are new to this tool, try 'help'\n"
    );

    if (argc > 1) {
    if (parsefile(argv[1]))
        tkstatus = STATUS_PARSED;
    }

    while ( (c = readline("jtool> ")) ) {
        if(strlen(c)) {
            add_history(c);
            commandstring ? free(commandstring) : 0;
            commandstring = c;
        }
        runcmd(c); // cmd parser counts empty lines
    }
    printf("\n");
    return 0;
}/*<<<<<*/

void idadd(int id, const char *s)/*>>>>>*/
{
    int slot;
    struct idtableelem *pre, *n;

    slot = id % BUCKETS;
    pre = unitidtable.h[slot];
    n = malloc(sizeof(struct idtableelem));
    memset(n, 0, sizeof(struct idtableelem));
    n->id = id;
    n->str = strdup(s);
    n->next = pre;
    unitidtable.h[slot] = n;
}/*<<<<<*/

char *idlookup(int id)/*>>>>>*/
{
    int slot;
    struct idtableelem *p;

    slot = id % BUCKETS;
    p = unitidtable.h[slot];
    while(p) {
        if(p->id == id) {
            return p->str;
        }
        p = p->next;
    }
    return NULL;
}/*<<<<<*/

void idtabledestroy(void)/*>>>>>*/
{
    int i;
    struct idtableelem *p, *p1;
    for(i=0; i<BUCKETS; i++) {
        p = unitidtable.h[i];
        while(p) {
            p1 = p->next;
            free(p->str);
            free(p);
            p = p1;
        }
        unitidtable.h[i] = NULL;
    }
}/*<<<<<*/

// vim: foldmethod=marker foldmarker=>>>>>,<<<<<:

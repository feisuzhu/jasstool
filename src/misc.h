enum toolkit_status {
    STATUS_INITIAL = 1,
    STATUS_PARSED,
    STATUS_MODIFIED
};

void notimpl();

int parsefile(char *file);
void destroyjasstree();

extern enum toolkit_status tkstatus;

extern char *filename;
extern char *commandstring;

extern struct JASSSTYPE *handle;

#define BUCKETS 577

struct hashnode {
    char *name;

    struct JASSSTYPE *handle;
    struct hashtable *vars;

    struct hashnode *next;
};

struct hashtable {
    struct hashnode *h[BUCKETS];
};

struct idtableelem {
    int id;
    char *str;
    struct idtableelem *next;
};

struct idtable {
    struct idtableelem *h[BUCKETS];
};

extern struct hashtable jassglobals;
extern struct hashtable jassfuncs;
extern struct hashtable jassallname;
extern struct idtable unitidtable;

extern struct hashnode *lookup(struct hashtable *h, const char *name);
extern int put(struct hashtable *h, const char *name, struct JASSSTYPE * p,
     struct hashtable *vars);
extern void clear(struct hashtable *h);
extern void hashwalk(struct hashtable *h, void (*f)(struct hashnode *));
extern void hashremove(struct hashtable *h, const char *name);

extern void allname_add(const char *s);
extern void allname_remove(const char *s);
extern struct hashnode *allname_lookup(const char *s);

extern void idadd(int id, const char *s);
extern char *idlookup(int id);
extern void idtabledestroy(void);

extern void prettyprint(FILE * f, struct JASSSTYPE * n);
extern struct JASSSTYPE *treewalk(struct JASSSTYPE *n, int (*filter)(struct JASSSTYPE *, void *), void *arg);
extern struct JASSSTYPE *pre_treewalk(struct JASSSTYPE *n, int (*filter)(struct JASSSTYPE *, void *), void *arg);

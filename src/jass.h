
enum tokentype {
    nt_program = 1,
    nt_files,
    nt_file,
    nt_newlines,
    nt_declrs,
    nt_funcs,
    nt_declr,
    nt_typedef,
    nt_globals,
    nt_global_var_list,
    nt_global_var_list_item,
    nt_native_func,
    nt_func_declr,
    nt_func_takes,
    nt_func_returns,
    nt_param_list,
    nt_param_list_item,
    nt_param_list_item_with_comma,
    nt_func,
    nt_local_var_list,
    nt_local_var_list_item,
    nt_var_declr,
    nt_var_declr_initval,
    nt_statement_list,
    nt_statement,
    nt_set,
    nt_call,
    nt_args,
    nt_args_items,
    nt_ifthenelse,
    nt_else_clause,
    nt_loop,
    nt_exitwhen,
    nt_return,
    nt_debug,
    nt_expr,
    nt_binary_op,
    nt_unary_op,
    nt_func_call,
    nt_array_ref,
    nt_func_ref,
    nt_const,
    nt_parens,
    nt_type,
    nt_newline,
    empty,
    end_of_nt
};

enum spacetype {
    NOSPC = 1,    // no space
    LSPC,        // left space
    RSPC,        // right space
    LRSPC        // left & right space
};

enum linefeedtype {
    NOLF = 1,    // no linefeed
    LLF,        // left linefeed
    RLF,        // right linefeed
    LRLF        // left & right linefeed
};


struct JASSSTYPE {
    struct JASSSTYPE *lch;
    struct JASSSTYPE *rch;
    struct JASSSTYPE *pch;
    char *str;
    enum tokentype type;
    
    // for pretty printing
    enum spacetype spc:16;
    enum linefeedtype lfeed:16;
    int indent;
    int lineno;
};

extern struct JASSSTYPE *handle;
extern int jasslineno;

extern int jassparse(void);
extern int jasslex_destroy(void);
extern int jasslex(void);
extern struct JASSSTYPE *semdup(struct JASSSTYPE *r);

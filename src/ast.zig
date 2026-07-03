const std = @import("std");

//////////// Program Block

const ProgramDeclTag = enum {
    // struct_,
    fn_,
};

pub const ProgramDecl = union(ProgramDeclTag) {
    fn_: FnDecl,
};

const FnDecl = struct {
    name: []const u8,
    args: std.ArrayList(Expr),
    body: std.ArrayList(Stmt),
};

//////////// Expr structs

const ExprTag = enum {
    arith,
    bool_,
};

const Expr = union(ExprTag) {
    arith: ArithExpr,
    bool_: BoolExpr,
};


const ArithExpr = struct {
    value: i32,
};

const BoolExpr = struct {
    value: bool,
};

const StmtTag = enum {
    assign,
};

//////////// Stmt structs
const Stmt = union(StmtTag) {
    assign: AssignStmt,
};

const AssignStmt = struct {
    var_: []const u8,
    value: Expr,
};

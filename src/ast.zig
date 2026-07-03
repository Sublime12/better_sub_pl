const std = @import("std");

//////////// Expr structs

const ExprTag = enum {
    arith,
    bool_,
    fn_,
};

const Expr = union(ExprTag) {
    arith: ArithExpr,
    bool_: BoolExpr,
    fn_: FnExpr,
};

const FnExpr = struct {
    name: []const u8,
    args: std.ArrayList(Expr),
    body: std.ArrayList(Stmt),
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
const Stmt = union (StmtTag) {
    assign: AssignStmt,
};

const AssignStmt = struct {
    var_: []const u8,
    value: Expr,
};

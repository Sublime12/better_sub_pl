const std = @import("std");

//////////// Program Block

const ProgramDeclTag = enum {
    // struct_,
    fn_,
};

pub const ProgramDecl = union(ProgramDeclTag) {
    fn_: FnDecl,

    pub fn create_fn(
        name: []const u8,
        args: std.ArrayList([]const u8),
        body: std.ArrayList(Stmt),
        return_type: []const u8,
    ) ProgramDecl {
        return  .{ .fn_ = .{
            .name = name, 
            .args = args,
            .body = body,
            .return_type = return_type,
        }};
    }
};

const FnDecl = struct {
    name: []const u8,
    args: std.ArrayList([]const u8),
    body: std.ArrayList(Stmt),
    return_type: []const u8,
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
pub const Stmt = union(StmtTag) {
    assign: AssignStmt,
};

const AssignStmt = struct {
    var_: []const u8,
    value: Expr,
};

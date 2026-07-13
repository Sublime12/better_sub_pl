const std = @import("std");

const Allocator = std.mem.Allocator;

const ast_pkg = @import("ast.zig");

const Ast = ast_pkg.Ast;
const FnDecl = ast_pkg.FnDecl;
const Arg = ast_pkg.Arg;
const Expr = ast_pkg.Expr;
const BlockStmt = ast_pkg.BlockStmt;

const panic = std.debug.panic;

pub fn sema(alloc: Allocator, ast: *const Ast) !void {
    // undeclared var

    for (ast.decls.items) |decl| {
        switch(decl) {
            .fn_decl => |fn_decl| try sema_fn_decl(alloc, fn_decl),
        }
    }
}

fn sema_fn_decl(alloc: Allocator, fn_decl: FnDecl) !void {
    var decl_vars: std.ArrayList(Arg) = .empty;
    defer decl_vars.deinit(alloc);

    try decl_vars.appendSlice(alloc, fn_decl.args.items);

    try sema_block(alloc, fn_decl.body, &decl_vars);
}

fn sema_block(alloc: Allocator, block: BlockStmt, decl_vars: *std.ArrayList(Arg)) !void {
    const length = decl_vars.items.len;
    // remove added elements on out
    defer decl_vars.items.len = length;
    for (block.stmts.items) |stmt| {
        switch (stmt) {
            .assign => |assign| {
                const arg: Arg = .{ .name = assign.var_, .type_ = assign.type_ ,};
                try decl_vars.append(alloc, arg);
            },
            .no_assign => |no_assign| sema_expr(no_assign.value, decl_vars),
            .if_ => |if_| {
                sema_expr(if_.if_eval, decl_vars);
                try sema_block(alloc, if_.if_body, decl_vars);
            },
        }
    }
}

fn sema_expr(expr: Expr, decl_vars: *std.ArrayList(Arg)) void {
    switch(expr) {
        .fn_call => |fn_call| {
            for (fn_call.args.items) |arg| {
                sema_expr(arg, decl_vars);
            }
        },
        .var_ => |var_| {
            if (!contains(decl_vars.items, var_)) {
                panic("use of undeclared var: {s}", .{var_});
            }
        },
        .arith, .bool_, .str => unreachable,
    }
}

fn contains(args: []const Arg, needle: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg.name, needle)) return true;
    }
    return false;
}

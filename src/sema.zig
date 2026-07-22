const std = @import("std");
const builtin = @import("builtin");

const ast_pkg = @import("ast.zig");
const types_pkg = @import("type.zig");
const errors_pkg = @import("errors.zig");

const Allocator = std.mem.Allocator;

const Ast = ast_pkg.Ast;
const FnDecl = ast_pkg.FnDecl;
const Arg = ast_pkg.Arg;
const Expr = ast_pkg.Expr;
const BlockStmt = ast_pkg.BlockStmt;
const Type = types_pkg.Type;

const panic = std.debug.panic;
const print_error_line = errors_pkg.print_error_line;

pub const SemaErr = error{
    OutOfMemory,
    CallUnknownFunction,
    UndeclaredVar,
};

pub fn sema(alloc: Allocator, ast: *const Ast, types: *std.ArrayList(Type)) SemaErr!void {
    try register_common_types(alloc, types);

    var fn_names: std.ArrayList([]const u8) = .empty;
    defer fn_names.deinit(alloc);
    // register fn names
    for (ast.decls.items) |decl| {
        switch (decl) {
            .fn_decl => |fn_decl| {
                try fn_names.append(alloc, fn_decl.name);
            },
        }
    }

    for (ast.decls.items) |decl| {
        switch (decl) {
            .fn_decl => |fn_decl| try sema_fn_decl(alloc, fn_decl, fn_names),
        }
    }
}

fn sema_fn_decl(
    alloc: Allocator,
    fn_decl: FnDecl,
    fn_names: std.ArrayList([]const u8),
) !void {
    var decl_vars: std.ArrayList(Arg) = .empty;
    defer decl_vars.deinit(alloc);

    try decl_vars.appendSlice(alloc, fn_decl.args.items);

    try sema_block(alloc, fn_decl.body, &decl_vars, fn_names);
}

fn sema_block(
    alloc: Allocator,
    block: BlockStmt,
    decl_vars: *std.ArrayList(Arg),
    fn_names: std.ArrayList([]const u8),
) !void {
    const length = decl_vars.items.len;
    // remove added elements on out
    defer decl_vars.items.len = length;
    for (block.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |assign| {
                const arg: Arg = .{
                    .name = assign.var_,
                    .type_ = assign.type_,
                };
                try decl_vars.append(alloc, arg);
            },
            .assign => unreachable,
            .no_assign => |no_assign| try sema_expr(no_assign.rvalue, decl_vars, fn_names),
            .if_ => |if_| {
                try sema_expr(if_.if_eval, decl_vars, fn_names);
                try sema_block(alloc, if_.if_body, decl_vars, fn_names);
            },
        }
    }
}

fn sema_expr(
    expr: Expr,
    decl_vars: *std.ArrayList(Arg),
    funs: std.ArrayList([]const u8),
) SemaErr!void {
    switch (expr.as) {
        .fn_call => |fn_call| {
            if (!contains_str(funs.items, fn_call.name)) {
                print_error_line(
                    "call to undefined function: {s}",
                    .{
                        fn_call.name,
                    },
                    expr.file_path,
                    expr.file_content,
                    expr.cursor,
                );
                return SemaErr.CallUnknownFunction;
            }
            for (fn_call.args.items) |arg| {
                try sema_expr(arg, decl_vars, funs);
            }
        },
        .var_ => |var_| {
            if (!contains(decl_vars.items, var_)) {
                print_error_line(
                    "use of undeclared var: {s}",
                    .{
                        var_,
                    },
                    expr.file_path,
                    expr.file_content,
                    expr.cursor,
                );
                return SemaErr.UndeclaredVar;
            }
        },
        .arith, .bool_, .str => {},
    }
}

fn register_common_types(alloc: Allocator, types: *std.ArrayList(Type)) !void {
    const i32_t: Type = .{
        .name = "i32",
        .size = 4,
        .childrens = .empty,
    };
    try types.append(alloc, i32_t);
}

fn contains_str(args: [][]const u8, needle: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, needle)) return true;
    }
    return false;
}

fn contains(args: []const Arg, needle: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg.name, needle)) return true;
    }
    return false;
}

const std = @import("std");

const ast_pkg = @import("ast.zig");
const types_pkg = @import("type.zig");
const sema_pkg = @import("sema.zig");

const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const Type = types_pkg.Type;

const Ast = ast_pkg.Ast;
const FnDecl = ast_pkg.FnDecl;
const FnCallExpr = ast_pkg.FnCallExpr;
const SemaResult = sema_pkg.SemaResult;

const assert = std.debug.assert;
const panic = std.debug.panic;

pub fn gen(alloc: Allocator, w: *Writer, ast: Ast, sema: SemaResult) !void {
    print(
        w,
        \\.intel_syntax noprefix
        \\.global _start
        \\
        \\.text
        \\_start:
        \\  call main
        \\  mov eax, 60
        \\  xor edi, edi
        \\  syscall
        \\
    ,
        .{},
    );

    for (ast.decls.items) |decl| {
        switch (decl) {
            .fn_decl => |fn_decl| try gen_fn(alloc, w, fn_decl, sema),
        }
    }
}

const Var = struct {
    name: []const u8,
    offset: usize,

    pub fn create(name: []const u8, offset: usize) Var {
        return .{ .name = name, .offset = offset };
    }
};

fn gen_fn(alloc: Allocator, w: *Writer, fn_decl: FnDecl, sema: SemaResult) !void {
    print(w, "{s}:\n", .{fn_decl.fn_sign.name});

    const prelude =
        \\  push rbp
        \\  mov rbp, rsp
        \\
    ;
    print(w, "{s}", .{prelude});

    assert(fn_decl.fn_sign.args.items.len == 0);

    var vars: std.ArrayList(Var) = .empty;
    var current_offset: usize = 0;

    for (fn_decl.body.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |var_decl| {
                // assert(std.mem.eql(u8, var_decl.type_, "i32"));
                const type_ = get_type(sema.types.items, var_decl.type_);
                if (type_ == null) {
                    std.debug.panic("type {s} not found", .{var_decl.type_});
                }
                current_offset += type_.?.size;
                const var_ = Var.create(var_decl.var_, current_offset);
                try vars.append(alloc, var_);
            },
            .if_ => panic("gen not implemented for if_", .{}),
            .assign, .no_assign => {},
        }
    }

    print(w, "  sub rsp, {}\n", .{current_offset});

    for (fn_decl.body.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |decl_assign| {
                // assert(std.meta.activeTag(decl_assign.value.as) == .arith);
                switch (decl_assign.value.as) {
                    .arith => |arith| {
                        const var_ = get_var(vars.items, decl_assign.var_);
                        const type_ = get_type(sema.types.items, decl_assign.type_);
                        assert(var_ != null);
                        assert(type_ != null);
                        print(w, "  mov {s} ptr [rbp - {}], {}\n", .{
                            size_mov(type_.?.size),
                            var_.?.offset,
                            arith.value,
                        });
                    },
                    .fn_call => |fn_call| {
                        try gen_fn_call_expr(alloc, w, fn_call, sema);
                    },
                    .bool_, .str, .var_ => unreachable,
                }
            },
            else => {},
        }
    }

    const teardown =
        \\  mov rsp, rbp
        \\  pop rbp
        \\  ret
        \\
    ;
    print(w, "{s}", .{teardown});
}

fn gen_fn_call_expr(alloc: Allocator, w: *Writer, fn_call: FnCallExpr, sema: SemaResult) !void {
    // alloc all params in current stack
    // just return value in parent stack
    _ = alloc;
    _ = w;
    _ = fn_call;
    _ = sema;
    unreachable;
}

fn size_mov(size: usize) []const u8 {
    return switch (size) {
        1 => "byte",
        4 => "dword",
        else => panic("mov prefix not defined for {}", .{size}),
    };
}

fn get_type(types: []const Type, needle: []const u8) ?Type {
    if (types.len == 0) return null;
    var i: usize = types.len - 1;
    while (i >= 0) {
        const cur = types[i];
        if (std.mem.eql(u8, cur.name, needle)) return cur;
        i -= 1;
    }
    return null;
}

fn get_var(vars: []const Var, needle: []const u8) ?Var {
    var i: usize = vars.len - 1;
    while (i >= 0) {
        const cur = vars[i];
        if (std.mem.eql(u8, cur.name, needle)) return cur;
        i -= 1;
    }
    return null;
}

fn print(w: *Writer, comptime fmt: []const u8, args: anytype) void {
    w.print(fmt, args) catch unreachable;
}

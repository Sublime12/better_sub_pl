const std = @import("std");

const ast_pkg = @import("ast.zig");

const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

const Ast = ast_pkg.Ast;
const FnDecl = ast_pkg.FnDecl;

const assert = std.debug.assert;
const panic = std.debug.panic;

pub fn gen(alloc: Allocator, w: *Writer, ast: Ast) !void {
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
            .fn_decl => |fn_decl| try gen_fn(alloc, w, fn_decl),
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

fn gen_fn(alloc: Allocator, w: *Writer, fn_decl: FnDecl) !void {
    print(w, "{s}:\n", .{fn_decl.name});

    const prelude =
        \\  push rbp
        \\  mov rbp, rsp
        \\
    ;
    print(w, "{s}", .{prelude});

    assert(fn_decl.args.items.len == 0);

    var vars: std.ArrayList(Var) = .empty;
    var current_offset: usize = 0;

    for (fn_decl.body.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |var_decl| {
                assert(std.mem.eql(u8, var_decl.type_, "i32"));
                current_offset += 4;
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
                assert(std.meta.activeTag(decl_assign.value.as) == .arith);
                const var_ = get_var(vars.items, decl_assign.var_);
                assert(var_ != null);
                print(w, "  mov dword ptr [rbp - {}], {}\n", .{
                    var_.?.offset,
                    decl_assign.value.as.arith.value,
                });
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

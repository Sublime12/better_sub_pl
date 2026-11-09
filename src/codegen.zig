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
        \\put_char:
        \\  push rbp
        \\  mov rbp, rsp
        \\  mov eax, 1
        \\  mov edi, 1
        \\  lea rsi, [rbp + 16]
        \\  mov edx, 1
        \\  syscall
        \\  mov rsp, rbp
        \\  pop rbp
        \\  ret
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

    var vars: std.ArrayList(Var) = .empty;
    var current_offset: usize = 0;

    for (fn_decl.body.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |var_decl| {
                const type_ = get_type(sema.types.items, var_decl.type_);
                if (type_ == null) {
                    panic("type {s} not found", .{var_decl.type_});
                }
                current_offset += type_.?.size;
                const var_ = Var.create(var_decl.var_, current_offset);
                try vars.append(alloc, var_);
            },
            .no_assign => {},
            .if_, .assign => panic("gen not implemented for if_", .{}),
        }
    }

    print(w, "  sub rsp, {}\n", .{current_offset});

    for (fn_decl.body.stmts.items) |stmt| {
        switch (stmt) {
            .declare_and_assign => |decl_assign| {
                switch (decl_assign.value.as) {
                    .arith => |arith| {
                        const var_ = get_var(vars.items, decl_assign.var_);
                        const type_ = get_type(sema.types.items, decl_assign.type_);
                        assert(var_ != null);
                        assert(type_ != null);
                        print(w, "  mov {s} ptr [rbp - {}], {}\n", .{
                            size_mov(type_.?.size),
                            var_.?.offset,
                            arith.i32_value,
                        });
                    },
                    .fn_call => |fn_call| {
                        try gen_fn_call_expr(alloc, w, fn_call, sema);
                    },
                    .bool_, .str, .var_ => panic("panic with {}", .{std.meta.activeTag(decl_assign.value.as)}),
                }
            },
            .no_assign => |no_assign| {
                switch (no_assign.rvalue.as) {
                    .fn_call => |fn_call| try gen_fn_call_expr(alloc, w, fn_call, sema),
                    .arith, .bool_, .str, .var_ => panic(
                        "panic with {}",
                        .{std.meta.activeTag(no_assign.rvalue.as)},
                    ),
                }
            },
            .if_, .assign => panic("gen not implemented for if_", .{}),
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
    _ = alloc;
    _ = sema;

    var offset: usize = 0;

    print(w, "  sub rsp, 16\n", .{});
    for (fn_call.args.items) |arg| {
        assert(std.meta.activeTag(arg.as) == .arith);
        const i32_value = arg.as.arith.i32_value;
        print(w, "  mov byte ptr [rsp + {}], {}\n", .{ offset, i32_value });
        offset += 4;
    }
    print(w, "  call {s}\n", .{fn_call.name});
    print(w, "  add rsp, 16\n", .{});
}

fn size_mov(size: usize) []const u8 {
    return switch (size) {
        1 => "byte",
        4 => "dword",
        else => panic("mov prefix not defined for {}", .{size}),
    };
}

fn get_type(types: []const Type, needle: []const u8) ?Type {
    var i: usize = types.len;
    while (i > 0) {
        i -= 1;
        const cur = types[i];
        if (std.mem.eql(u8, cur.name, needle)) return cur;
    }
    return null;
}

fn get_var(vars: []const Var, needle: []const u8) ?Var {
    var i: usize = vars.len;
    while (i > 0) {
        i -= 1;
        const cur = vars[i];
        if (std.mem.eql(u8, cur.name, needle)) return cur;
    }
    return null;
}

fn print(w: *Writer, comptime fmt: []const u8, args: anytype) void {
    w.print(fmt, args) catch unreachable;
}

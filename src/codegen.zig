const std = @import("std");

const ast_pkg = @import("ast.zig");

const Writer = std.Io.Writer;
const Ast = ast_pkg.Ast;

pub fn gen(w: *Writer, ast: Ast) void {
    _ = ast;
    print(
        w,
        \\ .intel_syntax noprefix
        \\ .global _start
        \\
        \\ .text
        \\ _start:
    ,
        .{},
    );
}

fn print(w: *Writer, comptime fmt: []const u8, args: anytype) void {
    w.print(fmt, args) catch unreachable;
}

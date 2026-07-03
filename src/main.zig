const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const ast = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;

const LIMIT = 1024 * 10;

pub fn main(init: std.process.Init) !void {
    _ = ast;
    const io = init.io;
    const alloc = std.heap.page_allocator;

    const current_dir = std.Io.Dir.cwd();
    const content: []const u8 = try current_dir.readFileAlloc(
        io,
        "examples/helloworld.sub",
        alloc,
        .limited(LIMIT),
    );

    var l = Lexer.init(
        content,
        "main.sub",
    );

    while (l.next()) {
        std.debug.print("token: {}\n", .{l.token});
    }
}

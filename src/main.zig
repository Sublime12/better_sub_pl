const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const parser_pkg = @import("parser.zig");
const ast_pkg = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;
const Parser = parser_pkg.Parser;

const LIMIT = 1024 * 10;

pub fn main(init: std.process.Init) !void {
    _ = ast_pkg;
    const io = init.io;
    const alloc = std.heap.page_allocator;

    const current_dir = std.Io.Dir.cwd();
    const file_path = "examples/helloworld.sub";
    const content: []const u8 = try current_dir.readFileAlloc(
        io,
        file_path,
        alloc,
        .limited(LIMIT),
    );

    var l = Lexer.init(
        content,
        "main.sub",
    );
    var parser = Parser.init(&l, alloc);
    const ast = try parser.parse();

    ast.print();

    // while (l.next()) {
    //     std.debug.print("token: {}\n", .{l.token});
    // }
}

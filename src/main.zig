const std = @import("std");

const lexer_pkg = @import("lexer.zig");

const Lexer = lexer_pkg.Lexer;

pub fn main(init: std.process.Init) !void {
    _ = init;

    const content = "";
    var l = Lexer.init(content, "main.sub", );

    while (l.next()) {
        std.debug.print("token: {}\n", .{l.token});
    }
}

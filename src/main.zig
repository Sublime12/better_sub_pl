const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const parser_pkg = @import("parser.zig");
const sema_pkg = @import("sema.zig");

const Lexer = lexer_pkg.Lexer;
const SemaErr = sema_pkg.SemaErr;

const parse = parser_pkg.parse;
const sema = sema_pkg.sema;

const LIMIT = 1024 * 10;

const assert = std.debug.assert;

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;

    const args = try init.minimal.args.toSlice(alloc);
    assert(args.len == 2);
    const io = init.io;

    const current_dir = std.Io.Dir.cwd();
    const file_path = args[1];
    const content: []const u8 = try current_dir.readFileAlloc(
        io,
        file_path,
        alloc,
        .limited(LIMIT),
    );

    var l = Lexer.init(
        content,
        file_path,
    );

    const ast = try parse(&l, alloc);
    sema(alloc, &ast) catch |err| {
        switch (err) {
            SemaErr.UndeclaredVar => std.debug.print("Call to undeclared var", .{}),
            SemaErr.CallUnknownFunction => std.debug.print("unknowns function", .{}),
            SemaErr.OutOfMemory => return SemaErr.OutOfMemory, 
        }
        return;
    };

    ast.print();

    // while (l.next()) {
    //     std.debug.print("token: {}\n", .{l.token});
    // }
}

test {
    std.testing.refAllDecls(@This());
}

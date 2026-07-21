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

const Options = struct {
    sema: bool,
    file_path: ?[]const u8,
};

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;

    const args = try init.minimal.args.toSlice(alloc);
    const io = init.io;

    const current_dir = std.Io.Dir.cwd();
    // const file_path = args[1];

    var options: Options = .{ .sema = false, .file_path = null };
    parse_args(args, &options);
    const file_path = options.file_path.?;

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

    if (options.sema) {
        sema(alloc, &ast) catch |err| {
            switch (err) {
                SemaErr.UndeclaredVar => std.debug.print("Call to undeclared var", .{}),
                SemaErr.CallUnknownFunction => std.debug.print("unknowns function", .{}),
                SemaErr.OutOfMemory => return SemaErr.OutOfMemory,
            }
            return;
        };
    }

    var w: std.Io.Writer.Allocating = .init(alloc);
    ast.print(&w.writer);

    const text = w.toArrayList();
    std.debug.print("printed content: \n{s}\n", .{text.items});
}

fn parse_args(args: []const []const u8, options: *Options) void {
    var has_file_path = false;
    for (args, 0..) |arg, i| {
        if (i == 0) continue;

        if (std.mem.eql(u8, arg, "--sema")) {
            options.sema = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            std.debug.print("unknowns arg: {s}\n", .{arg});
            std.process.exit(1);
        } else if (std.ascii.isAlphabetic(arg[0])) {
            if (has_file_path) {
                std.debug.print("provided file_path 2 times\n", .{});
                std.process.exit(1);
            }
            has_file_path = true;
            options.file_path = arg;
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}

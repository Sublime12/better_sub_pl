const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const parser_pkg = @import("parser.zig");
const sema_pkg = @import("sema.zig");
const codegen_pkg = @import("codegen.zig");
const types_pkg = @import("type.zig");

const Lexer = lexer_pkg.Lexer;
const Type = types_pkg.Type;
const SemaErr = sema_pkg.SemaErr;

const parse = parser_pkg.parse;
const sema = sema_pkg.sema;
const gen = codegen_pkg.gen;

const LIMIT = 1024 * 10;

const assert = std.debug.assert;

const Options = struct {
    sema: bool,
    gen: bool,
    file_path: ?[]const u8,
};

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;

    const args = try init.minimal.args.toSlice(alloc);
    const io = init.io;

    const current_dir = std.Io.Dir.cwd();

    var options: Options = .{
        .sema = false,
        .gen = false,
        .file_path = null,
    };
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

    var types: std.ArrayList(Type) = .empty;

    if (options.sema) {
        sema(alloc, &ast, &types) catch |err| {
            switch (err) {
                SemaErr.UndeclaredVar => std.debug.print("Call to undeclared var", .{}),
                SemaErr.CallUnknownFunction => std.debug.print("unknowns function", .{}),
                SemaErr.OutOfMemory => return SemaErr.OutOfMemory,
            }
            return;
        };
    }

    var assembly: std.Io.Writer.Allocating = .init(alloc);

    if (options.gen) {
        try gen(alloc, &assembly.writer, ast, types);

        const program_text = assembly.toArrayList().items;
        std.debug.print("generated program: \n==========\n{s}\n", .{program_text});
        const BUILD_DIR = "build";
        const output_path = BUILD_DIR ++ "/output.s";
        current_dir.createDir(io, BUILD_DIR, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        try current_dir.writeFile(io, .{
            .data = program_text,
            .sub_path = output_path,
            .flags = .{ .truncate = true },
        });

        var as_child = try std.process.spawn(
            io,
            .{ .argv = &.{ "as", output_path, "-o", BUILD_DIR ++ "/output.o" } },
        );
        _ = try as_child.wait(io);
        var ld_child = try std.process.spawn(
            io,
            .{ .argv = &.{ "ld", BUILD_DIR ++ "/output.o", "-o", BUILD_DIR ++ "/output" } },
        );
        _ = try ld_child.wait(io);
    }

    var w: std.Io.Writer.Allocating = .init(alloc);
    ast.print(&w.writer);
}

fn parse_args(args: []const []const u8, options: *Options) void {
    var has_file_path = false;
    for (args, 0..) |arg, i| {
        if (i == 0) continue;

        if (std.mem.eql(u8, arg, "--sema")) {
            options.sema = true;
        } else if (std.mem.eql(u8, arg, "--gen")) {
            options.gen = true;
            // if --gen provided, do also the sema
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

    if (!has_file_path) {
        std.debug.print("filepath not provided\n", .{});
        std.process.exit(1);
    }
}

test {
    std.testing.refAllDecls(@This());
}

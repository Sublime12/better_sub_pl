const std = @import("std");
const builtin = @import("builtin");

const lexer_pkg = @import("lexer.zig");

const Cursor = lexer_pkg.Cursor;

const panic = std.debug.panic;

pub fn print_error_line(
    comptime fmt: []const u8,
    args: anytype,
    file_path: []const u8,
    content: []const u8,
    cursor: Cursor,
) void {
    var begin: usize = cursor.pos;
    var end: usize = cursor.pos;

    var nb_line: usize = 3;
    while (true) {
        if (begin == 0) break;
        if (content[begin] == '\n' and nb_line == 0) break;
        if (content[begin] == '\n') nb_line -= 1;
        begin -= 1;
    }
    while (begin > 0 and content[begin] != '\n') begin -= 1;

    while (end < content.len and content[end] != '\n') end += 1;

    const content_error = content[begin..end];
    // std.debug.print("{s}\n", .{content_error});

    const GREEN_TAG = "\x1b[32m";
    const RED_TAG = "\x1b[31m";
    const END_TAG = "\x1b[0m";
    std.debug.print(
        "\n" ++ GREEN_TAG ++ "{s}:{}:{}" ++ END_TAG ++ " ",
        .{
            file_path,
            cursor.row + 1,
            cursor.col,
        },
    );

    std.debug.print(fmt ++ "\n", args);
    std.debug.print("{s}\n", .{content_error});

    for (0..cursor.col - 1) |_| {
        std.debug.print(" ", .{});
    }
    std.debug.print(RED_TAG ++ "^" ++ END_TAG ++ "\n", .{});
}

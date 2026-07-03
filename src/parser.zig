const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const ast_pkg = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;
const Allocator = std.mem.Allocator;
const ProgramDecl = ast_pkg.ProgramDecl;

pub const Parser = struct {
    const Self = @This();

    l: *Lexer,
    alloc: Allocator,

    pub fn init(l: *Lexer, alloc: Allocator) Self {
        return .{
            .l = l,
            .alloc = alloc,
        };
    }

    pub fn parse(self: *Self) std.ArrayList(ProgramDecl) {
        _ = self;
        unreachable;
    }
};

const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const ast_pkg = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;
const Allocator = std.mem.Allocator;
const ProgramDecl = ast_pkg.ProgramDecl;
const Stmt = ast_pkg.Stmt;

const panic = std.debug.panic;

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

    pub fn parse(self: *Self) !std.ArrayList(ProgramDecl) {
        self.l.nexti();
        var decls: std.ArrayList(ProgramDecl) = .empty;
        while (self.l.token != .end) {
            const expr = try parse_decl(self.l, self.alloc);
            try decls.append(self.alloc, expr);
        }

        return decls;
    }

    fn parse_decl(l: *Lexer, alloc: Allocator) !ProgramDecl {
        if (l.token == .fn_) {
            return parse_fn_decl(l, alloc);
        }
        panic("panic in  parse_decl with {}", .{l.token});
    }

    fn parse_fn_decl(l: *Lexer, alloc: Allocator) !ProgramDecl {
        l.eat(.fn_);

        // parse fn signature
        l.expect(.id);
        const id = l.name.as_str(l.content);
        var args: std.ArrayList([]const u8) = .empty;
        l.eat(.id);

        l.eat(.oparen);
        while (l.token != .cparen) {
            l.expect(.id);
            const arg = l.name.as_str(l.content);
            l.nexti();

            try args.append(alloc, arg);

            if (l.token != .comma) {
                l.expect(.cparen);
            } else {
                l.nexti();
            }
        }

        l.eat(.cparen);
        l.expect(.id);
        const return_type = l.name.as_str(l.content);
        l.eat(.id);

        // parse fn body
        var body: std.ArrayList(Stmt) = .empty;
        l.eat(.obrace);

        while (l.token != .cbrace) {
            const stmt: Stmt = .{ .assign = .{ .var_ = "a", .value = .{ .arith = .{ .value = 0 }}}};
            try body.append(alloc, stmt);
        }
        l.eat(.cbrace);

        return ProgramDecl.create_fn(id, args, body, return_type);
    }
};

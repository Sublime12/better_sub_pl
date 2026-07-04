const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const ast_pkg = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;
const Allocator = std.mem.Allocator;
const ProgramDecl = ast_pkg.ProgramDecl;
const Stmt = ast_pkg.Stmt;
const Expr = ast_pkg.Expr;
const Ast = ast_pkg.Ast;

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

    pub fn parse(self: *Self) !Ast {
        self.l.nexti();
        var decls: std.ArrayList(ProgramDecl) = .empty;
        while (self.l.token != .end) {
            const expr = try parse_decl(self.l, self.alloc);
            try decls.append(self.alloc, expr);
        }

        return Ast.create(decls);
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
        // end parse fn signature

        // parse fn body
        var body: std.ArrayList(Stmt) = .empty;
        l.eat(.obrace);

        while (l.token != .cbrace) {
            if (l.token == .var_) {
                panic("var declaration not yet implemented", .{});
                // var declaration
                // l.eat(.var_);
                // l.expect(.id);
                // const var_name = l.name.as_str(l.content);
                // l.eat(.id);
                // l.expect(.ddot);

            }
            const var_name: ?[]const u8 = null;
            const expr = try parse_expr(l, alloc);

            l.eat(.semicolon);
            const stmt: Stmt = .{ .assign = .{ .var_ = var_name, .value = expr } };
            try body.append(alloc, stmt);
        }
        l.eat(.cbrace);

        return ProgramDecl.create_fn(id, args, body, return_type);
    }

    fn parse_expr(l: *Lexer, alloc: Allocator) error{OutOfMemory}!Expr {
        if (l.token == .id) {
            const next_l = l.nextl();
            if (next_l.token == .oparen) {
                // fn call
                return parse_fn_call_expr(l, alloc);
            }
        } else if (l.token == .str) {
            return parse_str(l);
        }

        panic("parse_expr panics with {}", .{l.token});
    }

    fn parse_str(l: *Lexer) !Expr {
        const raw_str = l.name.as_str(l.content);
        l.eat(.str);
        // std.debug.assert(l.token == .str);
        return Expr.create_str(raw_str);
    }

    fn parse_fn_call_expr(l: *Lexer, alloc: Allocator) !Expr {
        const fn_name = l.name.as_str(l.content);
        l.eat(.id);
        l.eat(.oparen);
        var args: std.ArrayList(Expr) = .empty;

        while (l.token != .cparen) {
            const arg = try parse_expr(l, alloc);

            try args.append(alloc, arg);
            if (l.token == .comma) {
                l.eat(.comma);
            } else {
                l.expect(.cparen);
            }
        }
        l.eat(.cparen);

        return Expr.create_fn_call(fn_name, args);
    }
};

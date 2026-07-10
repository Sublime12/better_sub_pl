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
            const stmt = try parse_stmt(l, alloc);
            try body.append(alloc, stmt);
            // l.eat(.semicolon);
        }
        l.eat(.cbrace);

        return ProgramDecl.create_fn(id, args, body, return_type);
    }

    fn parse_stmt(l: *Lexer, alloc: Allocator) error{OutOfMemory}!Stmt {
        if (l.token == .var_) {
            // var declaration
            const stmt = parse_var_decl_stmt(l, alloc);
            l.eat(.semicolon);
            return stmt;
        } else if (l.token == .if_) {
            return parse_if_stmt(l, alloc);
        } else {
            const stmt = parse_no_var_decl_stmt(l, alloc);
            l.eat(.semicolon);
            return stmt;
        }
    }

    fn parse_no_var_decl_stmt(l: *Lexer, alloc: Allocator) !Stmt {
        const expr = try parse_expr(l, alloc);
        return .{ .no_assign = .{ .value = expr } };
    }

    fn parse_var_decl_stmt(l: *Lexer, alloc: Allocator) !Stmt {
        l.eat(.var_);
        l.expect(.id);
        const name = l.name.as_str(l.content);
        l.eat(.id);
        l.eat(.colon);
        l.expect(.id);
        const type_ = l.name.as_str(l.content);
        l.eat(.id);
        l.eat(.assign);
        const expr = try parse_expr(l, alloc);
        return .{ .assign = .{
            .var_ = name,
            .type_ = type_,
            .value = expr,
        } };
    }

    fn parse_if_stmt(l: *Lexer, alloc: Allocator) !Stmt {
        l.eat(.if_);
        const if_eval = try parse_expr(l, alloc);
        var if_body: std.ArrayList(Stmt) = .empty;
        l.eat(.obrace);
        while (l.token != .cbrace) {
            const stmt = try parse_stmt(l, alloc);
            try if_body.append(alloc, stmt);
        }
        l.eat(.cbrace);
        var elseif_evals: std.ArrayList(Expr) = .empty;
        var elseif_thens: std.ArrayList(std.ArrayList(Stmt)) = .empty;

        while (l.token == .elseif) {
            l.eat(.elseif);
            const eval = try parse_expr(l, alloc);

            var then: std.ArrayList(Stmt) = .empty;
            l.eat(.obrace);
            while (l.token != .cbrace) {
                const stmt = try parse_stmt(l, alloc);
                try then.append(alloc, stmt);
            }
            l.eat(.cbrace);
            try elseif_evals.append(alloc, eval);
            try elseif_thens.append(alloc, then);
        }

        var else_eval: ?Expr = null;
        var else_then: ?std.ArrayList(Stmt) = null;

        std.debug.print("HERE : {}\n", .{l.token});
        if (l.token == .else_) {
            l.eat(.else_);
            else_eval = try parse_expr(l, alloc);
            l.eat(.obrace);
            else_then = .empty;
            while (l.token != .cbrace) {
                const stmt = try parse_stmt(l, alloc);
                try else_then.?.append(alloc, stmt);
            }
            l.eat(.cbrace);
        }

        return Stmt.create_if(
            if_eval,
            if_body,
            elseif_evals,
            elseif_thens,
            else_eval,
            else_then,
        );
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
        panic("parse_expr panics with {}, name: {s}", .{ l.token, l.name.as_str(l.content) });
    }

    fn parse_str(l: *Lexer) !Expr {
        const raw_str = l.name.as_str(l.content);
        l.eat(.str);
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

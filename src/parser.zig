const std = @import("std");

const lexer_pkg = @import("lexer.zig");
const ast_pkg = @import("ast.zig");

const Lexer = lexer_pkg.Lexer;
const Allocator = std.mem.Allocator;
const ProgramDecl = ast_pkg.ProgramDecl;
const Stmt = ast_pkg.Stmt;
const BlockStmt = ast_pkg.BlockStmt;
const Expr = ast_pkg.Expr;
const Ast = ast_pkg.Ast;
const Arg = ast_pkg.Arg;

const panic = std.debug.panic;

pub fn parse(l: *Lexer, alloc: Allocator) !Ast {
    l.reset();
    l.nexti();
    var decls: std.ArrayList(ProgramDecl) = .empty;
    while (l.token != .end) {
        const expr = try parse_decl(l, alloc);
        try decls.append(alloc, expr);
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
    var args: std.ArrayList(Arg) = .empty;
    l.eat(.id);

    l.eat(.oparen);
    while (l.token != .cparen) {
        l.expect(.id);
        const arg_name = l.name.as_str(l.content);
        l.eat(.id);

        l.eat(.colon);
        l.expect(.id);
        const type_ = l.name.as_str(l.content);
        l.eat(.id);
        const arg: Arg = .{ .name = arg_name, .type_ = type_ };

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
    const body = try parse_block_stmt(l, alloc);

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
    const if_body = try parse_block_stmt(l, alloc);
    var elseif_evals: std.ArrayList(Expr) = .empty;
    var elseif_thens: std.ArrayList(BlockStmt) = .empty;

    while (l.token == .elseif) {
        l.eat(.elseif);
        const eval = try parse_expr(l, alloc);

        const then = try parse_block_stmt(l, alloc);
        try elseif_evals.append(alloc, eval);
        try elseif_thens.append(alloc, then);
    }

    var else_then: ?BlockStmt = null;

    if (l.token == .else_) {
        l.eat(.else_);
        else_then = try parse_block_stmt(l, alloc);
    }

    return Stmt.create_if(
        if_eval,
        if_body,
        elseif_evals,
        elseif_thens,
        else_then,
    );
}

fn parse_block_stmt(l: *Lexer, alloc: Allocator) !BlockStmt {
    var block: std.ArrayList(Stmt) = .empty;
    l.eat(.obrace);
    while (l.token != .cbrace) {
        const stmt = try parse_stmt(l, alloc);
        try block.append(alloc, stmt);
    }
    l.eat(.cbrace);

    return .{ .stmts = block };
}

fn parse_expr(l: *Lexer, alloc: Allocator) error{OutOfMemory}!Expr {
    if (l.token == .id) {
        const next_l = l.nextl();
        if (next_l.token == .oparen) {
            // fn call
            return parse_fn_call_expr(l, alloc);
        }
        const name = l.name.as_str(l.content);
        l.eat(.id);
        return Expr.create_var(
            name,
            l.file_path,
            l.cursor,
        );
    } else if (l.token == .str) {
        return parse_str(l);
    }
    panic("parse_expr panics with {}, name: {s}", .{ l.token, l.name.as_str(l.content) });
}

fn parse_str(l: *Lexer) !Expr {
    const raw_str = l.name.as_str(l.content);
    l.eat(.str);
    return Expr.create_str(
        raw_str,
        l.file_path,
        l.cursor,
    );
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

    return Expr.create_fn_call(fn_name, args, l.file_path, l.cursor);
}

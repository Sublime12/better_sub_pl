const std = @import("std");

const lexer_pkg = @import("lexer.zig");

const Cursor = lexer_pkg.Cursor;
const Writer = std.Io.Writer;

const panic = std.debug.panic;
const assert = std.debug.assert;

//////////// Program Block

pub const Ast = struct {
    decls: std.ArrayList(ProgramDecl),

    pub fn create(decls: std.ArrayList(ProgramDecl)) Ast {
        return .{ .decls = decls };
    }

    pub fn print(ast: Ast, w: *Writer) void {
        for (ast.decls.items) |decl| {
            decl.print(w, 0);
            w.print("\n\n", .{}) catch unreachable;
        }
    }
};

const ProgramDeclTag = enum {
    // struct_,
    fn_decl,
};

pub const ProgramDecl = union(ProgramDeclTag) {
    const Self = @This();

    fn_decl: FnDecl,

    pub fn create_fn(
        name: []const u8,
        args: std.ArrayList(Arg),
        body: BlockStmt,
        return_type: []const u8,
    ) ProgramDecl {
        return .{ .fn_decl = .{
            .name = name,
            .args = args,
            .body = body,
            .return_type = return_type,
        } };
    }

    pub fn print(self: Self, w: *Writer, nindent: usize) void {
        switch (self) {
            .fn_decl => |fn_decl| fn_decl.print(w, nindent),
        }
    }
};

pub const FnDecl = struct {
    const Self = @This();

    name: []const u8,
    args: std.ArrayList(Arg),
    body: BlockStmt,
    return_type: []const u8,

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        print_nindent(w, indent);
        w.print("fn {s}(", .{self.name}) catch unreachable;
        for (self.args.items, 0..) |arg, i| {
            w.print("{s}: {s}", .{ arg.name, arg.type_ }) catch unreachable;
            if (i < self.args.items.len - 1) w.print(", ", .{}) catch unreachable;
        }

        w.print(") {s} {{\n", .{self.return_type}) catch unreachable;

        for (self.body.stmts.items) |stmt| {
            stmt.print(w, indent + 1);
        }

        print_nindent(w, indent);
        w.print("}}", .{}) catch unreachable;
    }
};

pub const Arg = struct {
    name: []const u8,
    type_: []const u8,
};

pub const BlockStmt = struct {
    stmts: std.ArrayList(Stmt),
};

//////////// Expr structs

const ExprTag = enum {
    arith,
    bool_,
    fn_call,
    str,
    var_,
};

pub const Expr = struct {
    const Self = @This();

    cursor: Cursor,
    file_path: []const u8,
    file_content: []const u8,
    as: ExprAs,

    pub fn create_fn_call(
        name: []const u8,
        args: std.ArrayList(Expr),
        file_path: []const u8,
        cursor: Cursor,
        file_content: []const u8,
    ) Expr {
        return .{
            .as = .{ .fn_call = .{
                .name = name,
                .args = args,
            } },
            .file_path = file_path,
            .cursor = cursor,
            .file_content = file_content,
        };
    }

    pub fn create_str(
        content: []const u8,
        file_path: []const u8,
        cursor: Cursor,
        file_content: []const u8,
    ) Expr {
        return .{
            .as = .{ .str = content },
            .file_path = file_path,
            .cursor = cursor,
            .file_content = file_content,
        };
    }

    pub fn create_var(
        name: []const u8,
        file_path: []const u8,
        cursor: Cursor,
        file_content: []const u8,
    ) Expr {
        return .{
            .as = .{ .var_ = name },
            .file_path = file_path,
            .cursor = cursor,
            .file_content = file_content,
        };
    }

    pub fn create_int(
        integer: i32,
        file_path: []const u8,
        cursor: Cursor,
        file_content: []const u8,
    ) Expr {
        return .{
            .as = .{ .arith = .{ .value = integer } },
            .file_path = file_path,
            .cursor = cursor,
            .file_content = file_content,
        };
    }

    pub fn print(self: Self, w: *Writer) void {
        switch (self.as) {
            .str => |str| w.print("\"{s}\"", .{str}) catch unreachable,
            .fn_call => |fn_call| fn_call.print(w),
            .var_ => |var_| w.print("{s}", .{var_}) catch unreachable,
            .arith => |arith| {
                w.print("{}", .{arith.value}) catch unreachable;
            },
            .bool_ => panic("print unimplemented for bool", .{}),
        }
    }
};

pub const ExprAs = union(ExprTag) {
    const Self = @This();

    arith: ArithExpr,
    bool_: BoolExpr,
    fn_call: FnCallExpr,
    str: []const u8,
    var_: []const u8,
};

const ArithExpr = struct {
    value: i32,
};

const BoolExpr = struct {
    value: bool,
};

const FnCallExpr = struct {
    const Self = @This();

    name: []const u8,
    args: std.ArrayList(Expr),

    pub fn print(self: Self, w: *Writer) void {
        w.print("{s}(", .{self.name}) catch unreachable;
        for (self.args.items, 0..) |arg, i| {
            arg.print(w);
            if (i < self.args.items.len - 1) {
                w.print(", ", .{}) catch unreachable;
            }
        }
        w.print(")", .{}) catch unreachable;
    }
};

const StmtTag = enum {
    declare_and_assign,
    assign,
    no_assign,
    if_,
};

//////////// Stmt structs
pub const Stmt = union(StmtTag) {
    const Self = @This();

    declare_and_assign: DeclareAndAssignStmt,
    assign: AssignStmt,
    no_assign: NoAssignStmt,
    if_: IfStmt,

    pub fn create_declare_and_assign(
        var_: []const u8,
        type_: []const u8,
        value: Expr,
    ) Stmt {
        return .{ .declare_and_assign = .{
            .var_ = var_,
            .type_ = type_,
            .value = value,
        } };
    }

    pub fn create_assign(lvalue: Expr, rvalue: Expr) Stmt {
        return .{ .assign = .{
            .lvalue = lvalue,
            .rvalue = rvalue,
        } };
    }

    pub fn create_no_assign(rvalue: Expr) Stmt {
        return .{ .no_assign = .{
            .rvalue = rvalue,
        } };
    }

    pub fn create_if(
        if_eval: Expr,
        if_body: BlockStmt,
        elseif_evals: std.ArrayList(Expr),
        elseif_thens: std.ArrayList(BlockStmt),
        else_then: ?BlockStmt,
    ) Stmt {
        return .{ .if_ = .{
            .if_eval = if_eval,
            .if_body = if_body,
            .elseif_evals = elseif_evals,
            .elseif_thens = elseif_thens,
            .else_then = else_then,
        } };
    }

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        switch (self) {
            .declare_and_assign => |assign| assign.print(w, indent),
            .no_assign => |no_assign| no_assign.print(w, indent),
            .assign => |assign| assign.print(w, indent),
            .if_ => |if_| if_.print(w, indent),
        }
        w.print("\n", .{}) catch unreachable;
    }
};

const AssignStmt = struct {
    const Self = @This();

    lvalue: Expr,
    rvalue: Expr,

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        print_nindent(w, indent);
        self.lvalue.print(w);
        w.print(" = ", .{}) catch unreachable;
        self.rvalue.print(w);
        w.print(";", .{}) catch unreachable;
    }
};

const DeclareAndAssignStmt = struct {
    const Self = @This();

    var_: []const u8,
    type_: []const u8,
    value: Expr,

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        print_nindent(w, indent);
        w.print("var {s}: {s} = ", .{ self.var_, self.type_ }) catch unreachable;
        self.value.print(w);
        w.print(";", .{}) catch unreachable;
    }
};

const NoAssignStmt = struct {
    const Self = @This();
    rvalue: Expr,

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        print_nindent(w, indent);
        self.rvalue.print(w);
        w.print(";", .{}) catch unreachable;
    }
};

const IfStmt = struct {
    const Self = @This();

    if_eval: Expr,
    if_body: BlockStmt,

    elseif_evals: std.ArrayList(Expr),
    elseif_thens: std.ArrayList(BlockStmt),

    else_then: ?BlockStmt,

    pub fn print(self: Self, w: *Writer, indent: usize) void {
        print_nindent(w, indent);
        w.print("if ", .{}) catch unreachable;
        self.if_eval.print(w);
        w.print(" {{\n", .{}) catch unreachable;
        for (self.if_body.stmts.items) |stmt| {
            stmt.print(w, indent + 1);
        }
        print_nindent(w, indent);
        w.print("}}", .{}) catch unreachable;

        assert(self.elseif_evals.items.len == self.elseif_thens.items.len);
        for (0..self.elseif_evals.items.len) |i| {
            const eval = self.elseif_evals.items[i];
            const then = self.elseif_thens.items[i];

            w.print(" elseif ", .{}) catch unreachable;
            eval.print(w);
            w.print(" {{\n", .{}) catch unreachable;

            for (then.stmts.items) |then_stmt| {
                then_stmt.print(w, indent + 1);
            }
            print_nindent(w, indent);
            w.print("}}", .{}) catch unreachable;
        }

        if (self.else_then != null) {
            const else_then = self.else_then.?;

            w.print(" else {{\n", .{}) catch unreachable;
            for (else_then.stmts.items) |then_stmt| {
                then_stmt.print(w, indent + 1);
            }
            print_nindent(w, indent);
            w.print("}}", .{}) catch unreachable;
        }
    }
};

fn print_nindent(w: *Writer, n: usize) void {
    for (0..n) |_| {
        w.print("    ", .{}) catch unreachable;
    }
}

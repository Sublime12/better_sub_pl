const std = @import("std");

const panic = std.debug.panic;

//////////// Program Block

pub const Ast = struct {
    decls: std.ArrayList(ProgramDecl),

    pub fn create(decls: std.ArrayList(ProgramDecl)) Ast {
        return .{ .decls = decls };
    }

    pub fn print(ast: Ast) void {
        for (ast.decls.items) |decl| {
            decl.print(0);
            std.debug.print("\n\n", .{});
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
        args: std.ArrayList([]const u8),
        body: std.ArrayList(Stmt),
        return_type: []const u8,
    ) ProgramDecl {
        return .{ .fn_decl = .{
            .name = name,
            .args = args,
            .body = body,
            .return_type = return_type,
        } };
    }

    pub fn print(self: Self, nindent: usize) void {
        switch (self) {
            .fn_decl => |fn_decl| fn_decl.print(nindent),
        }
    }
};

const FnDecl = struct {
    const Self = @This();

    name: []const u8,
    args: std.ArrayList([]const u8),
    body: std.ArrayList(Stmt),
    return_type: []const u8,

    pub fn print(self: Self, indent: usize) void {
        print_nindent(indent);
        std.debug.print("fn {s}(", .{self.name});
        for (self.args.items) |arg| {
            std.debug.print("{s}, ", .{arg});
        }

        std.debug.print(") {s} {{\n", .{self.return_type});

        for (self.body.items) |stmt| {
            stmt.print(indent + 1);
        }

        print_nindent(indent);
        std.debug.print("}}", .{});
    }
};

//////////// Expr structs

const ExprTag = enum {
    arith,
    bool_,
    fn_call,
    str,
};

pub const Expr = union(ExprTag) {
    const Self = @This();

    arith: ArithExpr,
    bool_: BoolExpr,
    fn_call: FnCallExpr,
    str: []const u8,

    pub fn create_fn_call(name: []const u8, args: std.ArrayList(Expr)) Expr {
        return .{ .fn_call = .{
            .name = name,
            .args = args,
        } };
    }

    pub fn create_str(content: []const u8) Expr {
        return .{ .str = content };
    }

    pub fn print(self: Self) void {
        switch (self) {
            .str => |str| std.debug.print("\"{s}\"", .{str}),
            .fn_call => |fn_call| fn_call.print(),
            else => panic("print unimplemented for {}", .{std.meta.activeTag(self)}),
        }
    }
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

    pub fn print(self: Self) void {
        std.debug.print("{s}(", .{self.name});
        for (self.args.items, 0..) |arg, i| {
            arg.print();
            if (i < self.args.items.len - 1) {
                std.debug.print(", ", .{});
            }
        }
        std.debug.print(")", .{});
    }
};

const VarDeclExpr = struct {
    name: []const u8,
    value: *Expr,
};

const StmtTag = enum {
    assign,
    no_assign,
    if_,
};

//////////// Stmt structs
pub const Stmt = union(StmtTag) {
    const Self = @This();

    assign: AssignStmt,
    no_assign: NoAssignStmt,
    if_: IfStmt,

    pub fn create_assign(var_: ?[]const u8, value: Expr) Stmt {
        return .{ .assign = .{
            .var_ = var_,
            .value = value,
        } };
    }

    pub fn create_if(
        if_eval: Expr,
        if_body: std.ArrayList(Stmt),
        elseif_evals: std.ArrayList(Expr),
        elseif_thens: std.ArrayList(std.ArrayList(Stmt)),
        else_eval: ?Expr,
        else_then: ?std.ArrayList(Stmt),
    ) Stmt {
        return .{ .if_ = .{
            .if_eval = if_eval,
            .if_body = if_body,
            .elseif_evals = elseif_evals,
            .elseif_thens = elseif_thens,
            .else_eval = else_eval,
            .else_then = else_then,
        } };
    }

    pub fn print(self: Self, indent: usize) void {
        switch (self) {
            .assign => |assign| assign.print(indent),
            .no_assign => |no_assign| no_assign.print(indent),
            .if_ => |if_| if_.print(indent),
        }
        std.debug.print(";\n", .{});
    }
};

const AssignStmt = struct {
    const Self = @This();

    var_: []const u8,
    type_: []const u8,
    value: Expr,

    pub fn print(self: Self, indent: usize) void {
        print_nindent(indent);
        std.debug.print("var {s}: {s} = ", .{ self.var_, self.type_ });
        self.value.print();
    }
};

const NoAssignStmt = struct {
    const Self = @This();
    value: Expr,

    pub fn print(self: Self, indent: usize) void {
        print_nindent(indent);
        self.value.print();
    }
};

const IfStmt = struct {
    const Self = @This();

    if_eval: Expr,
    if_body: std.ArrayList(Stmt),

    elseif_evals: std.ArrayList(Expr),
    elseif_thens: std.ArrayList(std.ArrayList(Stmt)),

    else_eval: ?Expr,
    else_then: ?std.ArrayList(Stmt),

    pub fn print(self: Self, indent: usize) void {
        print_nindent(indent);
        std.debug.print("if ", .{});
        self.if_eval.print();
        std.debug.print(" {{\n", .{});
        for (self.if_body.items) |stmt| {
            stmt.print(indent + 1);
        }
        print_nindent(indent);
        std.debug.print("}}", .{});
    }
};

fn print_nindent(n: usize) void {
    for (0..n) |_| {
        std.debug.print("    ", .{});
    }
}

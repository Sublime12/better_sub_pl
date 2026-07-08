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
            decl.print();
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

    pub fn print(self: Self) void {
        switch (self) {
            .fn_decl => |fn_decl| fn_decl.print(),
        }
    }
};

const FnDecl = struct {
    const Self = @This();

    name: []const u8,
    args: std.ArrayList([]const u8),
    body: std.ArrayList(Stmt),
    return_type: []const u8,

    pub fn print(self: Self) void {
        std.debug.print("fn {s}(", .{self.name});
        for (self.args.items) |arg| {
            std.debug.print("{s}, ", .{arg});
        }

        std.debug.print(") {s} {{\n", .{self.return_type});
        const indent = 1;

        for (self.body.items) |stmt| {
            print_nindent(indent);
            stmt.print();
        }

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
};

//////////// Stmt structs
pub const Stmt = union(StmtTag) {
    const Self = @This();

    assign: AssignStmt,
    no_assign: NoAssignStmt,

    pub fn create_assign(var_: ?[]const u8, value: Expr) Stmt {
        return .{ .assign = .{
            .var_ = var_,
            .value = value,
        } };
    }

    pub fn print(self: Self) void {
        switch (self) {
            .assign => |assign| assign.print(),
            .no_assign => |no_assign| no_assign.print(),
        }
        std.debug.print(";\n", .{});
    }
};

const AssignStmt = struct {
    const Self = @This();

    var_: []const u8,
    type_: []const u8,
    value: Expr,

    pub fn print(self: Self) void {
        std.debug.print("var {s}: {s} = ", .{ self.var_, self.type_ });
        self.value.print();
    }
};

const NoAssignStmt = struct {
    const Self = @This();
    value: Expr,

    pub fn print(self: Self) void {
        self.value.print();
    }
};

fn print_nindent(n: usize) void {
    for (0..n) |_| {
        std.debug.print("  ", .{});
    }
}

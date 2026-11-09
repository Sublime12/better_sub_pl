const std = @import("std");

pub const Type = struct {
    name: []const u8,
    size: usize,
    childrens: std.ArrayList(Type),
};

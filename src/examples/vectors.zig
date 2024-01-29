const std = @import("std");
const interfacil = @import("interfacil");

pub const Vector = struct {
    x: i32,
    y: i32,

    fn xEquivalent(self: Vector, other: Vector) bool {
        return self.x == other.x;
    }

    fn yEquivalent(self: Vector, other: Vector) bool {
        return self.y == other.y;
    }

    pub usingnamespace interfacil.Equivalent(Vector, .{});
    pub const XEquivalent = interfacil.Equivalent(Vector, .{ .eq = xEquivalent });
    pub const YEquivalent = interfacil.Equivalent(Vector, .{ .eq = yEquivalent });
};

fn printEq(eq: bool) []const u8 {
    return if (eq) "===" else "!==";
}

pub fn main() !void {
    const zero = Vector{ .x = 0, .y = 0 };
    const one = Vector{ .x = 1, .y = 1 };
    const one_zero = Vector{ .x = 1, .y = 0 };

    std.debug.print(
        \\equivalent:
        \\    (0, 0) {s} (0, 0)
        \\    (0, 0) {s} (1, 0)
        \\    (0, 0) {s} (1, 1)
        \\    (1, 0) {s} (0, 0)
        \\    (1, 0) {s} (1, 0)
        \\    (1, 0) {s} (1, 1)
        \\    (1, 1) {s} (0, 0)
        \\    (1, 1) {s} (1, 0)
        \\    (1, 1) {s} (1, 1)
        \\
    , .{
        printEq(zero.eq(zero)),
        printEq(zero.eq(one_zero)),
        printEq(zero.eq(one)),
        printEq(one_zero.eq(zero)),
        printEq(one_zero.eq(one_zero)),
        printEq(one_zero.eq(one)),
        printEq(one.eq(zero)),
        printEq(one.eq(one_zero)),
        printEq(one.eq(one)),
    });
    std.debug.print(
        \\x-equivalent:
        \\    (0, 0) {s} (0, 0)
        \\    (0, 0) {s} (1, 0)
        \\    (0, 0) {s} (1, 1)
        \\    (1, 0) {s} (0, 0)
        \\    (1, 0) {s} (1, 0)
        \\    (1, 0) {s} (1, 1)
        \\    (1, 1) {s} (0, 0)
        \\    (1, 1) {s} (1, 0)
        \\    (1, 1) {s} (1, 1)
        \\
    , .{
        printEq(Vector.XEquivalent.eq(zero, zero)),
        printEq(Vector.XEquivalent.eq(zero, one_zero)),
        printEq(Vector.XEquivalent.eq(zero, one)),
        printEq(Vector.XEquivalent.eq(one_zero, zero)),
        printEq(Vector.XEquivalent.eq(one_zero, one_zero)),
        printEq(Vector.XEquivalent.eq(one_zero, one)),
        printEq(Vector.XEquivalent.eq(one, zero)),
        printEq(Vector.XEquivalent.eq(one, one_zero)),
        printEq(Vector.XEquivalent.eq(one, one)),
    });
    std.debug.print(
        \\y-equivalent:
        \\    (0, 0) {s} (0, 0)
        \\    (0, 0) {s} (1, 0)
        \\    (0, 0) {s} (1, 1)
        \\    (1, 0) {s} (0, 0)
        \\    (1, 0) {s} (1, 0)
        \\    (1, 0) {s} (1, 1)
        \\    (1, 1) {s} (0, 0)
        \\    (1, 1) {s} (1, 0)
        \\    (1, 1) {s} (1, 1)
        \\
    , .{
        printEq(Vector.YEquivalent.eq(zero, zero)),
        printEq(Vector.YEquivalent.eq(zero, one_zero)),
        printEq(Vector.YEquivalent.eq(zero, one)),
        printEq(Vector.YEquivalent.eq(one_zero, zero)),
        printEq(Vector.YEquivalent.eq(one_zero, one_zero)),
        printEq(Vector.YEquivalent.eq(one_zero, one)),
        printEq(Vector.YEquivalent.eq(one, zero)),
        printEq(Vector.YEquivalent.eq(one, one_zero)),
        printEq(Vector.YEquivalent.eq(one, one)),
    });
}

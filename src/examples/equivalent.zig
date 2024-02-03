const std = @import("std");
const Equivalent = @import("interfacil").comparison.Equivalent;

const Vector = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn squaredLength(self: Vector) i32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    /// `LenEq` is short for `LengthEquivalent`.
    pub const LenEq = Equivalent(Vector, .{ .eq = struct {
        pub fn call(a: Vector, b: Vector) bool {
            return a.squaredLength() == b.squaredLength();
        }
    }.call });
    pub const X = Equivalent(Vector, .{ .eq = struct {
        pub fn call(a: Vector, b: Vector) bool {
            return a.x == b.x;
        }
    }.call });

    pub usingnamespace Equivalent(Vector, .{});
};

pub fn main() void {
    const v1 = Vector{ .x = 3, .y = 4, .z = 5 };
    const v2 = Vector{ .x = 4, .y = 3, .z = 5 };
    const v3 = Vector{ .x = 3, .y = 3, .z = 3 };

    inline for (.{ v1, v2, v3 }) |a| inline for (.{ v1, v2, v3 }) |b| std.debug.print(
        \\If 
        \\    a == {any}
        \\    b == {any}
        \\Then
        \\    a {s} b
        \\    a {s} b
        \\
        \\
    , .{
        a,
        b,
        if (a.eq(b)) "==" else "!=",
        if (Vector.LenEq.eq(a, b)) "=len=" else "!len!",
    });

    inline for (.{ v1, v2, v3 }) |a| inline for (.{ v1, v2, v3 }) |b| std.debug.print(
        \\If 
        \\    a == {any}
        \\    b == {any}
        \\Then
        \\    a {s} b
        \\    a {s} b
        \\
        \\
    , .{
        a,
        b,
        if (a.eq(b)) "==" else "!=",
        if (Vector.X.eq(a, b)) "=x=" else "!x!",
    });
}

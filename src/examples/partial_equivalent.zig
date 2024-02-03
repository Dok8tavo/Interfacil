const std = @import("std");
const PartialEquivalent = @import("interfacil").comparison.PartialEquivalent;

const Point = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn isValid(self: Point) bool {
        return std.math.isFinite(self.x) and
            std.math.isFinite(self.y) and
            !std.math.isNan(self.x) and
            !std.math.isNan(self.y);
    }

    pub fn squaredDistanceTo(self: Point, other: Point) ?f32 {
        if (!self.isValid() or !other.isValid()) return null;
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return dx * dx + dy * dy;
    }

    pub fn distanceTo(self: Point, other: Point) ?f32 {
        const squared = self.squaredDistanceTo(other) orelse return null;
        return std.math.sqrt(squared);
    }

    pub fn PrecisionEquivalent(comptime precision: f32) type {
        return PartialEquivalent(Point, .{
            .eq = struct {
                pub fn call(a: Point, b: Point) ?bool {
                    const squared_distance = a.squaredDistanceTo(b) orelse return null;
                    return squared_distance <= precision * precision;
                }
            }.call,
        });
    }

    pub usingnamespace PrecisionEquivalent(1e-5);
};

pub fn main() void {
    const goal = Point{
        .x = -3,
        .y = 4,
    };

    var p = Point{};
    var i: usize = 1;
    while (true) : (i += 1) {
        std.debug.print(
            \\Attempt n°{}:
            \\    p = {any}
            \\    p.distanceTo(goal) = {?}
            \\    p.eq(goal) = {s}
            \\
        , .{
            i,
            p,
            p.distanceTo(goal),
            if (p.eq(goal)) |e| blk: {
                break :blk if (e) "true" else "false";
            } else "null",
        });

        p.x += (goal.x - p.x) / 2;
        p.y += (goal.y - p.y) / 2;

        if (p.eq(goal)) |e| {
            if (e) {
                std.debug.print("Found an equivalent: {any}\n", .{p});
                break;
            }
        } else {
            std.debug.print("Couldn't find an equivalent.\n", .{});
            break;
        }
    }
}

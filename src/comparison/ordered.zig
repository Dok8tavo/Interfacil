const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");
const Equivalent = @import("equivalent.zig").Equivalent;

pub const Order = enum(i3) {
    backwards = -1,
    equals = 0,
    forwards = 1,

    pub usingnamespace Equivalent(Order, .{});
};

/// This function is returns a comparison function. A comparison function takes two parameters of
/// the same type and returns an `Order` enum value. It can be used to define an order, a relation
/// that's guaranteed to be:
/// - reflexive: `∀x : ord(x, x)`,
/// - antisymmetric: `∀x, y : (ord(x, y) and ord(y, x)) => x == y`,
/// - transitive: `∀x, y, z : (ord(x, y) and ord(y, z)) => ord(x, z)`,
/// It'll be meaningful in the context of values, but not much when using complex types.
pub fn anyCompareFn(comptime T: type) fn (T, T) Order {
    return struct {
        fn anyCompare(a: anytype, b: @TypeOf(a)) Order {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                .Int, .ComptimeInt => if (a == b)
                    .equals
                else if (a < b)
                    .forwards
                else
                    .backwards,
                .Bool => anyCompare(@intFromBool(a), @intFromBool(b)),
                .Enum => anyCompare(@intFromEnum(a), @intFromEnum(b)),
                .ErrorSet => anyCompare(@intFromError(a), @intFromError(b)),
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => anyCompare(a.*, b.*),
                    // TODO: better errors!
                    else => misc.compileError(
                        "The `{s}.anyCompare` function can't compare complex types like `{s}`!",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // TODO: handle each case individually for better errors!
                else => misc.compileError(
                    "The `{s}.anyCompare` function can't compare complex types like `{s}`!",
                    .{ @typeName(T), @typeName(A) },
                ),
            };
        }

        pub fn compare(self: T, other: T) Order {
            return anyCompare(self, other);
        }
    }.compare;
}

const std = @import("std");
const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");
const equivalent = @import("equivalent.zig");
const Equivalent = equivalent.Equivalent;
const PartialEquivalent = equivalent.PartialEquivalent;

pub const Order = enum(i3) {
    backwards = -1,
    equals = 0,
    forwards = 1,

    pub usingnamespace Equivalent(Order, .{});
};

pub fn Ordered(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);
        const Self: type = contract.default(.Self, Contractor);

        pub const compare: fn (Self, Self) Order = contract.default(.compare, anyCompareFn(Self));
        pub usingnamespace Equivalent(Self, .{ .eq = eqFn });

        fn eqFn(self: Self, other: Self) bool {
            return compare(self, other).eq(.equals);
        }

        pub const lt: fn (Self, Self) bool = contract.default(.lt, defaultLessThan);
        pub const le: fn (Self, Self) bool = contract.default(.le, defaultLessEqual);
        pub const gt: fn (Self, Self) bool = contract.default(.gt, defaultGreaterThan);
        pub const ge: fn (Self, Self) bool = contract.default(.ge, defaultGreaterEqual);
        pub const maxIndex: fn ([]const Self) ?Self = contract.default(.maxIndex, defaultMaxIndex);
        pub const minIndex: fn ([]const Self) ?Self = contract.default(.minIndex, defaultMinIndex);
        pub const max: fn ([]const Self) ?usize = contract.default(.max, defaultMax);
        pub const min: fn ([]const Self) ?usize = contract.default(.min, defaultMin);
        pub const clamp: fn (Self, Self, Self) Self = contract.default(.clamp, defaultClamp);
        pub const clamped: fn (Self, Self, Self) bool = contract.default(.clamped, defaultClamped);

        fn defaultClamped(self: Self, floor: Self, roof: Self) bool {
            std.debug.assert(le(floor, roof));
            return le(floor, self) and le(self, roof);
        }

        fn defaultClamp(self: Self, floor: Self, roof: Self) Self {
            std.debug.assert(le(floor, roof));
            return if (le(self, floor)) floor else if (ge(self, roof)) roof else self;
        }

        fn defaultMax(slice: []const Self) ?Self {
            const max_index = maxIndex(slice) orelse return null;
            return slice[max_index];
        }

        fn defaultMin(slice: []const Self) ?Self {
            const min_index = minIndex(slice) orelse return null;
            return slice[min_index];
        }

        fn defaultMaxIndex(slice: []const Self) ?usize {
            if (slice.len == 0) return null;
            var imax: usize = 0;
            for (slice[1..], 1..) |item, i| {
                if (gt(item, slice[imax])) imax = i;
            }

            return imax;
        }

        fn defaultMinIndex(slice: []const Self) ?usize {
            if (slice.len == 0) return null;
            var imin: usize = 0;
            for (slice[1..], 1..) |item, i| {
                if (lt(item, slice[imin])) imin = i;
            }

            return imin;
        }

        fn defaultLessThan(self: Self, other: Self) bool {
            return compare(self, other).eq(.forwards);
        }

        fn defaultLessEqual(self: Self, other: Self) bool {
            return compare(self, other).no(.backwards);
        }

        fn defaultGreaterThan(self: Self, other: Self) bool {
            return compare(self, other).eq(.backwards);
        }

        fn defaultGreaterEqual(self: Self, other: Self) bool {
            return compare(self, other).no(.forwards);
        }
    };
}

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

pub fn PartialOrdered(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);
        const Self = contract.default(.Self, Contractor);

        pub const compare: fn (Self, Self) ?Order = contract.default(.compare, anyCompareFn(Self));
        pub usingnamespace PartialEquivalent(Contractor, .{ .eq = eqFn });

        fn eqFn(self: Self, other: Self) ?bool {
            const order = compare(self, other) orelse return null;
            return order.eq(.equals);
        }

        pub const lt: fn (Self, Self) ?bool = contract.default(.lt, defaultLessThan);
        pub const le: fn (Self, Self) ?bool = contract.default(.le, defaultLessEqual);
        pub const gt: fn (Self, Self) ?bool = contract.default(.gt, defaultGreaterThan);
        pub const ge: fn (Self, Self) ?bool = contract.default(.ge, defaultGreaterEqual);

        fn defaultLessThan(self: Self, other: Self) ?bool {
            const order = compare(self, other) orelse return null;
            return order.eq(.forwards);
        }

        fn defaultLessEqual(self: Self, other: Self) ?bool {
            const order = compare(self, other) orelse return null;
            return order.no(.backwards);
        }

        fn defaultGreaterThan(self: Self, other: Self) ?bool {
            const order = compare(self, other) orelse return null;
            return order.eq(.backwards);
        }

        fn defaultGreaterEqual(self: Self, other: Self) ?bool {
            const order = compare(self, other) orelse return null;
            return order.no(.forwards);
        }
    };
}

pub fn anyPartialCompareFn(comptime T: type) fn (T, T) ?Order {
    return struct {
        fn partialCompareItems(c: anytype, d: @TypeOf(c), order: Order) ?Order {
            if (anyPartialCompare(c, d)) |cd_order| {
                return switch (order) {
                    .equals => cd_order,
                    .forwards => if (cd_order.eq(.backwards)) null else order,
                    .backwards => if (cd_order.eq(.forwards)) null else order,
                };
            } else return null;
        }

        fn anyPartialCompare(a: anytype, b: @TypeOf(a)) ?Order {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                .Int, .ComptimeInt => if (a == b)
                    .equals
                else if (a < b)
                    .forwards
                else
                    .backwards,
                .Bool => anyPartialCompare(@intFromBool(a), @intFromBool(b)),
                .Enum => anyPartialCompare(@intFromEnum(a), @intFromEnum(b)),
                .ErrorSet => anyPartialCompare(@intFromError(a), @intFromError(b)),
                .Array, .Vector => {
                    var ab_order = Order.equals;
                    return inline for (a, b) |c, d| {
                        ab_order = partialCompareItems(c, d, ab_order) orelse break null;
                    } else ab_order;
                },
                .Struct => |Struct| {
                    var ab_order = Order.equals;
                    return inline for (Struct.fields) |field| {
                        const c = @field(a, field.name);
                        const d = @field(b, field.name);
                        ab_order = partialCompareItems(c, d, ab_order) orelse break null;
                    } else ab_order;
                },
                // Comparing two values of different types doesn't make much sense, that's why sum
                // types must return null when two of them don't have the same variant active.
                .Optional => {
                    const yes_a = a orelse return null;
                    const yes_b = b orelse return null;
                    return anyPartialCompare(yes_a, yes_b);
                },
                .ErrorUnion => {
                    const yes_a = a catch return null;
                    const yes_b = b catch return null;
                    return anyPartialCompare(yes_a, yes_b);
                },
                .Union => |Union| if (Union.tag_type) |_| {
                    const tag_a = @intFromEnum(a);
                    const tag_b = @intFromEnum(b);
                    if (tag_a != tag_b) return null;
                    const payload_a = @field(a, @tagName(tag_a));
                    const payload_b = @field(b, @tagName(tag_b));
                    return anyPartialCompare(payload_a, payload_b);
                } else misc.compileError("In order to be compared unions must be tagged!", .{}),
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => anyPartialCompare(a.*, b.*),
                    .Slice => if (a.len != b.len) null else {
                        var ab_order = Order.equals;
                        return for (a, b) |c, d| {
                            ab_order = partialCompareItems(c, d, ab_order) orelse break null;
                        } else ab_order;
                    },
                    // TODO: better error messages!
                    else => misc.compileError(
                        "The `{s}.anyPartialCompare` function can't compare complex types like `{s}`!",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // TODO: better error messages!
                else => misc.compileError(
                    "The `{s}.anyPartialCompare` function can't compare complex types like `{s}`!",
                    .{ @typeName(T), @typeName(A) },
                ),
            };
        }

        pub fn call(self: T, other: T) ?Order {
            return anyPartialCompare(self, other);
        }
    }.call;
}

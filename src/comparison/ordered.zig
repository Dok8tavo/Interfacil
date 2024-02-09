const std = @import("std");
const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");
const equivalent = @import("equivalent.zig");
const Equivalent = equivalent.Equivalent;
const PartialEquivalent = equivalent.PartialEquivalent;
const collections = @import("../collections.zig");
const Iterator = collections.iterating.Iterator;

pub const Order = enum(i3) {
    backwards = -1,
    equals = 0,
    forwards = 1,

    pub usingnamespace Equivalent(Order, .{});
    /// The `OptEq` name stands for "Optional Equivalency", which is the namespace for partial
    /// equivalency of the `?Order` type.
    pub const optionEq = PartialEquivalent(?Order, .{}).eq;
};

/// # Ordered
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
pub fn Ordered(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.default(.Self, Contractor);
    return struct {
        pub const cmp: fn (Self, Self) Order = contract.default(.cmp, anyCompareFn(Self));
        pub usingnamespace Equivalent(Self, .{ .eq = struct {
            pub fn call(self: Self, other: Self) bool {
                return cmp(self, other).eq(.equals);
            }
        }.call });

        pub fn lt(self: Self, other: Self) bool {
            return cmp(self, other).eq(.forwards);
        }

        pub fn le(self: Self, other: Self) bool {
            return !cmp(self, other).eq(.backwards);
        }

        pub fn gt(self: Self, other: Self) bool {
            return cmp(self, other).eq(.backwards);
        }

        pub fn ge(self: Self, other: Self) bool {
            return !cmp(self, other).eq(.forwards);
        }

        pub fn clamp(self: *Self, floor: Self, roof: Self) void {
            std.debug.assert(le(floor, roof));
            self.* = clamped(self, floor, roof);
        }

        pub fn isClamped(self: Self, floor: Self, roof: Self) bool {
            std.debug.assert(le(floor, roof));
            return le(floor, self) and le(self, roof);
        }

        pub fn clamped(self: Self, floor: Self, roof: Self) Self {
            std.debug.assert(le(floor, roof));
            return if (le(self, floor)) floor else if (le(roof, self)) roof else self;
        }

        pub fn isClampedStrict(self: Self, floor: Self, roof: Self) bool {
            std.debug.assert(lt(floor, roof));
            return lt(floor, self) and lt(self, roof);
        }

        pub fn max(iterator: Iterator(Self)) ?Self {
            return extremum(ge, iterator);
        }

        pub fn min(iterator: Iterator(Self)) ?Self {
            return extremum(le, iterator);
        }

        pub fn extremum(
            comptime comparator: fn (Self, Self) bool,
            iterator: Iterator(Self),
        ) ?Self {
            var extreme_item = iterator.next() orelse return null;
            return while (iterator.next()) |item| {
                if (comparator(extreme_item, item)) extreme_item = item;
            } else extreme_item;
        }

        pub fn maxIndex(iterator: Iterator(Self)) ?usize {
            return extremumIndex(ge, iterator);
        }

        pub fn minIndex(iterator: Iterator(Self)) ?usize {
            return extremumIndex(le, iterator);
        }

        pub fn extremumIndex(
            comptime comparator: fn (Self, Self) bool,
            iterator: Iterator(Self),
        ) ?usize {
            var extreme_item = iterator.next() orelse return null;
            var index: usize = 0;
            return while (iterator.next()) |item| : (index += 1) {
                if (comparator(extreme_item, item)) extreme_item = item;
            } else index;
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

/// # PartialOrdered
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
pub fn PartialOrdered(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self = contract.default(.Self, Contractor);
    return struct {
        pub const cmp: fn (Self, Self) ?Order = contract.default(.compare, anyCompareFn(Self));
        pub usingnamespace PartialEquivalent(Contractor, .{ .eq = struct {
            pub fn call(self: Self, other: Self) ?bool {
                return Order.optionEq(cmp(self, other), Order.equals);
            }
        }.call });

        pub fn lt(self: Self, other: Self) ?bool {
            return Order.optionEq(cmp(self, other), Order.forwards);
        }

        pub fn le(self: Self, other: Self) ?bool {
            return !Order.optionEq(cmp(self, other), Order.backwards);
        }

        pub fn gt(self: Self, other: Self) ?bool {
            return Order.optionEq(cmp(self, other), Order.backwards);
        }

        pub fn ge(self: Self, other: Self) ?bool {
            return !Order.optionEq(cmp(self, other), Order.forwards);
        }

        pub fn isClamped(self: Self, floor: Self, roof: Self) ?bool {
            std.debug.assert(le(floor, roof).?);
            const floor_self = le(floor, self) orelse return null;
            const self_roof = le(self, roof) orelse return null;
            return floor_self and self_roof;
        }

        pub fn clamped(self: Self, floor: Self, roof: Self) ?Self {
            std.debug.assert(le(floor, roof).?);
            const floor_self = le(self, floor) orelse return null;
            const self_roof = le(self, roof) orelse return null;
            return if (!floor_self) floor else if (!self_roof) roof else self;
        }

        pub fn isClampedStrict(self: Self, floor: Self, roof: Self) ?bool {
            std.debug.assert(lt(floor, roof).?);
            const floor_self = lt(floor, self) orelse return null;
            const self_roof = lt(self, roof) orelse return null;
            return floor_self and self_roof;
        }
    };
}

/// TODO
pub fn anyPartialCompareFn(comptime T: type) fn (T, T) ?Order {
    return struct {
        fn partialCompareItems(c: anytype, d: @TypeOf(c), order: Order) ?Order {
            const cd_order = anyPartialCompare(c, d) orelse return null;
            return switch (order) {
                .equals => cd_order,
                .forwards => if (cd_order.eq(.backwards)) null else order,
                .backwards => if (cd_order.eq(.forwards)) null else order,
            };
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

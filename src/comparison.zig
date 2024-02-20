const std = @import("std");
const utils = @import("utils.zig");
const contracts = @import("contracts.zig");
const iteration = @import("iteration.zig");
const Iterator = iteration.Iterator;

/// # Equivalent
///
/// The `Equivalent` interface relies on the existence of an equivalency function. A function
/// of type `fn (T, T) bool` that's assumed to be:
///
/// - reflexive: `∀x: T, eq(x, x)`
/// - symmetric: `∀x, y: T, eq(x, y) == eq(y, x)`
/// - transitive: `∀x, y, z: T, (eq(x, y) and eq(y, z)) => eq(x, z)`
///
/// ## Clauses
///
/// The only clause is the `.eq` clause that's a `fn (Self, Self) bool`.
///
/// ## Declarations
///
/// ### The equivalency function: `eq`
///
/// The `Equivalent` interface entirely rely on this function being reflexive, symmetric and
/// transitive. Therefore it's the main reason for using the testing module.
///
/// ### The universal quantifier: `allEq`
/// ### The existential quatifier: `anyEq`
/// ### Finding functions `firstEq`, `firstIndexEq`
///
/// These functions primary purpose isn't to be exposed. They're used internally by `allEq` and `anyEq`
/// ### The filter: `filterEq`
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
pub fn Equivalent(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const sample = contract.sample;
    // TODO: const ub_checked = contract.ub_checked;

    return struct {
        const Self: type = contract.Self;

        /// This function is the _equivalency_ from the `Equivalent` interface. It's assumed to be:
        /// - reflexive: `∀x: T, eq(x, x)`
        /// - symmetric: `∀x, y: T, eq(x, y) == eq(y, x)`
        /// - transitive: `∀x, y, z: T, (eq(x, y) and eq(y, z)) => eq(x, z)`
        pub const eq: fn (Self, Self) bool = contract.default(.eq, equalsFn(Self));

        /// This function is the _universal quantifier_ from the `Equivalent` interface.
        ///
        /// When `is_eq` is `true`, then it returns `true` when _**all**_ the items of the
        /// `iterator` are equivalent to `self`.
        /// - `∀x: iterator, eq(self, x)`
        ///
        /// When `is_eq` is `false`, then it returns `true` when _**none**_ of the items of the
        /// `iterator` are equivalent to `self`.
        /// - `∀x: iterator, !eq(self, x)`
        ///
        /// This function consumes the `iterator` argument.
        pub fn allEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) bool {
            return firstEq(self, !is_eq, iterator) == null;
        }

        /// This function is the _existantial quantifier_ from the `Equivalent` interface.
        ///
        /// When `is_eq` is `true` then it returns `true` if one the items of the `iterator` is
        /// equivalent to `self`.
        /// - `∃x: iterator, eq(self, x)`
        ///
        /// When `is_eq` is `false` then it returns `true` if one of the items of the `iterator`
        /// isn't equivalent to `self`.
        /// - `∃x: iterator, !eq(self, x)`
        ///
        /// This function consumes the `iterator` argument.
        pub fn anyEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) bool {
            return firstEq(self, is_eq, iterator) != null;
        }

        // TODO: doc
        pub fn firstIndexEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?usize {
            var index: usize = 0;
            return while (iterator.next()) |item| : (index += 1) {
                if (eq(self, item) == is_eq) break index;
            } else null;
        }

        // TODO: doc
        pub fn firstEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?Self {
            return while (iterator.next()) |item| {
                if (eq(self, item) == is_eq) break item;
            } else null;
        }

        /// This function returns an iterable that yields items from the `iterator` parameter.
        /// These items are yielded in the same order as `iterator`.
        ///
        /// If `is_eq` is `true`, then the result filters out the items that aren't equivalent to
        /// `self`.
        ///
        /// If `is_eq` is `false`, then the result filters out the items that are equivalent to
        /// `self`.
        pub fn filterEq(
            self: Self,
            comptime is_eq: bool,
            iterator: Iterator(Self),
        ) FilterEqIterator(is_eq) {
            return FilterEqIterator(is_eq){
                .filter = self,
                .iterator = iterator,
            };
        }

        /// This function returns `error.NonReflexive` if the set of items isn't reflexive.
        pub fn testingReflexiveEq(s: []const Self) !void {
            for (s) |x|
                if (!eq(x, x))
                    return error.NonReflexive;
        }

        /// This function returns `error.NonSymmetric` if the set of items isn't symmetric.
        pub fn testingEqSymmetry(s: []const Self) !void {
            for (s) |x| for (s) |y|
                if (eq(x, y) != eq(y, x))
                    return error.NonSymmetric;
        }

        /// This function returns `error.NonTransitive` if the set of items isn't transitive.
        pub fn testTransitiveEq(s: []const Self) !void {
            for (s) |x| for (s) |y| for (s) |z|
                if (eq(x, y) and eq(y, z) and !eq(x, z))
                    return error.NonTransitive;
        }

        test "Equivalent: Reflexivity" {
            try testingReflexiveEq(sample);
        }

        test "Equivalent: Symmetry" {
            try testingEqSymmetry(sample);
        }

        test "Equivalent: Transitivity" {
            try testTransitiveEq(sample);
        }

        fn FilterEqIterator(comptime is_eq: bool) type {
            return struct {
                const Filtered = @This();

                filter: Self,
                iterator: Iterator(Self),

                fn currFn(self: Filtered) ?Self {
                    return while (self.iterator.next()) |item| {
                        if (eq(self, item) == is_eq)
                            break item;
                    } else null;
                }

                fn skipFn(self: Filtered) void {
                    self.iterator.skip();
                }

                pub usingnamespace iteration.Iterable(Filtered, .{
                    .mutability = contracts.Mutability.by_val,
                    .curr = currFn,
                    .skip = skipFn,
                    .Item = Self,
                });
            };
        }
    };
}

/// This function returns an equality function. This equality is guaranteed to be:
/// - reflexive `∀x : equals(x, x)`
/// - symmetric `∀x, y : equals(x, y) == equals(y, x)`
/// - transitive `∀x, y, z : (equals(x, y) and equals(y, z)) => equals(x, z)`
pub fn equalsFn(comptime T: type) fn (T, T) bool {
    return struct {
        fn anyEquals(a: anytype, b: @TypeOf(a)) bool {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                // The following types are considered numerical values.
                .Bool,
                .ComptimeInt,
                .Enum,
                .EnumLiteral,
                .Int,
                // Types are their id, which is a numerical value.
                .Type,
                // Errors shouldn't be compared when they're in a union error, but here we're
                // comparing only errors between them, so it's fine.
                .ErrorSet,
                => a == b,
                // Floating points are the exception: they shouldn't be compared using `==`.
                // TODO: specialized equals with precision for floats
                .ComptimeFloat, .Float => utils.compileError(
                    "The `{s}.anyEquals` function shouldn't compare floating point `{s}`!",
                    .{ @typeName(T), @typeName(A) },
                ),
                // Void is a single-value type.
                .Void => true,
                // `null` and `undefined` should not be comparable to anything, they're not
                // representing data, or zero-sized data, but the absence of data.
                .Null, .Undefined => utils.compileError(
                    "The `{s}.anyEquals` function shouldn't compare `null` or `undefined`! " ++
                        "Consider using partial equality instead.",
                    .{@typeName(T)},
                ),
                // Comparing two items of different types doesn't make much sense, so partial
                // equality is better suited in this case!
                .ErrorUnion, .Optional, .Union => utils.compileError(
                    "Can't implement `{s}.anyEquals` function for a type `{s}` which is a sum " ++
                        "type! Consider using partial equality instead.",
                    .{ @typeName(T), @typeName(A) },
                ),
                // Structs, vectors and array are product types, two instances of them are equal if
                // all their members are equal.
                .Struct => |Struct| inline for (Struct.fields) |field| {
                    const field_a = @field(a, field.name);
                    const field_b = @field(b, field.name);
                    if (!anyEquals(field_a, field_b)) break false;
                } else true,
                .Vector, .Array => inline for (a, b) |c, d| {
                    if (!anyEquals(c, d)) break false;
                } else true,
                // Pointers are semantically meant to not hold any relevant data, but point to it.
                // So we're effectively not comparing pointers, but the data they're pointing to.
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => anyEquals(a.*, b.*),
                    else => utils.compileError(
                        "Can't implement `{s}.anyEquals` for type `{s}` which is a pointer to " ++
                            "a varying number of items! Consider using partial equality instead.",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // The following types, idk what to do, if there's anything to do.
                .AnyFrame, .Fn, .Frame, .Opaque, .NoReturn => utils.compileError(
                    "Can't implement `{s}.anyEquals` function for type `{s}` which is a `.{s}`!",
                    .{ @typeName(T), @typeName(A), @tagName(info) },
                ),
            };
        }

        pub fn equals(a: T, b: T) bool {
            return anyEquals(a, b);
        }
    }.equals;
}

/// # PartialEquivalent
///
/// The `PartialEquivalent` interface relies on the existence of an partial equivalency function.
/// A function of type `fn (T, T) bool?` that's assumed to be:
///
/// - almost reflexive, `∀x : eq(x, x) === true`,
/// - almost symmetric, `∀x, y : eq(x, y) === eq(y, x)`,
/// - almost transitive, `∀x, y, z : (eq(x, y) and eq(y, z)) or (eq(x, z) === false)`.
///
/// The "almost" operator ("===") returns true if one of its arguments is null, or if both are
/// equals.
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
pub fn PartialEquivalent(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const sample = contract.sample;
    return struct {
        const Self: type = contract.Self;
        /// This function is the partial equivalency function from the `PartialEquivalent`
        /// interface. It's assumed to be:
        /// - almost reflexive: `∀x : eq(x, x) === true`
        /// - almost symmetric: `∀x, y : eq(x, y) === eq(y, x)`
        /// - almost transitive: `∀x, y, z: (eq(x, y) and eq(y, z)) or (eq(x, z) === false)`
        pub const eq: fn (self: Self, other: Self) ?bool =
            contract.default(.eq, partialEqualsFn(Self));

        const PartialUsize = utils.Result(usize, usize);
        pub const PartialSelf = utils.Result(Self, Self);

        pub fn allEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?bool {
            const first = firstEqIndex(self, !is_eq, iterator) orelse return null;
            return first == .fail;
        }

        pub fn anyEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?bool {
            const first = firstEqIndex(self, is_eq, iterator) orelse return null;
            return first == .pass;
        }

        pub fn firstEqIndex(
            self: Self,
            comptime is_eq: bool,
            iterator: Iterator(Self),
        ) ?PartialUsize {
            var index: usize = 0;
            return while (iterator.next()) |item| : (index += 1) {
                const e = eq(self, item) orelse break PartialUsize{ .fail = index };
                if (e == is_eq) break PartialUsize{ .pass = index };
            } else null;
        }

        pub fn firstEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?PartialSelf {
            return while (iterator.next()) |item| {
                const e = eq(self, item) orelse break PartialUsize{ .fail = item };
                if (e == is_eq) break PartialUsize{ .pass = item };
            } else null;
        }

        pub fn filterEq(
            self: Self,
            comptime is_eq: bool,
            iterator: Iterator(Self),
        ) FilterPartialEqIterator(is_eq) {
            return FilterPartialEqIterator(is_eq){
                .filter = self,
                .iterator = iterator,
            };
        }

        /// This namespace contains functions and tests for the validity of the `PartialEquivalent`
        /// interface. The tests are using the `sample` clause on the testing functions.
        pub const testing_partial_equivalency = struct {
            pub fn testingAlmostReflexivity(s: []const Self) !void {
                for (s) |x| {
                    const x_x = eq(x, x) orelse continue;
                    if (!x_x)
                        return error.NoAlmostReflexivity;
                }
            }

            pub fn testingAlmostSymmetry(s: []const Self) !void {
                for (s) |x| for (s) |y| {
                    const x_y = eq(x, y) orelse continue;
                    const y_x = eq(y, x) orelse continue;
                    if (x_y != y_x)
                        return error.NoAlmostSymmetry;
                };
            }

            pub fn testingAlmostTransitivity(s: []const Self) !void {
                for (s) |x| for (s) |y| for (s) |z| {
                    const x_y = eq(x, y) orelse continue;
                    const y_z = eq(y, z) orelse continue;
                    const x_z = eq(x, z) orelse continue;
                    if (x_y and y_z and !x_z)
                        return error.NoAlmostTransitivity;
                };
            }

            fn maybeEq(a: ?bool, b: ?bool) bool {
                return partialEqualsFn(?bool)(a, b) orelse false;
            }

            test "Almost Reflexivity" {
                try testingAlmostReflexivity(sample);
            }

            test "Almost Symmetry" {
                try testingAlmostSymmetry(sample);
            }

            test "Almost Transitivity" {
                try testingAlmostTransitivity(sample);
            }
        };

        fn FilterPartialEqIterator(comptime is_eq: bool) type {
            return struct {
                const Filtered = @This();

                filter: Self,
                iterator: Iterator(Self),

                fn currFn(self: Filtered) ?PartialSelf {
                    return while (self.iterator.next()) |item| {
                        if (eq(self, item)) |e| {
                            if (e == is_eq) break PartialSelf{ .pass = item };
                        } else break PartialSelf{ .fail = item };
                    } else null;
                }

                fn skipFn(self: Filtered) void {
                    self.iterator.skip();
                }

                pub usingnamespace iteration.Iterable(Filtered, .{
                    .mutability = contracts.Mutability.by_val,
                    .curr = currFn,
                    .skip = skipFn,
                    .Item = Self,
                });
            };
        }
    };
}

/// This function returns a partial equality function for float types.
///
/// ## Usage
///
/// ```zig
/// const eq = floatPartialEqualsFn(f32, 0.10);
/// const nan: f32 = ...;
/// const inf: f32 = ...;
/// assert(eq(0.0, 0.05).?);
/// assert(!eq(0.0, 0.15).?);
/// assert(eq(0.0, nan) == null);
/// assert(eq(0.0, inf) == null);
/// ```
pub fn floatPartialEqualsFn(
    comptime Float: type,
    comptime precision: comptime_float,
) fn (Float, Float) ?bool {
    if (!std.math.isFinite(precision)) @compileError("Float precision must be a finite number!");
    if (precision < 0) @compileError("Float precision must be a positive number!");
    const info = @typeInfo(Float);
    switch (info) {
        .Float, .ComptimeFloat => {},
        else => utils.compileError(
            "`{s}` isn't a float type! It's a `.{s}` type!",
            .{ @typeName(Float), @tagName(info) },
        ),
    }

    return struct {
        pub fn call(self: Float, other: Float) ?bool {
            return if (!std.math.isFinite(self) or !std.math.isFinite(other))
                null
            else if (self < other)
                other - self < precision
            else if (other < self)
                self - other < precision
            else
                true;
        }
    }.call;
}

/// This function returns a partial equality function. This partial equality is guaranteed to be:
/// - symmetric `∀x, y : equals(x, y) == equals(y, x)`
/// - transitive `∀x, y, z : (equals(x, y) and equals(y, z)) => equals(x, z)`
pub fn partialEqualsFn(comptime T: type) fn (T, T) ?bool {
    return struct {
        fn anyPartialEquals(a: anytype, b: @TypeOf(a)) ?bool {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                // The following are considered numerical values
                .Bool,
                .ComptimeInt,
                .Enum,
                .EnumLiteral,
                .Int,
                // Types are their id, which is a numerical value.
                .Type,
                => a == b,
                // Floating points are the exception: they shouldn't be compared using `==`.
                .Float, .ComptimeFloat => utils.compileError(
                    "The `{s}.anyPartialEquals` function shouldn't compare floating point " ++
                        "`{s}`! Consider using `floatPartialEqualsFn`.",
                    .{ @typeName(T), @typeName(A) },
                ),
                // Void is a single-value type.
                .Void => true,
                // `null`, `undefined` and errors should not be comparable to anything, they're not
                // representing data, or zero-sized data, but the absence of data.
                .Null, .Undefined, .ErrorSet => null,
                // Comparing two values of different types doesn't make much sense, that's why sum
                // types must return null when two of them don't have the same variant active.
                .Optional => {
                    const yes_a = a orelse return null;
                    const yes_b = b orelse return null;
                    return anyPartialEquals(yes_a, yes_b);
                },
                .ErrorUnion => {
                    const yes_a = a catch return null;
                    const yes_b = b catch return null;
                    return anyPartialEquals(yes_a, yes_b);
                },
                .Union => |Union| if (Union.tag_type) |Tag| {
                    const tag_a = @field(Tag, @tagName(a));
                    const tag_b = @field(Tag, @tagName(b));
                    if (tag_a != tag_b) return null;
                    const payload_a = @field(a, @tagName(tag_a));
                    const payload_b = @field(b, @tagName(tag_b));
                    return anyPartialEquals(payload_a, payload_b);
                } else utils.compileError("In order to be compared unions must be tagged!", .{}),
                // Structs, vectors and array are product types. We are comparing their members one
                // by one, as pairs, following these rule:
                // 1. ∃(m1, m2) in (p1, p2) : (equals(m1, m2) == false)
                //   => (equals(p1, p2) == false)
                // 2. ∃(m1, m2) in (p1, p2) : (equals(m1, m2) == null)
                //   => ((equals(p1, p2) == false) or (equals(p1, p2) == null))
                // 3. ∀(m1, m2) in (p1, p2) : (equals(m1, m2) == true)
                //   => (equals(p1, p2) == true)
                //
                // In human language:
                // 1. If a pair of members returns false, then the pair of products returns false.
                // 2. If a pair of members returns null, then the pair of products returns false or
                //    null.
                // 3. If all the pairs of members return true, then the pair of products return
                //    true.
                .Struct => |Struct| {
                    var has_null = false;
                    return inline for (Struct.fields) |field| {
                        const field_a = @field(a, field.name);
                        const field_b = @field(b, field.name);
                        const equality = anyPartialEquals(field_a, field_b);
                        if (equality) |e| {
                            if (!e) break false;
                        } else has_null = true;
                    } else if (has_null) null else true;
                },
                .Vector, .Array => {
                    var has_null = false;
                    return inline for (a, b) |c, d| {
                        if (anyPartialEquals(c, d)) |equality| {
                            if (!equality) break false;
                        } else has_null = true;
                    } else if (has_null) null else true;
                },
                .Pointer => |Pointer| switch (Pointer.size) {
                    // Pointers are semantically meant to not hold any relevant data, but point to
                    // it. So we're effectively not comparing pointers, but the data they're
                    // pointing to.
                    .One => anyPartialEquals(a.*, b.*),
                    // Any multi-item pointer is similar to a pointer to an array. We can emulate
                    // this when both pointers have the same length. Else we can just return null.
                    .Slice => {
                        var has_null = false;
                        return if (a.len != b.len) null else for (a, b) |c, d| {
                            if (anyPartialEquals(c, d)) |equality| {
                                if (!equality) break false;
                            } else has_null = true;
                        } else if (has_null) null else true;
                    },
                    // If they were terminated, other pointers could emulate slices, but I'm not
                    // sure how I should test for equality with the sentinel.
                    else => utils.compileError(
                        "Can't implement `{s}.anyPartialEquals` function for type `{s}` which" ++
                            " is a {s}-pointer to `{s}`!",
                        .{ @typeName(T), @tagName(Pointer.size), @typeName(Pointer.child) },
                    ),
                },
                // The following types, idk what to do, if there's anything to do.
                .AnyFrame, .Frame, .Fn, .Opaque, .NoReturn => utils.compileError(
                    "Can't implement `{s}.anyPartialEquals` function for type `{s}` which is a `.{s}`!",
                    .{ @typeName(T), @typeName(A), @tagName(info) },
                ),
            };
        }

        pub fn partialEquals(a: T, b: T) ?bool {
            return anyPartialEquals(a, b);
        }
    }.partialEquals;
}

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
    const Self: type = contract.Self;
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
                    else => utils.compileError(
                        "The `{s}.anyCompare` function can't compare complex types like `{s}`!",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // TODO: handle each case individually for better errors!
                else => utils.compileError(
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
    const Self: type = contract.Self;
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
                } else utils.compileError("In order to be compared unions must be tagged!", .{}),
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => anyPartialCompare(a.*, b.*),
                    .Slice => if (a.len != b.len) null else {
                        var ab_order = Order.equals;
                        return for (a, b) |c, d| {
                            ab_order = partialCompareItems(c, d, ab_order) orelse break null;
                        } else ab_order;
                    },
                    // TODO: better error messages!
                    else => utils.compileError(
                        "The `{s}.anyPartialCompare` function can't compare complex types like `{s}`!",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // TODO: better error messages!
                else => utils.compileError(
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

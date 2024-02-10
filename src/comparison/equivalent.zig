const std = @import("std");
const utils = @import("../utils.zig");
const contracts = @import("../contracts.zig");
const collections = @import("../collections.zig");
const Iterator = collections.iterating.Iterator;

/// # Equivalent
///
/// The `Equivalent` interface relies on the existence of an equivalency function. A function
/// of type `fn (T, T) bool` that's assumed to be:
///
/// - reflexive: `∀x : eq(x, x)`
/// - symmetric: `∀x, y : eq(x, y) == eq(y, x)`
/// - transitive: `∀x, y, z: (eq(x, y) and eq(y, z)) or !eq(x, z)`
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
pub fn Equivalent(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.getSelf();
    const sample: []const Self = contract.getSample();
    return struct {
        /// This function is the equivalency function from the `Equivalent` interface. It's assumed
        /// to be:
        /// - reflexive: `∀x : eq(x, x)`
        /// - symmetric: `∀x, y : eq(x, y) == eq(y, x)`
        /// - transitive: `∀x, y, z: (eq(x, y) and eq(y, z)) or !eq(x, z)`
        pub const eq: fn (self: Self, other: Self) bool = contract.default(.eq, equalsFn(Self));

        pub fn allEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) bool {
            return firstEq(self, !is_eq, iterator) == null;
        }

        pub fn anyEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) bool {
            return firstEq(self, is_eq, iterator) != null;
        }

        pub fn firstEqIndex(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?usize {
            var index: usize = 0;
            return while (iterator.next()) |item| : (index += 1) {
                if (eq(self, item) == is_eq) break index;
            } else null;
        }

        pub fn firstEq(self: Self, comptime is_eq: bool, iterator: Iterator(Self)) ?Self {
            return while (iterator.next()) |item| {
                if (eq(self, item) == is_eq) break item;
            } else null;
        }

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

        fn FilterEqIterator(comptime is_eq: bool) type {
            return struct {
                const Filtered = @This();

                filter: Self,
                iterator: Iterator(Self),

                fn currFn(self: Filtered) ?Self {
                    return while (self.iterator.curr()) |item| {
                        if (eq(self, item) == is_eq)
                            break item
                        else
                            self.iterator.skip();
                    } else null;
                }

                fn skipFn(self: Filtered) void {
                    self.iterator.skip();
                }

                pub usingnamespace collections.iterating.Iterable(Filtered, .{
                    .mutation = contracts.Mutation.by_val,
                    .curr = currFn,
                    .skip = skipFn,
                    .Item = Self,
                });
            };
        }

        /// This namespace contains functions and tests for the validity of the `Equivalent`
        /// interface. The tests are using the `sample` clause on the testing functions.
        pub const testing_equivalency = struct {
            pub fn testingReflexivity(s: []const Self) !void {
                for (s) |x|
                    if (!eq(x, x))
                        return error.NoReflexivity;
            }

            pub fn testingSymmetry(s: []const Self) !void {
                for (s) |x| for (s) |y|
                    if (eq(x, y) != eq(y, x))
                        return error.NoSymmetry;
            }

            pub fn testingTransitivity(s: []const Self) !void {
                for (s) |x| for (s) |y| for (s) |z|
                    if (eq(x, y) and eq(y, z) and !eq(x, z))
                        return error.NoTransitivity;
            }

            test "Equivalent: Reflexivity" {
                try testingReflexivity(sample);
            }

            test "Equivalent: Symmetry" {
                try testingSymmetry(sample);
            }

            test "Equivalent: Transitivity" {
                try testingTransitivity(sample);
            }
        };
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
    const Self: type = contract.getSelf();
    const sample: []const Self = contract.getSample();
    return struct {
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

            test "PartialEquivalent: Almost Reflexivity" {
                try testingAlmostReflexivity(sample);
            }

            test "PartialEquivalent: Almost Symmetry" {
                try testingAlmostSymmetry(sample);
            }

            test "PartialEquivalent: Almost Transitivity" {
                try testingAlmostTransitivity(sample);
            }
        };

        fn FilterPartialEqIterator(comptime is_eq: bool) type {
            return struct {
                const Filtered = @This();

                filter: Self,
                iterator: Iterator(Self),

                fn currFn(self: Filtered) ?PartialSelf {
                    return while (self.iterator.curr()) |item| {
                        if (eq(self, item)) |e| {
                            if (e == is_eq)
                                break item
                            else
                                self.iterator.skip();
                        } else break PartialSelf{ .fail = item };
                    } else null;
                }

                fn skipFn(self: Filtered) void {
                    self.iterator.skip();
                }

                pub usingnamespace collections.iterating.Iterable(Filtered, .{
                    .mutation = contracts.Mutation.by_val,
                    .curr = currFn,
                    .skip = skipFn,
                    .Item = Self,
                });
            };
        }
    };
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
                    "The `{s}.anyPartialEquals` function shouldn't compare floating point `{s}`!",
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

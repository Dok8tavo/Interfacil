const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");

/// # Equivalent
/// This interface is useful when dealing with a function with two parameter of the same type that
/// happen to be an equivalency. It provides a few unit tests, wraps the equivalency into a few ub
/// checks, and provides a few additional functions.
///
/// By default this is the equivalency function is an equality function returned by `equalsFn`.
///
/// ## Equivalency
///
/// An equivalency is a function `eq: fn (Self, Self) bool` that is:
///
/// - reflexive: `∀x : eq(x, x)`,
/// - symmetric: `∀x, y : eq(x, y) == eq(y, x)`,
/// - transitive: `∀x, y, z : eq(x, y) and eq(y, z) => eq(x, z)`
///
/// ## API
///
/// ```zig
/// allEq: fn (Self, []const Self) bool,
/// anyEq: fn (Self, []const Self) ?usize,
/// eq: fn (Self, Self) bool,
/// filteredAllEq: fn ([]const Self, []const Self, []Self) ![]Self,
/// filterAllEq: fn ([]const Self, []Self) []Self,
/// fielteredEq: fn (Self, []const Self, []Self) ![]Self,
/// filterEq: fn (Self, []Self) ![]Self,
/// equivalency_tests: struct {
///     reflexivity: fn ([]const Self) !void,
///     symmetry: fn ([]const Self) !void,
///     transitivity: fn ([]const Self) !void,
///
///     test "Equivalency is reflexive";
///     test "Equivalency is symmetric";
///     test "Equivalency is transitive";
///     test "Equivalency";
/// },
/// ```
///
/// ## Clauses
///
/// ```zig
/// eq: fn (Self, Self) bool = equalsFn(Self),
/// ub_checked: bool = true,
/// sample: []const Self = &[_]Self{},
/// Self: type = Contractor,
/// ```
pub fn Equivalent(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        /// This function checks if all the items of the `slice` parameter are equivalent to the
        /// `self` parameter.
        pub fn allEq(
            self: Self,
            slice: []const Self,
        ) bool {
            return for (slice) |item| {
                if (!eq(self, item)) break false;
            } else true;
        }

        /// This function checks if there's at least one item of the `slice` parameter that's
        /// equivalent to the `self` parameter.
        pub fn anyEq(self: Self, slice: []const Self) ?usize {
            return for (slice, 0..) |item, i| {
                if (eq(self, item)) break i;
            } else null;
        }

        /// This function counts how many items of the `slice` parameter are equivalent to the
        /// `self` parameter.
        pub fn countEq(self: Self, slice: []const Self) usize {
            var count: usize = 0;
            for (slice) |item| {
                if (eq(self, item)) count += 1;
            }
            return count;
        }

        /// This function checks if the `self` parameter is equivalent to the `other` parameter.
        pub const eq: fn (self: Self, other: Self) bool =
            if (ub_checked) checkedEq else uncheckedEq;

        /// This function filter out all the elements of the `filtered` parameters that are
        /// equivalent to one item of the `filters` parameter.
        pub fn filterAllEq(filters: []const Self, filtered: []Self) []Self {
            return filteredAllEq(filters, filtered, filtered) catch unreachable;
        }

        /// This function filter out all the elements of the `filtered` parameters that are
        /// equivalent to the `self` parameter.
        pub fn filterEq(self: Self, filtered: []Self) []Self {
            return filteredEq(self, filtered, filtered) catch unreachable;
        }

        /// This function copy all the items of the `from` parameter that aren't equivalent to any
        /// item of the `filters` parameter into the `into` parameter.
        pub fn filteredAllEq(
            filters: []const Self,
            from: []const Self,
            into: []Self,
        ) error{OutOfMemory}![]Self {
            var index: usize = 0;
            return for (from) |item| {
                if (anyEq(item, filters)) |_| continue;
                if (index == into.len) break error.OutOfMemory;
                into[index] = item;
                index += 1;
            } else into[0..index];
        }

        /// This function copy all the items of the `from` parameter that aren't equivalent to the
        /// `self` parameter into the `into` parameter.
        pub fn filteredEq(
            self: Self,
            from: []const Self,
            into: []Self,
        ) error{OutOfMemory}![]Self {
            return try filteredAllEq(&[_]Self{self}, from, into);
        }

        /// This function checks if the `self` parameter isn't equivalent to the `other` parameter.
        pub fn no(self: Self, other: Self) bool {
            return !eq(self, other);
        }

        /// This function is either defined and declared by the user, or using `anyEq` by default.
        const uncheckedEq: fn (Self, Self) bool = contract.default(.eq, defaultEq);

        /// This boolean decides whether the program should check during runtime if equality
        /// actually is symmetric and reflexive. If not, it'll panic in debug mode, with a
        /// meaningful error message, in other modes it'll reach unreachable.
        ///
        /// As those checks have very bad complexity they're only done on calls for two elements,
        /// only `eq` and `no`. As there's no way to check for transitivity with two elements on
        /// a symmetric and reflexive relation, transitivity is not checked during runtime.
        const ub_checked: bool = contract.default(.ub_checked, true);

        const defaultEq: fn (Self, Self) bool = equalsFn(Self);

        /// This function wraps the `eq` function inside checks for symmetry and reflexivity. Those
        /// checks are only available in debug builds. They slow down debug builds but speed up
        /// unsafe builds.
        fn checkedEq(self: Self, other: Self) bool {
            const self_other = uncheckedEq(self, other);
            const other_self = uncheckedEq(other, self);
            const is_symmetric = self_other == other_self;

            misc.checkUB(!is_symmetric,
                \\The `{s}.eq` function isn't symmetric:
                \\    {any} {s} {any}
                \\    {any} {s} {any}
            , .{
                @typeName(Self),
                self,
                if (self_other) "===" else "!==",
                other,
                other,
                if (other_self) "===" else "!==",
                self,
            });

            inline for (.{ self, other }) |item| {
                const is_reflexive = uncheckedEq(item, item);
                misc.checkUB(!is_reflexive,
                    \\The `{s}.eq` function isn't reflexive:
                    \\   {any} !== {any}
                , .{
                    @typeName(Self),
                    item,
                    item,
                });
            }

            return self_other;
        }

        const Self: type = contract.default(.Self, Contractor);

        /// This namespace is a testing namespace for the `Equivalent` interface. It's intended to be
        /// used in tests, the functions inside have horrible complexity.
        pub const equivalency_tests = struct {
            /// This function fails when `∀x : x === x` is false in the given sample.
            ///
            /// It has a complexity of `O(n)`, with `n` being the length of  the sample, and
            /// assuming that the provided `eq` function is `O(1)`.
            pub fn reflexivity(sample: []const Self) ReflexivityError!void {
                if (!contract.hasClause(.eq)) return;
                for (sample) |x|
                    if (!testEq(x, x))
                        return ReflexivityError.EqualityIsNotReflexive;
            }

            /// This function fails when `∀x, y : (x === y) => (y === x)` is false in the given
            /// sample.
            ///
            /// It has a time complexity of `O(n^2)`, with `n` being the length of  the sample,
            /// and assuming that the provided `eq` function is `O(1)`.
            pub fn symmetry(sample: []const Self) SymmetryError!void {
                if (!contract.hasClause(.eq)) return;
                for (sample) |x| for (sample) |y|
                    if (testEq(x, y) and !testEq(y, x))
                        return SymmetryError.EqualityIsNotSymmetric;
            }

            /// This function fails when `∀x, y, z : ((x === y) & (y === z)) => (x === z)` is false
            /// in the given sample.
            ///
            /// It has a time complexity of `O(n^3)`, with `n` being the length of  the sample,
            /// and assuming that the provided `eq` function is `O(1)`.
            pub fn transitivity(sample: []const Self) TransitivityError!void {
                if (!contract.hasClause(.eq)) return;
                for (sample) |x| for (sample) |y| for (sample) |z|
                    //     ∀x, y, z : ((x === y) & (y === z)) => (x === z)
                    // <=> ∀x, y, z : !((x === y) & (y === z)) | (x === z)
                    // <=> ∀x, y, z : (!(x === y) | !(y === z)) | (x === z)
                    // <=> ∀x, y, z : (x !== y) | (y !== z) | (x === z)
                    if (!testEq(x, y) or !testEq(y, z) or testEq(x, z))
                        return TransitivityError.EqualityIsNotTransitive;
            }

            pub const ReflexivityError = error{EqualityIsNotReflexive};
            pub const SymmetryError = error{EqualityIsNotSymmetric};
            pub const TransitivityError = error{EqualityIsNotTransitive};

            /// This equivalent function should be used for tests. It must be unchecked, otherwise
            /// there might be infinite recursive call on checking functions.
            const testEq: fn (Self, Self) bool = uncheckedEq;

            /// This slice is a sample used for making tests. It can be useful when certain
            /// combinations of instances of `Contractor`
            const testing_sample: []const Self = contract.default(.sample, @as([]const Self, &.{}));

            test "Equivalency is reflexive" {
                try reflexivity(testing_sample);
            }

            test "Equivalency is symmetric" {
                try symmetry(testing_sample);
            }

            test "Equivalency is transitive" {
                try transitivity(testing_sample);
            }

            test "Equivalency" {
                try reflexivity(testing_sample);
                try symmetry(testing_sample);
                try transitivity(testing_sample);
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
                .ErrorSet,
                .Int,
                // Types are their id, which is a numerical value.
                .Type,
                => a == b,
                // Floating points are the exception: they shouldn't be compared using `==`.
                .ComptimeFloat, .Float => misc.compileError(
                    "The `{s}.anyEquals` function shouldn't compare floating point `{s}`!",
                    .{ @typeName(T), @typeName(A) },
                ),
                // Void is a single-value type.
                .Void => true,
                // `null` and `undefined` should not be comparable to anything, they're not
                // representing data, or zero-sized data, but the absence of data.
                .Null, .Undefined => misc.compileError(
                    "The `{s}.anyEquals` function shouldn't compare `null` or `undefined`! " ++
                        "Consider using partial equality instead.",
                    .{@typeName(T)},
                ),
                // Comparing two items of different types doesn't make much sense, so partial
                // equality is better suited in this case!
                .ErrorUnion, .Optional, .Union => misc.compileError(
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
                    else => misc.compileError(
                        "Can't implement `{s}.anyEquals` for type `{s}` which is a pointer to " ++
                            "a varying number of items! Consider using partial equality instead.",
                        .{ @typeName(T), @typeName(A) },
                    ),
                },
                // The following types, idk what to do, if there's anything to do.
                .AnyFrame, .Fn, .Frame, .Opaque, .NoReturn => misc.compileError(
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

pub fn PartiallyEquivalent(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        /// This function checks if the `self` parameter is equivalent to the `other` parameter.
        pub const eq: fn (self: Self, other: Self) ?bool =
            if (ub_checked) checkedEq else uncheckedEq;

        // TODO
        const checkedEq = uncheckedEq;
        const uncheckedEq: fn (self: Self, other: Self) ?bool =
            contract.default(.eq, partiallyEqualsFn(Self));

        const ub_checked: bool = contract.default(.un_checked, true);
        const Self: type = contract.default(.Self, Contractor);
    };
}

/// This function returns a partial equality function. This partial equality is guaranteed to be:
/// - symmetric `∀x, y : equals(x, y) == equals(y, x)`
/// - transitive `∀x, y, z : (equals(x, y) and equals(y, z)) => equals(x, z)`
pub fn partiallyEqualsFn(comptime T: type) fn (T, T) ?bool {
    return struct {
        fn anyPartiallyEquals(a: anytype, b: @TypeOf(a)) ?bool {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                .Bool,
                .ComptimeInt,
                .Enum,
                .EnumLiteral,
                .ErrorSet,
                .Int,
                .Type,
                => a == b,
                .Float, .ComptimeFloat => misc.compileError(
                    "The `{s}.anyPartialEquals` function shouldn't compare floating point `{s}`!",
                    .{ @typeName(T), @typeName(A) },
                ),
                .Void => true,
                .Null, .Undefined => null,
                .Optional => {
                    const yes_a = a orelse return null;
                    const yes_b = b orelse return null;
                    return anyPartiallyEquals(yes_a, yes_b);
                },
                .ErrorUnion => {
                    const yes_a = a catch return null;
                    const yes_b = b catch return null;
                    return anyPartiallyEquals(yes_a, yes_b);
                },
                .Union => |Union| if (Union.tag_type) |Tag| {
                    const tag_a = @field(Tag, @tagName(a));
                    const tag_b = @field(Tag, @tagName(b));
                    if (tag_a != tag_b) return null;
                    const payload_a = @field(a, @tagName(tag_a));
                    const payload_b = @field(b, @tagName(tag_b));
                    return anyPartiallyEquals(payload_a, payload_b);
                } else misc.compileError("", .{}),
                .Struct => |Struct| {
                    var has_null = false;
                    return inline for (Struct.fields) |field| {
                        const field_a = @field(a, field.name);
                        const field_b = @field(b, field.name);
                        const equality = anyPartiallyEquals(field_a, field_b);
                        if (equality) |e| {
                            if (!e) break false;
                        } else has_null = true;
                    } else if (has_null) null else true;
                },
                .Vector, .Array => {
                    var has_null = false;
                    return inline for (a, b) |c, d| {
                        if (anyPartiallyEquals(c, d)) |equality| {
                            if (!equality) break false;
                        } else has_null = true;
                    } else if (has_null) null else true;
                },
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => anyPartiallyEquals(a.*, b.*),
                    .Slice => {
                        var has_null = false;
                        return if (a.len != b.len) null else for (a, b) |c, d| {
                            if (anyPartiallyEquals(c, d)) |equality| {
                                if (!equality) break false;
                            } else has_null = true;
                        } else if (has_null) null else true;
                    },
                },
                .AnyFrame, .Frame, .Fn, .Opaque, .NoReturn => misc.compileError(
                    "Can't implement `{s}.anyEquals` function for type `{s}` which is a `.{s}`!",
                    .{ @typeName(T), @typeName(A), @tagName(info) },
                ),
            };
        }

        pub fn partiallyEquals(a: T, b: T) ?bool {
            return anyPartiallyEquals(a, b);
        }
    }.partiallyEquals;
}

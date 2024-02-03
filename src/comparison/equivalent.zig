const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");

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
/// ### Methods
///
/// The `eq` method is defaulted to an equality function returned by `equalsFn`. It's most of the
/// time the one you want, however if you truly want an equivalency and not an equality, you
/// probably will have to write it on your own.
///
/// All methods have a default implementation that'll most likely be the one you want. But in case
/// there are some invariants you want to take advantage of, you can override them.
///
/// ```zig
/// const Clauses = struct {
///     eq: fn (Self, Self) bool,
///     no: fn (Self, Self) bool,
///     allEq: fn (Self, []const Self) bool,
///     anyEq: fn (Self, []const Self) bool,
///     allNo: fn (Self, []const Self) bool,
///     anyNo: fn (Self, []const Self) bool,
///     filteredEq: fn (Self, []const Self, []Self) BoundsError![]Self,
///     filteredNo: fn (Self, []const Self, []Self) BoundsError![]Self,
///     filterEq: fn (Self, []Self) []Self,
///     filterNo: fn (Self, []Self) []Self,
/// };
/// ```
///
/// ### Others
///
/// The `Self` clause lets you specify another type than the contractor.
///
/// The `sample` clause lets you specify the sample slice on which tests will be performed.
///
/// The `max_sample_length` clause lets you define what length should the testing functions be
/// limited to.
///
/// ## Declarations
///
/// The returned namespace exposes the following declarations:
///
/// ```zig
/// const namespace = struct {
///     eq: fn (Self, Self) bool,
///     no: fn (Self, Self) bool,
///     allEq: fn (Self, []const Self) bool,
///     anyEq: fn (Self, []const Self) bool,
///     allNo: fn (Self, []const Self) bool,
///     anyNo: fn (Self, []const Self) bool,
///     filteredEq: fn (Self, []const Self, []Self) BoundsError![]Self,
///     filteredNo: fn (Self, []const Self, []Self) BoundsError![]Self,
///     filterEq: fn (Self, []Self) []Self,
///     filterNo: fn (Self, []Self) []Self,
///     testing_equivalency: type,
/// };
/// ```
///
/// The `testing_equivalency` namespace exposes the following declarations:
///
/// ```zig
/// const testing_equivalency = struct {
///     testingEq: fn ([]const Self) anyerror!void,
///     testingNo: fn ([]const Self) anyerror!void,
///     testingAllEq: fn ([]const Self) anyerror!void,
///     testingAnyEq: fn ([]const Self) anyerror!void,
///     testingAllNo: fn ([]const Self) anyerror!void,
///     testingAnyNo: fn ([]const Self) anyerror!void,
///     testingFilteredEq: fn ([]const Self) anyerror!void,
///     testingFilteredNo: fn ([]const Self) anyerror!void,
///     testingFilterEq: fn ([]Self) anyerror!void,
///     testingFilterNo: fn ([]Self) anyerror!void,
/// };
/// ```
pub fn Equivalent(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        /// This function is the equivalency function from the `Equivalent` interface. It's assumed
        /// to be:
        /// - reflexive: `∀x : eq(x, x)`
        /// - symmetric: `∀x, y : eq(x, y) == eq(y, x)`
        /// - transitive: `∀x, y, z: (eq(x, y) and eq(y, z)) or !eq(x, z)`
        pub const eq: fn (self: Self, other: Self) bool = contract.default(.eq, equalsFn(Self));

        /// This function is the non-equivalency function from the `Equivalent` interface. It's
        /// assumed to be:
        /// - antireflexive: `∀x : !no(x, x)`
        /// - symmetric: `∀x, y : no(x, y) == no(y, x)`
        /// - the opposite of `eq`: `∀x, y : eq(x, y) != no(x, y)`
        pub const no: fn (self: Self, other: Self) bool = contract.default(.no, defaultNo);

        /// This function checks that all items of the `slice` parameter are equivalent to the
        /// `self` parameter, i.e. that `eq(self, item) == true`.
        ///
        /// It basically returns `∀x in slice : eq(self, x)`.
        pub const allEq: fn (self: Self, slice: []const Self) bool =
            contract.default(.allEq, defaultAllEq);

        /// This function checks that there's at least one item of the `slice` parameter that's
        /// equivalent to the `self` parameter, i.e. that `eq(self, item) == true`.
        ///
        /// It basically returns `∃x in slice : eq(self, x)`.
        pub const anyEq: fn (self: Self, slice: []const Self) bool =
            contract.default(.allEq, defaultAnyEq);

        /// This function checks that none of the items of the `slice` parameter is equivalent to
        /// the `self` parameter, i.e. that `eq(self, item) == false`.
        ///
        /// It basically returns `∀x in slice : no(self, x)`.
        pub const allNo: fn (self: Self, slice: []const Self) bool =
            contract.default(.allNo, defaultAllNo);

        /// This function checks that there's at least one item of the `slice` parameter that's
        /// not equivalent to the `self` parameter, i.e. that `eq(self, item) == false`.
        ///
        /// It basically returns `∃x in slice : no(self, x)`.
        pub const anyNo: fn (self: Self, slice: []const Self) bool =
            contract.default(.anyNo, defaultAnyNo);

        /// This function returns the items of the `slice` parameter that are equivalent to the
        /// `self` parameter. A successful return is guaranteed to be a slice with:
        ///
        /// - `∀x in result : eq(self, x)`
        /// - `allEq(self, result)`
        /// - `!anyNo(self, result)`
        pub const filteredEq: fn (
            self: Self,
            slice: []const Self,
            into: []Self,
        ) BoundsError![]Self = contract.default(.filteredEq, defaultFilteredEq);

        /// This function returns the items of the `slice` parameter that are not equivalent to
        /// the `self` parameter. A successful return is guaranteed to be a slice with:
        ///
        /// - `∀x in result : no(self, x)`,
        /// - `allNo(self, result)`
        /// - `!anyEq(self, result)`
        pub const filteredNo: fn (
            self: Self,
            slice: []const Self,
            into: []Self,
        ) BoundsError![]Self = contract.default(.filteredNo, defaultFilteredNo);

        /// This function is a shorthand for `filteredEq(self, slice, silce) catch unreachable`
        pub const filterEq: fn (self: Self, slice: []Self) []Self =
            contract.default(.filterEq, defaultFilterEq);

        /// This function is a shorthand for `filteredNo(self, slice, silce) catch unreachable`
        pub const filterNo: fn (self: Self, slice: []Self) []Self =
            contract.default(.filterNo, defaultFilterNo);

        const Self: type = contract.default(.Self, Contractor);
        const sample: []const Self = contract.default(.sample, default_sample);
        const max_sample_length = contract.default(.max_sample_length, @max(sample.len, 16));

        fn defaultNo(self: Self, other: Self) bool {
            return !eq(self, other);
        }

        fn defaultAllEq(self: Self, slice: []const Self) bool {
            return for (slice) |item| {
                if (no(self, item)) break false;
            } else true;
        }

        fn defaultAnyEq(self: Self, slice: []const Self) bool {
            return for (slice) |item| {
                if (eq(self, item)) break true;
            } else false;
        }

        fn defaultAllNo(self: Self, slice: []const Self) bool {
            return for (slice) |item| {
                if (eq(self, item)) break false;
            } else true;
        }

        fn defaultAnyNo(self: Self, slice: []const Self) bool {
            return for (slice) |item| {
                if (no(self, item)) break true;
            } else false;
        }

        fn defaultFilteredEq(self: Self, slice: []const Self, into: []Self) BoundsError![]Self {
            var index: usize = 0;
            for (slice) |item| if (no(self, item)) {
                if (index == into.len) return BoundsError.OutOfBounds;
                into[index] = item;
                index += 1;
            };

            return into[0..index];
        }

        fn defaultFilteredNo(self: Self, slice: []const Self, into: []Self) BoundsError![]Self {
            var index: usize = 0;
            for (slice) |item| if (eq(self, item)) {
                if (index == into.len) return BoundsError.OutOfBounds;
                into[index] = item;
                index += 1;
            };

            return into[0..index];
        }

        fn defaultFilterEq(self: Self, slice: []Self) []Self {
            return filteredEq(self, slice, slice) catch unreachable;
        }

        fn defaultFilterNo(self: Self, slice: []Self) []Self {
            return filteredNo(self, slice, slice) catch unreachable;
        }

        const default_sample: []const Self = &[_]Self{};
        const BoundsError = error{OutOfBounds};

        /// This namespace contains functions and tests for the validity of the `Equivalent`
        /// interface. The tests are using the `sample` clause on the testing functions.
        pub const testing_equivalency = struct {
            pub fn testingReflexivity(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x|
                    if (no(x, x))
                        return error.NoReflexivity;
            }

            pub fn testingSymmetry(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x| for (s) |y|
                    if (eq(x, y) != eq(y, x))
                        return error.NoSymmetry;
            }

            pub fn testingTransitivity(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x| for (s) |y| for (s) |z|
                    if (eq(x, y) and eq(y, z) and no(x, z))
                        return error.NoTransitivity;
            }

            pub fn testingNo(s: []const Self) !void {
                if (contract.hasClause(.no)) return;
                for (s) |x| for (s) |y|
                    if (no(x, y) == eq(x, y))
                        return error.MisimplementedNo;
            }

            pub fn testingAllEq(s: []const Self) !void {
                if (contract.hasClause(.allEq)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (allEq(x, s[start..end]) != defaultAllEq(x, s[start..end]))
                        return error.MisimplementedAllEq;
            }

            pub fn testingAnyEq(s: []const Self) !void {
                if (contract.hasClause(.anyEq)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (anyEq(x, s[start..end]) != defaultAnyEq(x, s[start..end]))
                        return error.MisimplementedAnyEq;
            }

            pub fn testingAllNo(s: []const Self) !void {
                if (contract.hasClause(.allNo)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (allNo(x, s[start..end]) != defaultAllNo(x, s[start..end]))
                        return error.MisimplementedAllNo;
            }

            pub fn testingAnyNo(s: []const Self) !void {
                if (contract.hasClause(.anyNo)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (anyNo(x, s[start..end]) != defaultAnyNo(x, s[start..end]))
                        return error.MisimplementedAnyNo;
            }

            pub fn testingFilteredEq(s: []const Self) !void {
                if (contract.hasClause(.filteredEq)) return;
                var buffer1: [max_sample_length]Self = undefined;
                var buffer2: [max_sample_length]Self = undefined;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end| {
                    const filtered1 = filteredEq(x, s[start..end], &buffer1);
                    const filtered2 = defaultFilteredEq(x, s[start..end], &buffer2);
                    if (filtered1) |f1| {
                        if (filtered2) |f2| {
                            if (f1.len != f2.len) return error.MisimplementedFilteredEq;
                            for (f1) |y| if (no(x, y)) return error.MisimplementedFilteredEq;
                        } else return error.MisimplementedFilteredEq;
                    } else if (filtered2) |_| return error.MisimplementedFilteredEq;
                };
            }

            pub fn testingFilteredNo(s: []const Self) !void {
                if (contract.hasClause(.filteredNo)) return;
                var buffer1: [max_sample_length]Self = undefined;
                var buffer2: [max_sample_length]Self = undefined;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end| {
                    const filtered1 = filteredNo(x, s[start..end], &buffer1);
                    const filtered2 = defaultFilteredNo(x, s[start..end], &buffer2);
                    if (filtered1) |f1| {
                        if (filtered2) |f2| {
                            if (f1.len != f2.len) return error.MisimplementedFilteredEq;
                            for (f1) |y| if (eq(x, y)) return error.MisimplementedFilteredEq;
                        } else return error.MisimplementedFilteredEq;
                    } else if (filtered2) |_| return error.MisimplementedFilteredEq;
                };
            }

            pub fn testingFilterEq(s: []const Self) !void {
                if (contract.hasClause(.filterEq)) return;
                var buffer1: [max_sample_length]Self = undefined;
                var buffer2: [max_sample_length]Self = undefined;
                const max = @min(s.len, sample.len);
                for (s) |x| for (0..s.len) |start| for (start..max + start) |end| {
                    for (s[start..end], 0..) |item, i| {
                        buffer1[i] = item;
                        buffer2[i] = item;
                    }

                    const slice1: []Self = buffer1[0..end];
                    const slice2: []Self = buffer2[0..end];
                    const result1 = filterEq(x, slice1);
                    const result2 = defaultFilterEq(x, slice2);

                    if (result1.len != result2.len) return error.MisimplementedFilterEq;
                    for (result1, result2) |item1, item2|
                        if (no(item1, item2))
                            return error.MisimplementedFilterEq;
                };
            }

            pub fn testingFilterNo(s: []const Self) !void {
                if (contract.hasClause(.filterNo)) return;
                var buffer1: [max_sample_length]Self = undefined;
                var buffer2: [max_sample_length]Self = undefined;
                const max = @min(s.len, sample.len);
                for (s) |x| for (0..s.len) |start| for (start..max + start) |end| {
                    for (s[start..end], 0..) |item, i| {
                        buffer1[i] = item;
                        buffer2[i] = item;
                    }

                    const slice1: []Self = buffer1[0..end];
                    const slice2: []Self = buffer2[0..end];
                    const result1 = filterNo(x, slice1);
                    const result2 = defaultFilterNo(x, slice2);

                    if (result1.len != result2.len) return error.MisimplementedFilterNo;
                    for (result1, result2) |item1, item2|
                        if (no(item1, item2))
                            return error.MisimplementedFilterNo;
                };
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

            test "Equivalent: no" {
                try testingNo(sample);
            }

            test "Equivalent: allEq" {
                try testingAllEq(sample);
            }

            test "Equivalent: anyEq" {
                try testingAnyEq(sample);
            }

            test "Equivalent: allNo" {
                try testingAllNo(sample);
            }

            test "Equivalent: anyNo" {
                try testingAnyNo(sample);
            }

            test "Equivalent: filteredEq" {
                try testingFilteredEq(sample);
            }

            test "Equivalent: filteredNo" {
                try testingFilteredNo(sample);
            }

            test "Equivalent: filterEq" {
                try testingFilterEq(sample);
            }

            test "Equivalent: filterNo" {
                try testingFilterNo(sample);
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

/// # PartialEquivalent
///
/// The `PartialEquivalent` interface relies on the existence of an partial equivalency function.
/// A function of type `fn (T, T) bool?` that's assumed to be:
///
/// - almost reflexive, `∀x : eq(x, x) === true`,
/// - almost symmetric, `∀x, y : eq(x, y) === eq(y, x)`,
/// - almost transitive, `∀x, y, z : (eq(x, y) and eq(y, z)) or (eq(x, z) === false)`.
///
/// The "almost" operator ("===") returns true if one of the two arguments is null.
///
/// ## Clauses
///
/// ### Methods
///
/// The `eq` method is defaulted to a partial equality function returned by `partialEqualsFn`.
/// It's most of the time the one you want, however if you truly want an equivalency and not an
/// equality, you probably will have to write it on your own.
///
/// All methods have a default implementation that'll most likely be the one you want. But in case
/// there are some invariants you want to take advantage of, you can override them.
///
/// ```zig
/// const Clauses = struct {
///     no: fn (Self, Self) bool,
///     allEq: fn (Self, []const Self) ?bool,
///     anyEq: fn (Self, []const Self) ?bool,
///     allNo: fn (Self, []const Self) ?bool,
///     anyNo: fn (Self, []const Self) ?bool,
/// };
/// ```
///
/// ### Others
///
/// The `Self` clause lets you specify another type than the contractor.
///
/// The `sample` clause lets you specify the sample slice on which tests will be performed.
///
/// The `max_sample_length` clause lets you define what length should the testing functions be
/// limited to.
///
/// ## Declarations
///
/// The returned namespace exposes the following declarations:
///
/// ```zig
/// const namespace = struct {
///     eq: fn (Self, Self) ?bool,
///     no: fn (Self, Self) ?bool,
///     allEq: fn (Self, []const Self) ?bool,
///     anyEq: fn (Self, []const Self) ?bool,
///     allNo: fn (Self, []const Self) ?bool,
///     anyNo: fn (Self, []const Self) ?bool,
///     testing_partial_equivalency: type,
/// };
/// ```
///
/// The `testing_partial_equivalency` namespace exposes the following declarations:
///
/// ```zig
/// const testing_partial_equivalency = struct {
///     testingEq: fn ([]const Self) anyerror!void,
///     testingNo: fn ([]const Self) anyerror!void,
///     testingAllEq: fn ([]const Self) anyerror!void,
///     testingAnyEq: fn ([]const Self) anyerror!void,
///     testingAllNo: fn ([]const Self) anyerror!void,
///     testingAnyNo: fn ([]const Self) anyerror!void,
/// };
/// ```
pub fn PartialEquivalent(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        /// This function is the partial equivalency function from the `PartialEquivalent`
        /// interface. It's assumed to be:
        /// - almost reflexive: `∀x : eq(x, x) === true`
        /// - almost symmetric: `∀x, y : eq(x, y) === eq(y, x)`
        /// - almost transitive: `∀x, y, z: (eq(x, y) and eq(y, z)) or (eq(x, z) === false)`
        pub const eq: fn (self: Self, other: Self) ?bool =
            contract.default(.eq, partialEqualsFn(Self));

        /// This function is the non-partial-equivalency function from the `PartialEquivalent`
        /// interface. It's assumed to be:
        /// - almost antireflexive: `∀x : no(x, x) === false`
        /// - almost symmetric: `∀x, y : no(x, y) === no(y, x)`
        /// - almost the opposite of `eq`: `∀x, y : eq(x, y) !== no(x, y)`
        pub const no: fn (self: Self, other: Self) ?bool =
            contract.default(.no, defaultNo);

        /// This function checks that all items of the `slice` parameter are equivalent to the
        /// `self` parameter, i.e. that `eq(self, item) == true`. Else if some items are only
        /// partial-equivalent, it returns `null`. Else it returns `false`.
        pub const allEq: fn (self: Self, slice: []const Self) ?bool =
            contract.default(.allEq, defaultAllEq);

        /// This function checks that there's at least one item of the `slice` parameter that's
        /// equivalent to the `self` parameter, i.e. that `eq(self, item) == true`. Else if there's
        /// an item partial-equivalent to `self`, it returns `null`. Else it returns `false`.
        pub const anyEq: fn (self: Self, slice: []const Self) ?bool =
            contract.default(.allEq, defaultAnyEq);

        /// This function checks that none of the items of the `slice` parameter is equivalent to
        /// the `self` parameter, i.e. that `eq(self, item) == false`. Else if some items are only
        /// partial-equivalent, it returns `null`. Else it returns `false`.
        pub const allNo: fn (self: Self, slice: []const Self) ?bool =
            contract.default(.allNo, defaultAllNo);

        /// This function checks that there's at least one item of the `slice` parameter that's not
        /// equivalent to the `self` parameter, i.e. that `eq(self, item) == false`. Else if
        /// there's an item partial-equivalent to `self`, it returns `null`. Else it returns
        /// `false`.
        pub const anyNo: fn (self: Self, slice: []const Self) bool =
            contract.default(.anyNo, defaultAnyNo);

        const Self: type = contract.default(.Self, Contractor);
        const sample: []const Self = contract.default(.sample, default_sample);

        fn defaultNo(self: Self, other: Self) ?bool {
            return if (eq(self, other)) |r| !r else null;
        }

        fn defaultAllEq(self: Self, slice: []const Self) ?bool {
            var has_null = false;
            for (slice) |item| {
                if (eq(self, item)) |r| {
                    if (!r) return false;
                } else has_null = true;
            }

            return if (has_null) null else true;
        }

        fn defaultAnyEq(self: Self, slice: []const Self) ?bool {
            var has_null = false;
            for (slice) |item| {
                if (eq(self, item)) |r| {
                    if (r) return true;
                } else has_null = true;
            }

            return if (has_null) null else false;
        }

        fn defaultAllNo(self: Self, slice: []const Self) ?bool {
            var has_null = false;
            for (slice) |item| {
                if (eq(self, item)) |r| {
                    if (r) return false;
                } else has_null = true;
            }

            return if (has_null) null else true;
        }

        fn defaultAnyNo(self: Self, slice: []const Self) ?bool {
            var has_null = false;
            for (slice) |item| {
                if (no(self, item)) |r| {
                    if (r) return true;
                } else has_null = true;
            }

            return if (has_null) null else false;
        }

        const default_sample: []const Self = &[_]Self{};
        const BoundsError = error{OutOfBounds};

        /// This namespace contains functions and tests for the validity of the `PartialEquivalent`
        /// interface. The tests are using the `sample` clause on the testing functions.
        pub const testing_partial_equivalency = struct {
            pub fn testingAlmostReflexivity(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x| {
                    const x_x = eq(x, x) orelse continue;
                    if (!x_x)
                        return error.NoAlmostReflexivity;
                }
            }

            pub fn testingAlmostSymmetry(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x| for (s) |y| {
                    const x_y = eq(x, y) orelse continue;
                    const y_x = eq(y, x) orelse continue;
                    if (x_y != y_x)
                        return error.NoAlmostSymmetry;
                };
            }

            pub fn testingAlmostTransitivity(s: []const Self) !void {
                if (contract.hasClause(.eq)) return;
                for (s) |x| for (s) |y| for (s) |z| {
                    const x_y = eq(x, y) orelse continue;
                    const y_z = eq(y, z) orelse continue;
                    const x_z = eq(x, z) orelse continue;
                    if (x_y and y_z and !x_z)
                        return error.NoAlmostTransitivity;
                };
            }

            pub fn testingNo(s: []const Self) !void {
                if (contract.hasClause(.no)) return;
                for (s) |x| for (s) |y|
                    if (maybeEq(no(x, y), eq(x, y)))
                        return error.MisimplementedNo;
            }

            pub fn testingAllEq(s: []const Self) !void {
                if (contract.hasClause(.allEq)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (!maybeEq(allEq(x, s[start..end]), defaultAllEq(x, s[start..end])))
                        return error.MisimplementedAllEq;
            }

            pub fn testingAnyEq(s: []const Self) !void {
                if (contract.hasClause(.anyEq)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (!maybeEq(anyEq(x, s[start..end]), defaultAnyEq(x, s[start..end])))
                        return error.MisimplementedAnyEq;
            }

            pub fn testingAllNo(s: []const Self) !void {
                if (contract.hasClause(.allNo)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (!maybeEq(allNo(x, s[start..end]), defaultAllNo(x, s[start..end])))
                        return error.MisimplementedAllNo;
            }

            pub fn testingAnyNo(s: []const Self) !void {
                if (contract.hasClause(.anyNo)) return;
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (!maybeEq(anyNo(x, s[start..end]), defaultAnyNo(x, s[start..end])))
                        return error.MisimplementedAnyNo;
            }

            fn maybeEq(a: ?bool, b: ?bool) bool {
                return if (a) |yes_a| {
                    if (b) |yes_b| yes_a == yes_b else return false;
                } else return false;
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

            test "PartialEquivalent: no" {
                try testingNo(sample);
            }

            test "PartialEquivalent: allEq" {
                try testingAllEq(sample);
            }

            test "PartialEquivalent: anyEq" {
                try testingAnyEq(sample);
            }

            test "PartialEquivalent: allNo" {
                try testingAllNo(sample);
            }

            test "PartialEquivalent: anyNo" {
                try testingAnyNo(sample);
            }
        };
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
                .Float, .ComptimeFloat => misc.compileError(
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
                } else misc.compileError("", .{}),
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
                    else => misc.compileError(
                        "Can't implement `{s}.anyPartialEquals` function for type `{s}` which" ++
                            " is a {s}-pointer to `{s}`!",
                        .{ @typeName(T), @tagName(Pointer.size), @typeName(Pointer.child) },
                    ),
                },
                // The following types, idk what to do, if there's anything to do.
                .AnyFrame, .Frame, .Fn, .Opaque, .NoReturn => misc.compileError(
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

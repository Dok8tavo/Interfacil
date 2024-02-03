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
                for (s) |x|
                    if (no(x, x))
                        return error.NoReflexivity;
            }

            pub fn testingSymmetry(s: []const Self) !void {
                for (s) |x| for (s) |y|
                    if (eq(x, y) != eq(y, x))
                        return error.NoSymmetry;
            }

            pub fn testingTransitivity(s: []const Self) !void {
                for (s) |x| for (s) |y| for (s) |z|
                    if (eq(x, y) and eq(y, z) and no(x, z))
                        return error.NoTransitivity;
            }

            pub fn testingNo(s: []const Self) !void {
                for (s) |x| for (s) |y|
                    if (no(x, y) == eq(x, y))
                        return error.MisimplementedNo;
            }

            pub fn testingAllEq(s: []const Self) !void {
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (allEq(x, s[start..end]) != defaultAllEq(x, s[start..end]))
                        return error.MisimplementedAllEq;
            }

            pub fn testingAnyEq(s: []const Self) !void {
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (anyEq(x, s[start..end]) != defaultAnyEq(x, s[start..end]))
                        return error.MisimplementedAnyEq;
            }

            pub fn testingAllNo(s: []const Self) !void {
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (allNo(x, s[start..end]) != defaultAllNo(x, s[start..end]))
                        return error.MisimplementedAllNo;
            }

            pub fn testingAnyNo(s: []const Self) !void {
                for (s) |x| for (0..s.len) |start| for (start..s.len) |end|
                    if (anyNo(x, s[start..end]) != defaultAnyNo(x, s[start..end]))
                        return error.MisimplementedAnyNo;
            }

            pub fn testingFilteredEq(s: []const Self) !void {
                var buffer1: [sample.len]Self = undefined;
                var buffer2: [sample.len]Self = undefined;
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
                var buffer1: [sample.len]Self = undefined;
                var buffer2: [sample.len]Self = undefined;
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
                var buffer1: [sample.len]Self = undefined;
                var buffer2: [sample.len]Self = undefined;
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
                var buffer1: [sample.len]Self = undefined;
                var buffer2: [sample.len]Self = undefined;
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

            test "Reflexivity" {
                try testingReflexivity(sample);
            }

            test "Symmetry" {
                try testingSymmetry(sample);
            }

            test "Transitivity" {
                try testingTransitivity(sample);
            }

            test "no" {
                try testingNo(sample);
            }

            test "allEq" {
                try testingAllEq(sample);
            }

            test "anyEq" {
                try testingAnyEq(sample);
            }

            test "allNo" {
                try testingAllNo(sample);
            }

            test "anyNo" {
                try testingAnyNo(sample);
            }

            test "filteredEq" {
                try testingFilteredEq(sample);
            }

            test "filteredNo" {
                try testingFilteredNo(sample);
            }

            test "filterEq" {
                try testingFilterEq(sample);
            }

            test "filterNo" {
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
                    // Pointers are semantically meant to not hold any relevant data, but point to
                    // it. So we're effectively not comparing pointers, but the data they're
                    // pointing to.
                    .One => anyPartiallyEquals(a.*, b.*),
                    // Any multi-item pointer is similar to a pointer to an array. We can emulate
                    // this when both pointers have the same length. Else we can just return null.
                    .Slice => {
                        var has_null = false;
                        return if (a.len != b.len) null else for (a, b) |c, d| {
                            if (anyPartiallyEquals(c, d)) |equality| {
                                if (!equality) break false;
                            } else has_null = true;
                        } else if (has_null) null else true;
                    },
                    // If they were terminated, other pointers could emulate slices, but I'm not
                    // sure how I should test for equality with the sentinel.
                    else => misc.compileError(
                        "Can't implement `{s}.anyPartiallyEquals` function for type `{s}` which" ++
                            " is a {s}-pointer to `{s}`!",
                        .{ @typeName(T), @tagName(Pointer.size), @typeName(Pointer.child) },
                    ),
                },
                // The following types, idk what to do, if there's anything to do.
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

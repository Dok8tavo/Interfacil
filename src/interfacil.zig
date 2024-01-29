//!zig-autodoc-guide: guides/conventions.md
//!zig-autodoc-guide: guides/glossary.md
//!zig-autodoc-section: tutorials
//!zig-autodoc-guide: guides/tutorials/interface-usage.md
//!zig-autodoc-guide: guides/tutorials/interface-writing.md

const std = @import("std");

pub const misc = @import("misc.zig");
pub const contracts = @import("contracts.zig");

const EnumLiteral = misc.EnumLiteral;

/// # Equivalent
/// This interface is useful when dealing with a function with two parameter of the same type that
/// happen to be an equivalency (i.e, reflexive, symmetric and transitive). It provides a few unit
/// tests, wraps the equivalency into a few ub checks, and provides a few additional functions.
///
/// By default this is the equivalency function is an equality function generated by `equalsFn`.
///
/// ## API
///
/// ```zig
/// allEq: fn (Self, []const Self) bool,
/// anyEq: fn (Self, []const Self) ?usize,
/// eq: fn (Self, Self) bool,
/// fielterEq: fn (Self, []const Self, []Self) ![]Self,
/// filterAllEq: fn ([]const Self, []const Self, []Self) ![]Self,
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
/// Self: type = Contractor,
/// eq: fn (Self, Self) bool = equalsFn(Self),
/// ub_checked: bool = true,
/// sample: []const Self = emptySlice(Self),
/// ```
pub fn Equivalent(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Self, clauses);

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
        pub fn anyEq(
            self: Self,
            slice: []const Self,
        ) ?usize {
            return for (slice, 0..) |item, i| {
                if (eq(self, item)) break i;
            } else null;
        }

        /// This function checks if the `self` parameter is equivalent to the `other` parameter.
        pub const eq: fn (self: Self, other: Self) bool =
            if (ub_checked) checkedEq else uncheckedEq;

        /// This function copy all the items of the `from` parameter that aren't equivalent to the
        /// `self` parameter into the `into` parameter.
        pub fn filterEq(
            self: Self,
            from: []const Self,
            into: []Self,
        ) error{OutOfMemory}![]Self {
            return try filterAllEq(&.{self}, from, into);
        }

        /// This function copy all the items of the `from` parameter that aren't equivalent to any
        /// item of the `filters` parameter into the `into` parameter.
        pub fn filterAllEq(
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
                    \\The `eq` function isn't reflexive:
                    \\   {any} !== {any}
                , .{
                    @typeName(Self),
                    item,
                    item,
                });
            }

            return self_other;
        }

        const Self = contract.default(.Self, Contractor);

        /// This namespace is a testing namespace for the `Equivalent` interface. It's intended to be
        /// used in tests, the functions inside have horrible complexity.
        pub const equivalency_tests = struct {
            /// This function fails when `∀x : x === x` is false in the given sample.
            ///
            /// It has a complexity of `O(n)`, with `n` being the length of  the sample, and
            /// assuming that the provided `eq` function is `O(1)`.
            pub fn reflexivity(sample: []const Self) ReflexivityError!void {
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
                for (sample) |x| for (sample) |y| for (sample) |z|
                    //    ∀x, y, z : ((x === y) & (y === z)) => (x === z)
                    // => ∀x, y, z : !((x === y) & (y === z)) | (x === z)
                    // => ∀x, y, z : (!(x === y) | !(y === z)) | (x === z)
                    // => ∀x, y, z : (x !== y) | (y !== z) | (x === z)
                    if (!testEq(x, y) or !testEq(y, z) or testEq(x, z))
                        return TransitivityError.EqualityIsNotTransitive;
            }

            pub const ReflexivityError = error{EqualityIsNotReflexive};
            pub const SymmetryError = error{EqualityIsNotSymmetric};
            pub const TransitivityError = error{EqualityIsNotTransitive};

            /// This equivalent function should be used for tests. It must be unchecked, otherwise
            /// there might be infinite recursive call on checking functions.
            const testEq: fn (Self, Self) bool = uncheckedEq;

            /// This slice is a sample used for generating tests. It can be useful when certain
            /// combinations of instances of `Contractor`
            const testing_sample: []const Self = contract.default(.sample, misc.emptySlice(Self));

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

/// This function generates an equality function. This equality is guaranteed to be:
/// - reflexive `∀x : equals(x, x)`
/// - symmetric `∀x, y : equals(x, y) == equals(y, x)`
/// - transitive `∀x, y, z : (equals(x, y) and equals(y, z)) => equals(x, z)`
/// It will be meaningful in most contexts, but if what you need is not an equality function, but a
/// way to check for special equivalent cases, you should implement it yourself.
pub fn equalsFn(comptime T: type) fn (T, T) bool {
    return struct {
        fn anyEquals(a: anytype, b: @TypeOf(a)) bool {
            const A = @TypeOf(a);
            const info = @typeInfo(A);
            return switch (info) {
                // The following types are considered numerical values.
                .Bool,
                .ComptimeFloat,
                .ComptimeInt,
                .Enum,
                .EnumLiteral,
                .ErrorSet,
                .Int,
                .Float,
                // Types are their id, which is a numerical value.
                .Type,
                => a == b,
                // The following are single-value types, therefore they allays equals themselves.
                .Void, .Null, .Undefined => true,
                // Error unions, optionals, and unions are all sum types. Two sum type instances
                // are equals when they have the same tag and payload.
                .ErrorUnion => if (a) |yes_a| {
                    return if (b) |yes_b| anyEquals(yes_a, yes_b) else |_| false;
                } else |no_a| {
                    return if (b) |_| false else |no_b| no_a == no_b;
                },
                .Optional => if (a) |some_a| {
                    return if (b) |some_b| anyEquals(some_a, some_b) else false;
                } else b == null,
                .Union => |Union| if (Union.tag_type) |Tag| {
                    const variant_a = @field(Tag, @tagName(a));
                    const variant_b = @field(Tag, @tagName(b));
                    if (variant_a != variant_b) return false;
                    const unwrapped_a = @field(a, @tagName(a));
                    const unwrapped_b = @field(b, @tagName(b));
                    return anyEquals(unwrapped_a, unwrapped_b);
                } else misc.compileError(
                    "Can't implement `{s}.anyEquals` function for the untagged union `{s}`!",
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
                    // Slices can be thought as a special case of both a pointer (we're comparing
                    // the data they're pointing to), and arrays (we're comparing all their
                    // members, except they don't allways have the same number of members). In both
                    // cases this seems like the right thing to do.
                    .Slice => if (a.len != b.len) false else for (a, b) |c, d| {
                        if (!anyEquals(c, d)) break false;
                    } else true,
                    // A many pointer can emulate a slice if they have a sentinel.
                    .Many => if (Pointer.sentinel) |sentinel_ptr| {
                        var index: usize = 0;
                        const sentinel = @as(*const Pointer.child, @ptrCast(sentinel_ptr)).*;
                        return while (true) : (index += 1) {
                            if (!anyEquals(a[index], b[index])) break false;
                            if (anyEquals(a[index], sentinel)) break true;
                        } else unreachable;
                    },
                    // C-pointers don't carry enough information by themselves to know if they're
                    // equals to one another.
                    .C => misc.compileError(
                        "Can't implement `{s}.anyEquals` function for type `{s}` which is a " ++
                            "c-pointer to `{s}!",
                        .{ @typeName(T), @typeName(A), @typeName(Pointer.child) },
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


const std = @import("std");
const utils = @import("utils.zig");
const contracts = @import("contracts.zig");
const iteration = @import("iteration.zig");

pub fn Equivalent(
    comptime Contractor: type,
    comptime Provider: type,
    comptime options: contracts.Options(Contractor),
) type {
    const contract = contracts.Contract(Contractor, Provider, options);
    const sample = contract.sample;
    const is_transitive = contract.default(.is_transitive, true);
    const is_reflexive = contract.default(.is_reflexive, true);
    const is_symmetric = contract.default(.is_symmetric, true);
    return struct {
        const Self: type = contract.Self;
        const Iterator = iteration.Iterator(Self);
        const ub_checked = contract.ub_checked;

        pub fn eq(self: Self, other: Self) bool {
            const function = contract.default(.eq, equalsFn(Self));
            return function(self, other);
        }

        pub fn allEq(self: Self, is_eq: bool, iterable: anytype) bool {
            const iterator = Iterator.fromIterable(iterable);
            return findEq(self, !is_eq, iterator) == null;
        }

        pub fn anyEq(self: Self, is_eq: bool, iterable: anytype) bool {
            const iterator = Iterator.fromIterable(iterable);
            return findEq(self, is_eq, iterator) != null;
        }

        pub fn findIndexEq(self: Self, is_eq: bool, iterable: anytype) ?usize {
            const iterator = Iterator.fromIterable(iterable);
            var index: usize = 0;
            return while (iterator.next()) |item| : (index += 1) {
                if (eq(self, item) == is_eq) break index;
            } else null;
        }

        pub fn findEq(self: Self, is_eq: bool, iterable: anytype) ?Self {
            const iterator = Iterator.fromIterable(iterable);
            return while (iterator.next()) |item| {
                if (eq(self, item) == is_eq) break item;
            } else null;
        }

        pub fn filterEq(
            self: Self,
            comptime is_eq: bool,
            iterable: anytype,
        ) FilterEqIterator(is_eq) {
            const iterator = Iterator.fromIterable(iterable);
            return FilterEqIterator(is_eq){
                .filter = self,
                .iterator = iterator,
            };
        }

        /// This function returns `error.NonReflexive` if the set of items isn't reflexive.
        pub fn testingReflexive(s: []const Self) !void {
            for (s) |x|
                if (!eq(x, x))
                    return error.NonReflexive;
        }

        /// This function returns `error.NonSymmetric` if the set of items isn't symmetric.
        pub fn testingSymmetry(s: []const Self) !void {
            for (s) |x| for (s) |y|
                if (eq(x, y) != eq(y, x))
                    return error.NonSymmetric;
        }

        /// This function returns `error.NonTransitive` if the set of items isn't transitive.
        pub fn testTransitive(s: []const Self) !void {
            for (s) |x| for (s) |y| for (s) |z|
                if (eq(x, y) and eq(y, z) and !eq(x, z))
                    return error.NonTransitive;
        }

        pub fn FilterEqIterator(comptime is_eq: bool) type {
            return struct {
                const Filtered = @This();

                filter: Self,
                iterator: Iterator,

                pub usingnamespace iteration.Iterable(Filtered, struct {
                    pub const Item = Self;
                    pub fn next(self: Filtered) ?Item {
                        return while (self.iterator.next()) |item| {
                            if (eq(self.filter, item) == is_eq) break item;
                        } else null;
                    }
                }, .{ .mutability = contracts.Mutability.by_val });
            };
        }

        const reflexivity = struct {
            test "Equivalent: Reflexivity" {
                try testingReflexive(sample);
            }
        };

        const symmetry = struct {
            test "Equivalent: Symmetry" {
                try testingSymmetry(sample);
            }
        };

        const transitivity = struct {
            test "Equivalent: Transitivity" {
                try testTransitive(sample);
            }
        };

        test eq {
            if (is_reflexive) _ = reflexivity;
            if (is_symmetric) _ = symmetry;
            if (is_transitive) _ = transitivity;
        }
    };
}

pub fn advancedEqualFn(comptime T: type, comptime type_equalFn_pairs: anytype) fn (T, T) bool {
    return struct {
        pub fn advancedEquals(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            inline for (type_equalFn_pairs) |type_equalFn_pair| {
                if (type_equalFn_pair[0] == Self) {
                    return type_equalFn_pair[1](self, other);
                }
            }

            switch (@typeInfo(Self)) {
                .Union, .Struct, .Enum, .Opaque => if (@hasDecl(Self, "eq")) {
                    if (@TypeOf(@field(Self, "eq") == fn (Self, Self) bool)) {
                        return @field(Self, "eq")(self, other);
                    }
                },
            }

            return equalsFn(Self);
        }

        pub fn equals(self: T, other: T) bool {
            return advancedEquals(self, other);
        }
    }.equals;
}

pub const EqualOptions = struct {
    unions: struct {
        use_interface: UseInterface = .allow,
        allowed: bool = true,
    } = .{},
    structs: struct {
        use_interface: UseInterface = .allow,
    } = .{},
    enums: struct {
        use_interface: UseInterface = .allow,
    } = .{},
    opaques: struct {
        allowed: bool = true,
    } = .{},
    floats: struct {
        precision: union(enum) {
            absolute: ?comptime_float,
            relative: ?comptime_float,
        } = .{ .absolute = null },
        nan_is_nan: bool = false,
        allowed: bool = false,
    } = .{},
    optionals: struct {
        null_is_null: bool = true,
        allowed: bool = false,
    } = .{},
    error_unions: struct {
        allowed: bool = false,
    } = .{},
    errors: Errors = .are_values,
    pointers_to_many: struct {
        length_does_matter: bool = true,
        allowed: bool = false,
    } = .{},

    pub const Errors = enum {
        imply_true,
        imply_false,
        are_values,
    };

    pub const UseInterface = enum {
        allow,
        force,
        never,
    };

    pub fn withFloats(
        self: EqualOptions,
        precision: ?comptime_float,
        kind: enum { rel, abs },
        nan_is_nan: bool,
    ) EqualOptions {
        var result = self;
        result.floats = .{
            .nan_is_nan = nan_is_nan,
            .allowed = true,
            .precision = switch (kind) {
                .abs => .{ .absolute = precision },
                .rel => .{ .relative = precision },
            },
        };
    }

    pub fn withoutFloats(self: EqualOptions) EqualOptions {
        var result = self;
        result.floats.allowed = false;
        return result;
    }

    pub fn withUnions(self: EqualOptions, use_interface: UseInterface) EqualOptions {
        var result = self;
        result.unions = .{
            .allowed = true,
            .use_interface = use_interface,
        };

        return result;
    }

    pub fn withoutUnions(self: EqualOptions) EqualOptions {
        var result = self;
        result.unions.allowed = false;
        return result;
    }

    pub fn withInterfaces(self: EqualOptions, use_interface: UseInterface) EqualOptions {
        var result = self;
        result.unions.use_interface = use_interface;
        result.structs.use_interface = use_interface;
        result.enums.use_interface = use_interface;
        result.opaques.allowed = use_interface != .never;
        return result;
    }

    pub fn withErrors(self: EqualOptions, errors: Errors) EqualOptions {
        var result = self;
        result.errors = errors;
        return result;
    }

    pub fn withOpaques(self: EqualOptions) EqualOptions {
        var result = self;
        result.opaques.allowed = true;
        return result;
    }

    pub fn withoutOpaques(self: EqualOptions) EqualOptions {
        var result = self;
        result.opaques.allowed = false;
        return result;
    }

    pub fn withUnionsInterface(self: EqualOptions, use_interface: UseInterface) EqualOptions {
        var result = self;
        result.unions.allowed = true;
        result.unions.use_interface = use_interface;
        return result;
    }

    pub fn withStructInterface(self: EqualOptions, use_interface: UseInterface) EqualOptions {
        var result = self;
        result.structs.use_interface = use_interface;
        return result;
    }

    pub fn withEnumInterface(self: EqualOptions, use_interface: UseInterface) EqualOptions {
        var result = self;
        result.enums.use_interface = use_interface;
        return result;
    }

    pub fn withPointersToMany(self: EqualOptions, does_length_matter: bool) EqualOptions {
        var result = self;
        result.pointers_to_many = .{
            .allowed = true,
            .length_does_matter = does_length_matter,
        };

        return result;
    }

    pub fn withoutPointersToMany(self: EqualOptions) EqualOptions {
        var result = self;
        result.pointers_to_many.allowed = false;
        return result;
    }

    pub fn withErrorUnions(self: EqualOptions) EqualOptions {
        var result = self;
        result.error_unions.allowed = true;
        return result;
    }

    pub fn withoutErrorUnions(self: EqualOptions) EqualOptions {
        var result = self;
        result.error_unions.allowed = false;
        return result;
    }

    pub fn withOptionals(self: EqualOptions, null_is_null: bool) EqualOptions {
        var result = self;
        result.optionals = .{
            .allowed = true,
            .null_is_null = null_is_null,
        };

        return result;
    }

    pub fn withoutOptionals(self: EqualOptions) EqualOptions {
        var result = self;
        result.optionals.allowed = false;
        return result;
    }
};

pub fn equalsFnWithOptions(comptime T: type, comptime options: EqualOptions) fn (T, T) bool {
    return struct {
        fn cantImplement(comptime Self: type) noreturn {
            utils.compileError(
                "Can't implement `equalsFnWithOptions`, because `{s}` contains `{s}`!",
                .{ @typeName(T), @typeName(Self) },
            );
        }

        fn equalsByInterface(
            comptime Self: type,
            comptime use_interface: EqualOptions.UseInterface,
            self: Self,
            other: Self,
        ) ?bool {
            const interface: ?fn (Self, Self) bool = if (@hasDecl(Self, "eq") and
                @TypeOf(Self.eq) == fn (Self, Self) bool)
                Self.eq
            else
                null;
            return switch (use_interface) {
                .never => null,
                .allow => if (interface) |eq| eq(self, other) else null,
                .force => if (interface) |eq| eq(self, other) else utils.compileError(
                    "Can't implement `equalsWithOptions` for `{s}` because `{s}` doesn't have " ++
                        "a `eq: fn ({s}, {s})` public declaration!",
                    .{ @typeName(T), @typeName(Self), @typeName(Self), @typeName(Self) },
                ),
            };
        }

        fn equalsValue(self: anytype, other: @TypeOf(self)) bool {
            return self == other;
        }

        fn equalsFloat(self: anytype, other: @TypeOf(self)) bool {
            if (!options.float.is_allowed) cantImplement(@TypeOf(self));
            const self_is_nan = std.math.isNan(self);
            const other_is_nan = std.math.isNan(other);

            if (self_is_nan != other_is_nan)
                return false;
            if (self_is_nan and other_is_nan)
                return options.float.nan_is_nan;

            const diff = @max(self, other) - @min(self, other);
            // basically self (infty) == other (infty)
            if (std.math.isNan(diff)) return true;

            return diff <= switch (options.float.precision) {
                .absolute => |absolute| @abs(absolute) orelse 0,
                .relative => |relative| if (std.math.isFinite(self)) div: {
                    const eta = relative orelse 0;
                    break :div eta * @abs(self);
                } else false,
            };
        }

        fn equalsEnum(self: anytype, other: @TypeOf(self)) bool {
            return equalsByInterface(
                @TypeOf(self),
                options.@"enum".use_interface,
                self,
                other,
            ) orelse equalsValue(self, other);
        }

        fn equalsError(self: anytype, other: @TypeOf(self)) bool {
            return switch (options.@"error") {
                .is_error => true,
                .implies_false => false,
                .is_value => equalsValue(self, other),
            };
        }

        fn equalsByItem(self: anytype, other: @TypeOf(self)) bool {
            return for (self, other) |self_item, other_item| {
                if (!equalsWithOptions(self_item, other_item)) break false;
            } else true;
        }

        fn equalsOptional(self: anytype, other: @TypeOf(self)) bool {
            if (!options.optional.is_allowed) cantImplement(@TypeOf(self));

            const self_is_null = self == null;
            const other_is_null = other == null;

            if (self_is_null != other_is_null) return false;
            if (self_is_null) return options.optional.null_is_null;

            return equalsWithOptions(self, other);
        }

        fn equalsErrorUnion(self: anytype, other: @TypeOf(self)) bool {
            if (!options.error_union.is_allowed) cantImplement(@TypeOf(self));

            const self_is_err = if (self) |_| false else true;
            const other_is_err = if (other) |_| false else true;

            if (self_is_err != other_is_err) return false;
            if (self_is_err) {
                const self_err: anyerror = if (self) |_| unreachable else |err| err;
                const other_err: anyerror = if (other) |_| unreachable else |err| err;
                return equalsError(self_err, other_err);
            } else return equalsWithOptions(
                self catch unreachable,
                other catch unreachable,
            );
        }

        fn equalsUnion(self: anytype, other: @TypeOf(self)) bool {
            if (!options.@"union".is_allowed) cantImplement(@TypeOf(self));
            switch (self) {
                inline else => |comptime_tag| {
                    if (other != comptime_tag) return false;
                    const self_payload = @field(self, comptime_tag);
                    const other_payload = @field(other, comptime_tag);
                    return equalsWithOptions(self_payload, other_payload);
                },
            }
        }

        fn equalsStruct(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const fields = @typeInfo(Self).Struct.fields;
            if (equalsByInterface(Self, options.structs.use_interface, self, other)) |res|
                return res;

            // Structs are product types, two instances of them are equal when all their members
            // are equal two by two.
            return inline for (fields) |field| {
                const self_field = @field(self, field.name);
                const other_field = @field(other, field.name);
                if (!equalsWithOptions(self_field, other_field)) break false;
            } else true;
        }

        fn equalsPointer(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const info = @typeInfo(Self).Pointer;
            if (info.size == .One) equalsWithOptions(self.*, other.*);
            if (!options.pointer_to_many.is_allowed) cantImplement(Self);
            const sentinel: *const info.child = utils.cast(
                info.sentinel orelse cantImplement(Self),
            );

            var index: usize = 0;
            return while (true) : (index += 1) {
                if (equalsWithOptions(self[index], sentinel.*))
                    break !options.pointer_to_many.length_does_matter or
                        equalsWithOptions(other[index], sentinel.*);
                if (!equalsWithOptions(self[index], other[index])) break false;
            };
        }

        fn equalsOpaque(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            return if (options.@"opaque".is_allowed)
                equalsByInterface(Self, .force, self, other)
            else
                cantImplement(Self);
        }

        fn equalsWithOptions(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            return switch (@typeInfo(Self)) {
                // The following types are considered numerical values.
                .Bool,
                .EnumLiteral,
                .Int,
                .ComptimeInt,
                // Types are their id, which is a numerical value.
                .Type,
                => equalsValue(self, other),
                // Void is a single-value type.
                .Void,
                => true,
                .ErrorSet,
                => equalsError(self, other),
                .Enum => equalsEnum(self, other),
                .ComptimeFloat, .Float => equalsFloat(self, other),
                .Optional => equalsOptional(self, other),
                .ErrorUnion => equalsError(self, other),
                .Union => equalsUnion(self, other),
                .Struct => equalsStruct(self, other),
                .Array, .Vector => equalsByItem(self, other),
                .Pointer => equalsPointer(self, other),
                .Opaque => equalsOpaque(self, other),
                .AnyFrame, .Frame, .Fn, .NoReturn, .Null, .Undefined => cantImplement(Self),
            };
        }

        pub fn equals(self: T, other: T) bool {
            return equalsWithOptions(self, other);
        }
    }.equals;
}

pub fn equalsFn(comptime T: type) fn (T, T) bool {
    return equalsFnWithOptions(T, .{});
}

test "Color" {
    const ColorRGB = struct {
        r: u8,
        g: u8,
        b: u8,

        pub fn from(r: u8, g: u8, b: u8) @This() {
            return .{ .r = r, .g = g, .b = b };
        }

        pub const black = from(0, 0, 0);
        pub const red = from(255, 0, 0);
        pub const green = from(0, 255, 0);
        pub const yellow = from(255, 255, 0);
        pub const blue = from(0, 0, 255);
        pub const magenta = from(255, 0, 255);
        pub const cyan = from(0, 255, 255);
        pub const white = from(255, 255, 255);

        pub const colors = [_]@This(){ black, red, green, yellow, blue, magenta, cyan, white };
        pub usingnamespace Equivalent(@This(), struct {}, .{});
    };

    for (ColorRGB.colors) |color| {
        try std.testing.expect(color.eq(color));
        var count: u8 = 0;
        for (ColorRGB.colors) |other| {
            if (color.eq(other)) count += 1;
        }

        try std.testing.expect(count == 1);
    }
}

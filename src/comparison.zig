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
            const function = contract.default(.eq, equalsWithOptionsFn(Self));
            const self_eq_other = function(self, other);
            const other_eq_self = function(other, self);
            const self_eq_self = function(self, self);
            const other_eq_other = function(other, other);
            utils.checkUB(
                ub_checked and is_symmetric and self_eq_other == other_eq_self,
                "UB: {s} isn't symmetric: `({any} == {any}) != ({any} == {any})`",
                .{ contract.name, self, other, other, self },
            );
            utils.checkUB(
                ub_checked and is_reflexive and self_eq_self,
                "UB: {s} isn't reflexive: `{any} != {any}`",
                .{ contract.name, self, self },
            );
            utils.checkUB(
                ub_checked and is_reflexive and other_eq_other,
                "UB: {s} isn't reflexive: `{any} != {any}`",
                .{ contract.name, other, other },
            );
            return self_eq_other;
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

        pub fn isReflexive(s: []const Self) bool {
            return for (s) |x| {
                if (!eq(x, x))
                    break false;
            } else false;
        }

        pub fn isSymmetric(s: []const Self) bool {
            return for (s) |x| {
                for (s) |y|
                    if (eq(x, y) != eq(y, x))
                        break false;
            } else true;
        }

        pub fn isTransitive(s: []const Self) bool {
            return for (s) |x| {
                for (s) |y| for (s) |z|
                    if (eq(x, y) and eq(y, z) and !eq(x, z))
                        break false;
            } else true;
        }

        const reflexivity = struct {
            test isReflexive {
                try std.testing.expect(isReflexive(sample));
            }
        };

        const symmetry = struct {
            test isSymmetric {
                try std.testing.expect(isSymmetric(sample));
            }
        };

        const transitivity = struct {
            test isTransitive {
                try std.testing.expect(isTransitive(sample));
            }
        };

        test eq {
            if (is_reflexive) _ = reflexivity;
            if (is_symmetric) _ = symmetry;
            if (is_transitive) _ = transitivity;
        }
    };
}

pub const EqualOptions = struct {
    /// WARNING: this can result into infinite recursion if interface use `equalsWithOptionsFn`.
    structs: UseInterface = .never,
    /// WARNING: this can result into infinite recursion if interface use `equalsWithOptionsFn`.
    unions: UseInterface = .never,
    /// WARNING: this can result into infinite recursion if interface use `equalsWithOptionsFn`.
    enums: UseInterface = .never,
    /// Opaque types can only use the interface function
    /// WARNING: this can result into infinite recursion if interface use `equalsWithOptionsFn`.
    allow_opaques: bool = false,
    floats_precision: Precision = .relative,
    floats_tolerance: ?comptime_float = null,
    nan_is_nan: bool = true,
    null_is_null: bool = true,
    any_error_is_any_error: bool = false,

    pub const Precision = enum { absolute, relative };

    pub const UseInterface = enum {
        allow,
        force,
        never,
    };

    pub const default = EqualOptions{};

    pub fn withNullIsNull(self: EqualOptions, null_is_null: bool) EqualOptions {
        var result = self;
        result.null_is_null = null_is_null;
        return result;
    }

    pub fn withAnyErrorIsAnyError(self: EqualOptions, any_error_is_any_error: bool) EqualOptions {
        var result = self;
        result.any_error_is_any_error = any_error_is_any_error;
        return result;
    }

    pub fn withNanIsNan(self: EqualOptions, nan_is_nan: bool) EqualOptions {
        var result = self;
        result.nan_is_nan = nan_is_nan;
        return result;
    }

    pub fn withFloatsTolerance(
        self: EqualOptions,
        floats_tolerance: ?comptime_float,
    ) EqualOptions {
        var result = self;
        result.floats_tolerance = floats_tolerance;
        return result;
    }

    pub fn withFloatsPrecision(self: EqualOptions, floats_precision: Precision) EqualOptions {
        var result = self;
        result.floats_precision = floats_precision;
        return result;
    }

    pub fn withAllowOpaques(self: EqualOptions, allow_opaques: bool) EqualOptions {
        var result = self;
        result.allow_opaques = allow_opaques;
        return result;
    }

    pub fn withUnions(self: EqualOptions, unions: UseInterface) EqualOptions {
        var result = self;
        result.unions = unions;
        return result;
    }

    pub fn withStructs(self: EqualOptions, structs: UseInterface) EqualOptions {
        var result = self;
        result.structs = structs;
        return result;
    }

    pub fn withEnums(self: EqualOptions, enums: UseInterface) EqualOptions {
        var result = self;
        result.enums = enums;
        return result;
    }

    pub fn withInterfaces(self: EqualOptions, interfaces: UseInterface) EqualOptions {
        return self
            .withAllowOpaques(interfaces != .never)
            .withStructs(interfaces)
            .withUnions(interfaces)
            .withEnums(interfaces);
    }

    pub fn withTransitivity(self: EqualOptions) EqualOptions {
        return self
            .withInterfaces(.never)
            .withFloatsTolerance(0)
            .assertTransitive();
    }

    pub fn withReflexivity(self: EqualOptions) EqualOptions {
        return self
            .withInterfaces(.never)
            .withNanIsNan(true)
            .withNullIsNull(true)
            .assertReflexive();
    }

    pub fn withSymmetry(self: EqualOptions) EqualOptions {
        return self
            .withInterfaces(.never)
            .assertSymmetric();
    }

    pub fn canUseInterface(self: EqualOptions) bool {
        return self.structs != .never or
            self.unions != .never or
            self.enums != .never or
            self.allow_opaques;
    }

    pub fn mustUseInterface(self: EqualOptions) bool {
        return self.structs == .force or
            self.unions == .force or
            self.enums == .force or
            self.allow_opaques;
    }

    pub fn isTransitive(self: EqualOptions) bool {
        return !self.canUseInterface() and switch (self.float_precision) {
            .absolute => if (self.float_tolerance) |t| t == 0 else true,
            .relative => if (self.float_tolerance) |t| t == 0 else false,
        };
    }

    pub fn isSymmetric(self: EqualOptions) bool {
        return !self.canUseInterface();
    }

    pub fn isReflexive(self: EqualOptions) bool {
        return !self.canUseInterface() and
            self.nan_is_nan and
            self.null_is_null;
    }

    pub fn assertTransitive(self: EqualOptions) EqualOptions {
        std.debug.assert(self.isTransitive());
        return self;
    }

    pub fn assertSymmetric(self: EqualOptions) EqualOptions {
        std.debug.assert(self.isSymmetric());
        return self;
    }

    pub fn assertReflexive(self: EqualOptions) EqualOptions {
        std.debug.assert(self.isReflexive());
        return self;
    }
};

pub fn equalsWithOptionsFn(comptime T: type, comptime options: EqualOptions) fn (T, T) bool {
    return struct {
        fn EqFn(comptime Self: type) type {
            return fn (Self, Self) bool;
        }

        inline fn cantImplement(comptime Self: type) noreturn {
            utils.compileError(
                "Can't implement `{s}` because it contains the type `{s}`!",
                .{ @typeName(T), @typeName(Self) },
            );
        }

        inline fn getInterfaceFunction(
            comptime Self: type,
            comptime use: EqualOptions.UseInterface,
        ) ?EqFn(Self) {
            const interface = contracts.Contract(
                Self,
                Self,
                .{ .interface_name = "Equality" },
            );

            return switch (use) {
                .never => null,
                .allow => interface.default(.eq, @as(?EqFn(Self), null)),
                .force => interface.require(.eq, EqFn(Self)),
            };
        }

        fn equalsStruct(self: anytype, other: @TypeOf(self)) bool {
            const Self: type = @TypeOf(self);
            const interface_function = getInterfaceFunction(Self, options.structs);
            return if (interface_function) |function|
                function(self, other)
            else inline for (@typeInfo(Self).Struct.fields) |field| {
                const self_field = @field(self, field.name);
                const other_field = @field(other, field.name);
                if (!equalsAny(self_field, other_field)) break false;
            } else true;
        }

        fn equalsError(self: anytype, other: @TypeOf(self)) bool {
            return if (options.any_error_is_any_error) true else self == other;
        }

        fn equalsFloat(self: anytype, other: @TypeOf(self)) bool {
            const Self: type = @TypeOf(self);
            const epsilon: Self = std.math.floatEps(Self);
            const tolerance: Self = options.floats_tolerance orelse epsilon;
            std.debug.assert(0 <= tolerance);

            const self_is_nan = std.math.isNan(self);
            const other_is_nan = std.math.isNan(other);

            if (self_is_nan != other_is_nan)
                return false;

            if (self_is_nan)
                return options.nan_is_nan;

            if (self == other) return true;

            const delta = @abs(self - other);
            return delta <= switch (options.floats_precision) {
                .absolute => tolerance,
                .relative => tolerance * @max(@abs(self), @abs(other)),
            };
        }

        fn equalsMultiPointer(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const info = @typeInfo(Self).Pointer;
            return switch (info.size) {
                .One => unreachable,
                .Slice => self.len == other.len and for (self, other) |self_item, other_item| {
                    if (!equalsAny(self_item, other_item)) break false;
                } else true,
                .Many => if (info.sentinel) |info_sentinel| {
                    var index: usize = 0;
                    const sentinel: *const info.child = @ptrCast(@alignCast(info_sentinel));
                    return while (true) : (index += 1) {
                        const self_item = self[index];
                        const other_item = other[index];
                        if (self_item != other_item) break false;
                        if (self_item == sentinel.*) break other_item == sentinel.*;
                    };
                } else cantImplement(Self),
                .C => {
                    const C2Z = @Type(.{ .Pointer = comptime c2z: {
                        var c2z = info;
                        const zero = std.mem.zeroes(info.child);
                        c2z.size = .Many;
                        c2z.sentinel = &zero;
                        break :c2z c2z;
                    } });
                    return equalsMultiPointer(@as(C2Z, @ptrCast(self)), @ptrCast(other));
                },
            };
        }

        fn equalsUnion(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const interface_function = getInterfaceFunction(Self, options.unions);
            if (interface_function) |function|
                return function(self, other);

            const info = @typeInfo(Self).Union;
            const Tag = info.tag_type orelse cantImplement(Self);

            const self_int = @intFromEnum(self);
            const other_int = @intFromEnum(other);
            const self_tag: Tag = @enumFromInt(self_int);
            const other_tag: Tag = @enumFromInt(other_int);
            if (self_tag != other_tag) return false;

            switch (self_tag) {
                inline else => |comptime_tag| {
                    const self_payload = @field(self, @tagName(comptime_tag));
                    const other_payload = @field(other, @tagName(comptime_tag));
                    return equalsAny(self_payload, other_payload);
                },
            }
        }

        fn equalsErrorUnion(self: anytype, other: @TypeOf(self)) bool {
            const self_failed = if (self) |_| false else |_| true;
            const other_failed = if (other) |_| false else |_| true;
            if (self_failed != other_failed) return false;
            if (self_failed) {
                const self_fail = if (self) |_| unreachable else |fail| fail;
                const other_fail = if (other) |_| unreachable else |fail| fail;
                return equalsError(self_fail, other_fail);
            }

            const self_pass = self catch unreachable;
            const other_pass = other catch unreachable;
            return equalsAny(self_pass, other_pass);
        }

        fn equalsOptional(self: anytype, other: @TypeOf(self)) bool {
            const self_is_null = self == null;
            const other_is_null = other == null;
            if (self_is_null != other_is_null) return false;
            if (self_is_null) return options.null_is_null;
            return equalsAny(self.?, other.?);
        }

        fn equalsEnum(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const interface_function = getInterfaceFunction(Self, options.enums);
            return if (interface_function) |function| function(self, other) else self == other;
        }

        fn equalsOpaque(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const use = if (options.allow_opaques) .force else .never;
            const function = getInterfaceFunction(Self, use) orelse cantImplement(Self);
            return function(self, other);
        }

        fn equalsAny(self: anytype, other: @TypeOf(self)) bool {
            const Self = @TypeOf(self);
            const info = @typeInfo(Self);
            return switch (info) {
                // values
                .Int, .ComptimeInt, .Bool, .Type => self == other,
                .Vector => @reduce(.And, self == other),
                .Void => true,
                .ErrorSet => equalsError(self, other),
                .Float, .ComptimeFloat => equalsFloat(self, other),
                // product types
                .Struct => equalsStruct(self, other),
                .Array => inline for (self, other) |self_item, other_item| {
                    if (!equalsAny(self_item, other_item)) break false;
                } else true,
                // pointers
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => equalsAny(self.*, other.*),
                    else => equalsMultiPointer(self, other),
                },
                // sum types
                .Union => equalsUnion(self, other),
                .ErrorUnion => equalsErrorUnion(self, other),
                .Optional => equalsOptional(self, other),
                .Enum => equalsEnum(self, other),
                // others
                .Opaque => equalsOpaque(self, other),
                else => cantImplement(Self),
            };
        }

        fn equals(self: T, other: T) bool {
            return equalsAny(self, other);
        }
    }.equals;
}

test equalsWithOptionsFn {
    const expect = std.testing.expect;

    // values
    const eqByte = equalsWithOptionsFn(u8, .{});
    try expect(eqByte(2, 2));
    try expect(!eqByte(2, 3));

    const Vector = @Vector(2, isize);
    const eqVec = equalsWithOptionsFn(Vector, .{});
    const vec1: Vector = @splat(-1);
    const vec2: Vector = [_]isize{ -1, 1 };
    const vec3 = vec1;

    try expect(!eqVec(vec1, vec2));
    try expect(!eqVec(vec2, vec3));
    try expect(eqVec(vec3, vec1));

    inline for ([_]type{ f16, f32, f64, f128, f80 }) |T| {
        const eps_value = comptime std.math.floatEps(T);
        const sqrt_eps_value = comptime std.math.sqrt(eps_value);
        const nan_value = comptime std.math.nan(T);
        const inf_value = comptime std.math.inf(T);
        const min_value = comptime std.math.floatMin(T);

        const eqAbsEps = equalsWithOptionsFn(T, .{ .floats_precision = .absolute });
        const eqRelSqt = equalsWithOptionsFn(T, .{
            .floats_tolerance = sqrt_eps_value,
        });
        const eqAbsTwo = equalsWithOptionsFn(T, .{
            .floats_precision = .absolute,
            .floats_tolerance = 2 * std.math.floatEps(T),
        });

        try expect(eqAbsEps(0.0, 0.0));
        try expect(eqAbsEps(-0.0, -0.0));
        try expect(eqAbsEps(0.0, -0.0));
        try expect(eqRelSqt(1.0, 1.0));
        try expect(!eqRelSqt(1.0, 0.0));
        try expect(!eqAbsEps(1.0 + 2 * eps_value, 1.0));
        try expect(eqAbsEps(1.0 + 1 * eps_value, 1.0));
        try expect(!eqRelSqt(1.0, nan_value));

        // todo: IEEE 754 or transitivity?
        try expect(eqRelSqt(nan_value, nan_value));
        try expect(eqRelSqt(inf_value, inf_value));
        try expect(eqRelSqt(min_value, min_value));
        try expect(eqRelSqt(-min_value, -min_value));

        try expect(eqAbsTwo(min_value, 0.0));
        try expect(eqAbsTwo(-min_value, 0.0));
    }

    // arrays
    const eqArr = equalsWithOptionsFn([4]bool, .{});

    const array1 = [4]bool{ true, false, true, false };
    const array2 = [4]bool{ true, true, true, false };
    const array3 = [4]bool{ true, false, true, false };

    try expect(!eqArr(array1, array2));
    try expect(!eqArr(array2, array3));
    try expect(eqArr(array3, array1));

    // structs
    const Struct = struct {
        field_a: bool,
        field_b: u32,

        pub fn eq(self: @This(), other: @This()) bool {
            return self.field_a == other.field_a;
        }
    };

    const struct1 = Struct{ .field_a = true, .field_b = 5 };
    const struct2 = Struct{ .field_a = true, .field_b = 7 };
    const struct3 = Struct{ .field_a = true, .field_b = 5 };

    const eqStructWoutIface = equalsWithOptionsFn(Struct, .{});
    const eqStructWithIface = equalsWithOptionsFn(Struct, .{ .structs = .allow });

    try expect(!eqStructWoutIface(struct1, struct2));
    try expect(!eqStructWoutIface(struct2, struct3));
    try expect(eqStructWoutIface(struct3, struct1));

    try expect(eqStructWithIface(struct1, struct2));
    try expect(eqStructWithIface(struct2, struct3));
    try expect(eqStructWithIface(struct3, struct1));

    // pointers
    const ptr1 = &struct1;
    const ptr2 = &struct2;
    const ptr3 = &struct3;

    const eqPtr = equalsWithOptionsFn(*const Struct, .{});

    try expect(!eqPtr(ptr1, ptr2));
    try expect(!eqPtr(ptr2, ptr3));
    try expect(eqPtr(ptr3, ptr1));

    const slice1 = utils.slice(bool, comptime array1);
    const slice2 = utils.slice(bool, comptime array2);
    const slice3 = utils.slice(bool, comptime array3);

    const eqSlice = equalsWithOptionsFn([]const bool, .{});

    try expect(!eqSlice(slice1, slice2));
    try expect(!eqSlice(slice2, slice3));
    try expect(eqSlice(slice3, slice1));

    // c_strings
    const str1: [*c]const u8 = "Hello world!";
    const str2: [*c]const u8 = "How are you?";
    const str3: [*c]const u8 = "Hello world!";

    const eqStr = equalsWithOptionsFn([*c]const u8, .{});

    try expect(!eqStr(str1, str2));
    try expect(!eqStr(str2, str3));
    try expect(eqStr(str3, str1));

    // unions
    const Union = union(enum) {
        unsigned: u32,
        signed: i32,

        pub fn eq(self: @This(), other: @This()) bool {
            return switch (self) {
                inline else => |self_payload| switch (other) {
                    inline else => |other_payload| self_payload == other_payload,
                },
            };
        }
    };

    const eqUnionWoutIface = equalsWithOptionsFn(Union, .{});
    const eqUnionWithIface = equalsWithOptionsFn(Union, .{ .unions = .allow });

    const union1 = Union{ .signed = 1 };
    const union2 = Union{ .unsigned = 1 };
    const union3 = Union{ .signed = 2 };
    const union4 = Union{ .signed = 1 };

    try expect(!eqUnionWoutIface(union1, union2));
    try expect(!eqUnionWoutIface(union1, union3));
    try expect(eqUnionWoutIface(union1, union4));
    try expect(!eqUnionWoutIface(union2, union3));
    try expect(!eqUnionWoutIface(union2, union4));
    try expect(!eqUnionWoutIface(union3, union4));

    try expect(eqUnionWithIface(union1, union2));
    try expect(!eqUnionWithIface(union1, union3));
    try expect(eqUnionWithIface(union1, union4));
    try expect(!eqUnionWithIface(union2, union3));
    try expect(eqUnionWithIface(union2, union4));
    try expect(!eqUnionWithIface(union3, union4));

    // error unions
    const Result = std.fmt.ParseIntError!u8;
    const eqResult = equalsWithOptionsFn(Result, .{});

    const eighteen = std.fmt.parseInt(u8, "18", 10);
    const eighteen_again = std.fmt.parseInt(u8, "18", 10);
    const eighty_one = std.fmt.parseInt(u8, "81", 10);
    const overflow = std.fmt.parseInt(u8, "256", 10);
    const underflow = std.fmt.parseInt(u8, "-1", 10);
    const invalid_character = std.fmt.parseInt(u8, "lol", 10);
    const invalid_cifer = std.fmt.parseInt(u8, "so funny!", 10);

    try expect(eqResult(eighteen, eighteen_again));
    try expect(!eqResult(eighteen, eighty_one));
    try expect(!eqResult(eighteen, overflow));
    try expect(!eqResult(eighteen, underflow));
    try expect(!eqResult(eighteen, invalid_character));
    try expect(!eqResult(eighteen, invalid_cifer));

    try expect(eqResult(overflow, underflow));
    try expect(!eqResult(overflow, invalid_character));
    try expect(eqResult(invalid_character, invalid_cifer));

    // optionals
    const Optional = ?usize;
    const some: Optional = 0;
    const none: Optional = null;
    const some_other: Optional = 1;

    const eqOpt = equalsWithOptionsFn(Optional, .{});

    try expect(!eqOpt(some, none));
    try expect(!eqOpt(none, some_other));
    try expect(!eqOpt(some_other, some));
    try expect(eqOpt(some, some));
    try expect(eqOpt(none, none));
}

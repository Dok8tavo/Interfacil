const std = @import("std");
const utils = @import("utils.zig");
const contracts = @import("contracts.zig");

pub fn FieldManaged(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);

    const Self: type = contract.Self();
    const info = @typeInfo(Self);
    if (info != .Struct) utils.compileError(
        "The `{s}.FieldManaged` interface must be applied to a struct, not a `.{s}` like `{s}`!",
        .{ @typeName(Contractor), @tagName(info), @typeName(Self) },
    );

    if (info.Struct.is_tuple) utils.compileError(
        "The `{s}.FieldManaged` interface can't be applied to a tuple like `{s}`!",
        .{ @typeName(Contractor), @typeName(Self) },
    );

    return struct {
        pub const FieldLiteral: type = std.meta.FieldEnum(Self);
        pub fn Field(comptime field: FieldLiteral) type {
            return std.meta.fieldInfo(Self, field).type;
        }

        fn defaultGetField(self: Self, comptime field: FieldLiteral) Field(field) {
            return @field(self, @tagName(field));
        }

        fn defaultSetField(self: *Self, comptime field: FieldLiteral, value: Field(field)) Field(field) {
            defer @field(self, @tagName(field)) = value;
            return @field(self, @tagName(field));
        }

        pub const setField = contract.default(.setField, defaultSetField);
        pub const getField = contract.default(.getField, defaultGetField);
        pub fn getFieldFn(comptime field: FieldLiteral) fn (Self) Field(field) {
            return struct {
                pub fn call(self: Self) Field(field) {
                    return getField(self, field);
                }
            }.call;
        }

        pub fn setFieldFn(comptime field: FieldLiteral) fn (*Self, Field(field)) Field(field) {
            return struct {
                pub fn call(self: Self, value: Field(field)) Field(field) {
                    return setField(self, field, value);
                }
            }.call;
        }
    };
}

pub fn VariantManaged(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.Self;
    const info = @typeInfo(Self);

    if (info != .Union and info != .Enum) utils.compileError(
        "The `{s}.VariantManaged` interface must be applied to a union or an enum, not a `.{s}` like `{s}`!",
        .{ @typeName(Contractor), @tagName(info), @typeName(Self) },
    );

    if (info == .Union and info.Union.tag_type == null) utils.compileError(
        "The `{s}.VariantManaged` interface can't be applied to an untagged union like `{s}`!",
        .{ @typeName(Contractor), @typeName(Self) },
    );

    return struct {
        pub const VariantLiteral: type = std.meta.FieldEnum(Self);
        pub fn Variant(comptime variant: VariantLiteral) type {
            return std.meta.fieldInfo(Self, variant).type;
        }

        fn defaultGetVariant(self: Self, comptime variant: VariantLiteral) ?Variant(variant) {
            return if (self == variant)
                @field(self, @tagName(variant))
            else
                null;
        }

        fn defaultSetVariant(self: *Self, comptime variant: VariantLiteral, value: Variant(variant)) ?Variant(variant) {
            if (self != variant) return null;
            const old = @field(self, @tagName(variant));
            setToVariant(self, variant, value);
            return old;
        }

        fn defaultSetToVariant(self: *Self, comptime variant: VariantLiteral, value: Variant(variant)) void {
            self.* = @unionInit(Self, @tagName(variant), value);
        }

        pub const setVariant = contract.default(.setVariant, defaultSetVariant);
        pub const getVariant = contract.default(.getVariant, defaultGetVariant);
        pub const setToVariant = contract.default(.setToVariant, defaultSetToVariant);

        pub fn setVariantFn(comptime variant: VariantLiteral) fn (*Self, Variant(variant)) ?Variant(variant) {
            return struct {
                pub fn call(self: *Self, value: Variant(variant)) ?Variant(variant) {
                    return setVariant(self, variant, value);
                }
            }.call;
        }

        pub fn setToVariantFn(comptime variant: VariantLiteral) fn (*Self, Variant(variant)) void {
            return struct {
                pub fn call(self: *Self, value: Variant(variant)) void {
                    setToVariant(self, variant, value);
                }
            }.call;
        }

        pub fn getVariantFn(comptime variant: VariantLiteral) fn (Self) Variant(variant) {
            return struct {
                pub fn call(self: Self) Variant(variant) {
                    return getVariant(self, variant);
                }
            }.call;
        }
    };
}

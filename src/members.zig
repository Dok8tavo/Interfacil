const std = @import("std");
const misc = @import("misc.zig");
const contracts = @import("contracts.zig");

pub fn FieldManaged(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);

    const Self: type = contract.default(.Self, Contractor);
    const info = @typeInfo(Self);
    if (info != .Struct) misc.compileError(
        "The `{s}.FieldManaged` interface must be applied to a struct, not a `.{s}` like `{s}`!",
        .{ @typeName(Contractor), @tagName(info), @typeName(Self) },
    );

    if (info.Struct.is_tuple) misc.compileError(
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
    };
}

pub fn VariantManaged(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);

    const Self: type = contract.default(.Self, Contractor);
    const info = @typeInfo(Self);
    if (info != .Union and info != .Enum) misc.compileError(
        "The `{s}.VariantManaged` interface must be applied to a union or an enum, not a `.{s}` like `{s}`!",
        .{ @typeName(Contractor), @tagName(info), @typeName(Self) },
    );

    if (info == .Union and info.Union.tag_type == null) misc.compileError(
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
    };
}

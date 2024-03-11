const std = @import("std");
const utils = @import("utils.zig");
const EnumLiteral = utils.EnumLiteral;

pub fn Options(comptime Contractor: type) type {
    return struct {
        mutability: Mutability = .by_ref,
        ub_checked: bool = true,
        sample: []const Contractor = &[_]Contractor{},
        interface_name: ?[]const u8 = null,
    };
}

pub fn Contract(
    comptime Contractor: type,
    comptime Provider: type,
    comptime options: Options(Contractor),
) type {
    return struct {
        pub const sample = options.sample;
        pub const ub_checked = options.ub_checked;
        pub const mutability = options.mutability;
        pub const Self = Contractor;
        pub const VarSelf = switch (options.mutability) {
            .by_ref => *Self,
            .by_val => Self,
        };

        pub fn asSelf(self: VarSelf) Self {
            return switch (options.mutability) {
                .by_ref => self.*,
                .by_val => self,
            };
        }

        pub fn asVarSelf(self: *Self) VarSelf {
            return switch (options.mutability) {
                .by_ref => self,
                .by_val => self.*,
            };
        }

        pub const name = std.fmt.comptimePrint("{s}[{s}]", .{
            options.interface_name orelse "AnonymousInterface",
            @typeName(Contractor),
        });

        pub fn default(
            comptime literal: EnumLiteral,
            comptime declaration: anytype,
        ) @TypeOf(declaration) {
            const untyped = getUntyped(literal) orelse declaration;
            return coerced(untyped, @TypeOf(declaration));
        }

        pub fn require(
            comptime literal: EnumLiteral,
            comptime Declaration: type,
        ) Declaration {
            const untyped = getUntyped(literal) orelse utils.compileError(
                "The `{s}` interface requires a `{s}` declaration!",
                .{ name, @tagName(literal) },
            );
            return coerced(untyped, Declaration);
        }

        fn coerced(comptime to_coerce: anytype, comptime CoerceTo: type) CoerceTo {
            const ToCoerce: type = @TypeOf(to_coerce);
            return utils.todo(
                if (ToCoerce == CoerceTo) to_coerce else utils.compileError(
                    "The `{s}` interface requires that `{s}` coerces to `{s}`, but it's a `{s}`!",
                    .{ name, @tagName(to_coerce), @typeName(CoerceTo), @typeName(ToCoerce) },
                ),
                "Allow smart and intelligent coercion for the users plz, would be great",
                .{},
            );
        }

        fn getUntyped(comptime declaration: EnumLiteral) ?Type(declaration) {
            const declaration_name = @tagName(declaration);
            return if (@hasDecl(Provider, declaration_name))
                @field(Provider, declaration_name)
            else
                null;
        }

        fn Type(comptime declaration: EnumLiteral) type {
            const declaration_name = @tagName(declaration);
            return if (@hasDecl(Provider, declaration_name))
                @TypeOf(@field(Provider, declaration_name))
            else
                void;
        }
    };
}

/// This type is used to describe whether data from a given type can be mutated when an instance is
/// passed by value.
pub const Mutability = enum {
    /// This variant means that passing something by value can't modify what it holds. It should
    /// be used when the relevant data is contained, not referenced. It sets `VarSelf` to `*Self`.
    ///
    /// ## Example
    ///
    /// ```zig
    /// const Struct = struct {
    ///     data: [32]Data,
    /// };
    /// ```
    ///
    /// Assuming that `Data` mutability is `.by_ref`, then `Struct` is also `.by_ref`, because
    /// passing a `Struct` as argument can't change its data. In order to change its data, one must
    /// pass a `*Struct` instead.
    by_ref,
    /// This variant means that passing something by value could modify what it holds. It should be
    /// used when the relevant data is referenced, not contained. It sets `VarSelf` to `Self`.
    ///
    /// ## Example
    ///
    /// ```zig
    /// const Struct = struct {
    ///     data: []Data,
    /// };
    /// ```
    ///
    /// The `Struct` mutability is be `.by_val`, because passing a `Struct` as argument may change
    /// its data.
    by_val,
};

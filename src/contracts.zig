//! Contracts are a very important part of interfaces. They're taking the clauses from the
//! `clauses` parameter of the interface, type-check them, and give them back for the making
//! of the namespace.

const std = @import("std");
const utils = @import("utils.zig");
const EnumLiteral = utils.EnumLiteral;

// TODO: implement coercion tools for clauses
/// This function takes the clauses from the `clauses` parameter of the interface, type-checks
/// them, and gives them back in order to return the namespace. It's considered responsible for
/// providing thenecessary `clauses` and is often the type that receives the namespace, allowing
/// for the use of method syntax on the function of the interface.
pub fn Contract(
    /// This is the type considered responsible for providing the necessary `clauses`. It's always
    /// important for good error message at compile-time. But it's also very common for this type
    /// to be the one receiving the namespace, thus allowing to use method syntax on the function
    /// of the interface.
    comptime Contractor: type,
    /// The clauses are a struct literal, whose fields will fulfill the requirement of the
    /// contract. It's through them that the user will provide the values and declarations needed,
    /// or the options available, for returning the interface.
    comptime clauses: anytype,
) type {
    // Struct literals are weird sometimes. Using `@Type · @typeInfo` on them is a way to
    // ensure that we'll get a proper struct type.
    const Clauses: type = @Type(@typeInfo(@TypeOf(clauses)));
    return struct {
        // --- Requirements ---

        /// This function asks the `clauses` of the contract for a field with the same name as
        /// the `clause` parameter, and of the same type as the `default_clause` parameter. If no
        /// such field is found, it'll return the `default_clause` instead.
        ///
        /// # Usage
        /// Inside the returned namespace of an interface:
        ///
        /// ```zig
        /// // This will ask for a `comptime_int` to be passed as a field named `count`. If
        /// // There's none, it'll be `8`. If there's field named `count` that isn't a
        /// // `comptime_int`, it'll trigger a compile error with a meaningful message.
        /// pub const count = contract.default(.count, default_count);
        /// pub const default_count = 8
        /// ```
        pub inline fn default(
            comptime clause: EnumLiteral,
            comptime default_clause: anytype,
        ) @TypeOf(default_clause) {
            const name = @tagName(clause);
            if (!hasClause(clause)) return default_clause;
            return typeChecked(name, @TypeOf(default_clause));
        }

        /// This function requires the `clauses` of the contract to provide a field with the same
        /// name as `clause`, and of type `Clause`.
        ///
        /// # Usage
        /// Inside the return of an interface:
        ///
        /// ```zig
        /// // This will ask for a `comptime_int` to be passed as a field named `count`. If
        /// // There's none, or if there's field named `count` but it isn't a `usize`, it
        /// // will trigger a compile error with a meaningful message.
        /// pub const count = contract.require(.count, usize);
        /// ```
        pub inline fn require(comptime clause: EnumLiteral, comptime Clause: type) Clause {
            const name: []const u8 = @tagName(clause);
            if (!hasClause(clause)) utils.compileError(
                "`{s}` requires a `.{s}` clause of type `{s}`!",
                .{ full_name, name, @typeName(Clause) },
            );

            return typeChecked(name, Clause);
        }

        /// This function checks if a certain clause is given.
        pub inline fn hasClause(comptime clause: EnumLiteral) bool {
            return @hasField(Clauses, @tagName(clause));
        }

        /// This function checks if a certain clause is given and has the right type.
        pub inline fn hasClauseTyped(comptime clause: EnumLiteral, comptime Clause: type) bool {
            return hasClause(clause) and Clause == @TypeOf(@field(
                clauses,
                @tagName(clause),
            ));
        }

        fn typeChecked(comptime name: []const u8, comptime Type: type) Type {
            const clause = @field(clauses, name);
            const Clause = @TypeOf(clause);
            if (Clause != Type) utils.compileError(
                "{s} requires `.{s}` to be of type `{s}`, not `{s}`!",
                .{ full_name, name, @typeName(Type), @typeName(Clause) },
            );

            return clause;
        }

        // --- Testing ---

        /// This is the `.ub_checked` clause, by default `true`. For enabling runtime checks.
        pub const ub_checked: bool = default(.ub_checked, true);

        /// This is the `.sample` clause, by default an empty const slice of `Self`.
        pub const sample: []const Self = default(.sample, @as([]const Self, &.{}));

        // --- Mutation ---

        /// This is the `.Self` clause, by default `Contractor`.
        pub const Self: type = default(.Self, Contractor);

        /// This is the mutable version of `Self`.
        pub const VarSelf: type = switch (mutability) {
            .by_val => Self,
            .by_ref => *Self,
        };

        /// This function takes a `VarSelf` value, either `*Self` or `Self`, and returns an
        /// instance of `Self`.
        pub inline fn asSelf(self: VarSelf) Self {
            return switch (mutability) {
                .by_ref => self.*,
                .by_val => self,
            };
        }

        /// This function takes a `Self` reference and returns an instance of `VarSelf`, either
        /// `*Self` or `Self`.
        pub inline fn asVarSelf(self: *Self) VarSelf {
            return switch (mutability) {
                .by_ref => self,
                .by_val => self.*,
            };
        }

        /// The mutability determines whether `VarSelf` should be a reference (`*Self`) or a value
        /// (`Self`).
        pub const mutability: Mutability = if (hasClauseTyped(.mutability, Mutability))
            default(.mutability, Mutability.by_ref)
        else if (hasClauseTyped(.mutability, EnumLiteral)) enum_literal: {
            const enum_literal = require(.mutability, EnumLiteral);
            break :enum_literal if (enum_literal == .by_ref)
                Mutability.by_ref
            else if (enum_literal == .by_val)
                Mutability.by_val
            else
                require(.mutability, Mutability);
        } else Mutability.by_ref;

        // --- Naming ---
        // TODO: default name defined from interface

        pub const interface_name = default(.interface_name, @as(?[]const u8, null));
        pub const contractor_name = default(.contractor_name, @as(?[]const u8, null));
        pub const self_name = default(.self_name, @as(?[]const u8, null));

        pub fn getInterfaceName() []const u8 {
            comptime {
                return interface_name orelse "AnonymousInterface";
            }
        }

        pub fn getContractorName() []const u8 {
            comptime {
                return contractor_name orelse @typeName(Contractor);
            }
        }

        pub fn getSelfName() []const u8 {
            comptime {
                return self_name orelse @typeName(Self);
            }
        }

        const full_name: []const u8 = std.fmt.comptimePrint("{s}.{s}[{s}]", .{
            getContractorName(),
            getInterfaceName(),
            getSelfName(),
        });
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

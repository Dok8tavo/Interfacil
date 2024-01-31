//! Contracts are a very important part of interfaces. They're taking the clauses from the
//! `clauses` parameter of the interface, type-check them, and give them back for the making
//! of the namespace.

const std = @import("std");
const misc = @import("misc.zig");
const EnumLiteral = misc.EnumLiteral;

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
    /// The clauses are a struct literal, whose fields will fullfill the requirement of the
    /// contract. It's through them that the user will provide the values and declarations needed,
    /// or the options available, for returning the interface.
    comptime clauses: anytype,
) type {
    return struct {
        // Struct literals are weird sometimes. Using `@Type · @typeInfo` on them is a way to
        // ensure that we'll get a proper struct type.
        const Clauses: type = @Type(@typeInfo(@TypeOf(clauses)));

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
        pub fn default(
            comptime clause: EnumLiteral,
            comptime default_clause: anytype,
        ) @TypeOf(default_clause) {
            const name = @tagName(clause);
            if (!hasClause(clause)) return default_clause;
            return typeChecked(name, @TypeOf(default_clause));
        }

        /// This function checks if a certain clause is given.
        pub fn hasClause(comptime clause: EnumLiteral) bool {
            return @hasField(Clauses, @tagName(clause));
        }

        /// This function checks if a certain clause is given and has the right type.
        pub fn hasClauseTyped(comptime clause: EnumLiteral, comptime Clause: type) bool {
            return hasClause(clause) and Clause == @TypeOf(@field(
                clauses,
                @tagName(clause),
            ));
        }

        /// This function requires the `clauses` of the contract to provide a field with the same
        /// name as `clause`, and of type `Clause`.
        ///
        /// # Usage
        /// Inside the return of an interface:
        ///
        /// ```zig
        /// // This will ask for a `comptime_int` to be passed as a field named `count`. If
        /// // There's none, or if there's field named `count` but it isn't a `comptime_int`, it
        /// // will trigger a compile error with a meaningful message.
        /// pub const count = contract.require(.count, comptime_int);
        /// ```
        pub fn require(comptime clause: EnumLiteral, comptime Clause: type) Clause {
            const name: []const u8 = @tagName(clause);
            if (!hasClause(clause)) misc.compileError(
                "Interface of {s} requires a `.{s}` clause of type `{s}`!",
                .{ @typeName(Contractor), name, @typeName(Clause) },
            );

            return typeChecked(name, Clause);
        }

        fn typeChecked(comptime name: []const u8, comptime Type: type) Type {
            const clause = @field(clauses, name);
            const Clause = @TypeOf(clause);
            if (Clause != Type) misc.compileError(
                "Interface of `{s}` requires `{s}` to be of type `{s}`, not `{s}`!",
                .{ @typeName(Contractor), name, @typeName(Type), @typeName(Clause) },
            );

            return clause;
        }
    };
}

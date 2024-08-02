// MIT License
//
// Copyright (c) 2024 Dok8tavo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const config = @import("config");
const ifl = @import("interfacil.zig");
const std = @import("std");

pub const ContractOptions = struct {
    implementation_field: ?ifl.EnumLiteral = null,
    naming: @TypeOf(config.naming) = config.naming,
};

pub inline fn Contract(
    comptime Contractor: type,
    comptime clauses: anytype,
    comptime options: ContractOptions,
) type {
    const Clauses = @TypeOf(clauses);
    const unwrapped_implementation_field = options.implementation_field orelse ifl.compileError(
        "Some interface of the `{s}` type requires an implementation field!",
        .{switch (options.naming) {
            .full => @typeName(Contractor),
            .short => shortName(@typeName(Contractor)),
        }},
    );

    return struct {
        // --- Clauses ---
        pub inline fn default(
            comptime clause: ifl.EnumLiteral,
            comptime default_clause: anytype,
        ) @TypeOf(default_clause) {
            const name = @tagName(clause);
            if (!hasClause(clause)) return default_clause;
            return typeChecked(name, @TypeOf(default_clause));
        }

        pub inline fn require(comptime clause: ifl.EnumLiteral, comptime Clause: type) Clause {
            const name: []const u8 = @tagName(clause);
            if (!hasClause(clause)) ifl.compileError(
                "`{s}` requires a `.{s}` clause of type `{s}`!",
                .{ naming.interface, name, @typeName(Clause) },
            );

            return typeChecked(name, Clause);
        }

        pub inline fn hasClause(comptime clause: ifl.EnumLiteral) bool {
            return @hasField(Clauses, @tagName(clause));
        }

        pub inline fn hasClauseTyped(
            comptime clause: ifl.EnumLiteral,
            comptime Clause: type,
        ) bool {
            return hasClause(clause) and Clause == @TypeOf(@field(
                clauses,
                @tagName(clause),
            ));
        }

        // --- Implementation ---
        /// This function takes the implementation, _i.e._ the field implementing the interface, as
        /// a parameter; and returns the contractor, _i.e._ its parent struct.
        pub inline fn contractorFromImplementation(implementation: *Implementation) *Contractor {
            return @alignCast(@fieldParentPtr(naming.implementation_field, implementation));
        }

        /// The `Implementation` type is the type of the implementation field. It's also the result
        /// of the interface function.
        pub const Implementation = @TypeOf(@field(
            @as(Contractor, undefined),
            naming.implementation_field,
        ));

        // --- Names ---
        pub const naming = struct {
            pub const implementation_field = @tagName(unwrapped_implementation_field);

            pub const implementation_type_full = @typeName(Implementation);
            pub const contractor_type_full = @typeName(Contractor);

            pub const implementation_type_short = shortName(implementation_type_full);
            pub const contractor_type_short = shortName(contractor_type_full);

            pub const interface_full =
                contractor_type_full ++ " => [" ++
                implementation_field ++ ": " ++
                implementation_type_full ++ "(...)]";

            pub const interface_short =
                contractor_type_short ++ " => [" ++
                implementation_field ++ ": " ++
                implementation_type_short ++ "(...)]";

            pub const implementation_type = switch (options.naming) {
                .full => implementation_type_full,
                .short => implementation_type_short,
            };

            pub const contractor_type = switch (options.naming) {
                .full => contractor_type_full,
                .short => contractor_type_short,
            };

            pub const interface = switch (options.naming) {
                .full => interface_full,
                .short => interface_short,
            };
        };

        // This function is inlined in order to improve debugging messages
        inline fn typeChecked(comptime name: []const u8, comptime Type: type) Type {
            const clause = @field(clauses, name);
            const Clause = @TypeOf(clause);
            if (Clause != Type) ifl.compileError(
                "`{s}` requires `.{s}` to be of type `{s}`, not `{s}`!",
                .{ naming.interface, name, @typeName(Type), @typeName(Clause) },
            );

            return clause;
        }
    };
}

/// This function assumes no @"" shenanigans from type names, it also assumes those types
/// are user defined.
inline fn shortName(comptime type_name: []const u8) []const u8 {
    var index = type_name.len - 1;
    var parenthese_nesting: usize = 0;
    var in_string = false;
    var in_char = false;
    while (index != 0) : (index -= 1) {
        var c = type_name[index];
        if (in_string) {
            if (c == '\\') index += 1;
            if (c == '"') in_string = false;
            continue;
        }

        if (in_char) {
            if (c == '\\') index += 1;
            if (c == '\'') in_char = false;
            continue;
        }

        if (c == '(') parenthese_nesting -= 1;
        if (c == ')') parenthese_nesting += 1;
        if (parenthese_nesting != 0) continue;

        if (std.ascii.isAlphanumeric(c) or c == '_') {
            const end_index = index + 1;
            while (std.ascii.isAlphanumeric(c) or c == '_') {
                index -= 1;
                c = type_name[index];
            }

            return type_name[index + 1 .. end_index];
        }
    }

    unreachable;
}

test shortName {
    const expect = std.testing.expectEqualStrings;
    try expect("Contractor", shortName("file.Container.Contractor"));
    try expect("Generic", shortName("file.Generic(argument)"));
    try expect("Interface", shortName(
        \\file.Interface(file.Contractor, .{ .clause = "clause" }, .{ .option = 'o' }),
    ));
    try expect("Interface", shortName(
        \\file.Interface(file.Contractor, .{ .weird_clause = "some weird \"clause\", if I may say" }, .{})
    ));
}

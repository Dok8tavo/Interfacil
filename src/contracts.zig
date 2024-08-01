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

const ifl = @import("root.zig");
const std = @import("std");

pub inline fn Contract(
    comptime Contractor: type,
    comptime field: ifl.EnumLiteral,
    comptime clauses: anytype,
) type {
    const Clauses = @TypeOf(clauses);
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
                "{s} requires a `.{s}` clause of type `{s}`!",
                .{ implementation_name, name, @typeName(Clause) },
            );

            return typeChecked(name, Clause);
        }

        pub inline fn hasClause(comptime clause: ifl.EnumLiteral) bool {
            return @hasField(Clauses, @tagName(clause));
        }

        pub inline fn hasClauseTyped(comptime clause: ifl.EnumLiteral, comptime Clause: type) bool {
            return hasClause(clause) and Clause == @TypeOf(@field(
                clauses,
                @tagName(clause),
            ));
        }

        inline fn typeChecked(comptime name: []const u8, comptime Type: type) Type {
            const clause = @field(clauses, name);
            const Clause = @TypeOf(clause);
            if (Clause != Type) ifl.compileError(
                "{s} requires `.{s}` to be of type `{s}`, not `{s}`!",
                .{ implementation_name, name, @typeName(Type), @typeName(Clause) },
            );

            return clause;
        }

        pub fn contractorFromInterface(interface: *Interface) *Contractor {
            return @alignCast(@fieldParentPtr(field_name, interface));
        }

        pub const field_name = @tagName(field);
        pub const interface_name = @typeName(Interface);
        pub const contractor_name = @typeName(Contractor);
        pub const implementation_name = std.fmt.comptimePrint(
            "{s}[{s}.{s}]",
            .{ contractor_name, interface_name, field_name },
        );

        pub const Interface: type = @TypeOf(@field(@as(Contractor, undefined), field_name));
    };
}

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
    naming: @TypeOf(config.naming) = config.naming,
    interface_name: ?[]const u8 = null,
};

pub fn Contract(
    comptime Contractor: type,
    comptime clauses: anytype,
    comptime options: ContractOptions,
) type {
    const Clauses = @TypeOf(clauses);
    return struct {
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
                .{ interface_name, name, @typeName(Clause) },
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

        pub const interface_name = contractor_name ++ "[" ++ options.interface_name orelse "AnonymousInterface" ++ "]";
        pub const contractor_name = typeName(Contractor);

        pub fn overwrittenClauses(comptime overwrite: anytype) OverwrittenClauses(@TypeOf(overwrite)) {
            return .{};
        }

        pub fn OverwrittenClauses(comptime Overwrite: type) type {
            comptime {
                const Field = std.builtin.Type.StructField;
                // TODO: better debugging
                const overwrite_info = @typeInfo(Overwrite).Struct;
                const original_info = @typeInfo(Clauses).Struct;

                var fields: []const Field = overwrite_info.fields;
                for (original_info.fields) |field| {
                    if (!@hasField(Overwrite, field.name))
                        fields = fields ++ &[_]Field{field};
                }

                return @Type(.{ .Struct = std.builtin.Type.Struct{
                    .decls = &.{},
                    .fields = fields,
                    .is_tuple = false,
                    .layout = .auto,
                } });
            }
        }

        fn typeName(comptime T: type) []const u8 {
            comptime return switch (options.naming) {
                .full => @typeName(T),
                .short => shortName(@typeName(T)),
            };
        }

        fn typeChecked(comptime name: []const u8, comptime Type: type) Type {
            const clause = @field(clauses, name);
            const Clause = @TypeOf(clause);
            if (Clause != Type) ifl.compileError(
                "`{s}` requires `.{s}` to be of type `{s}`, not `{s}`!",
                .{ interface_name, name, @typeName(Type), @typeName(Clause) },
            );

            return clause;
        }
    };
}
test "Contract(...).overwrittenClauses" {
    const contract = Contract(void, .{
        .clause1 = 1,
        .clause2 = 2,
    }, .{});

    const Overwritten = @TypeOf(contract.overwrittenClauses(.{
        .clause2 = 3,
        .clause3 = 4,
    }));

    try std.testing.expectEqual(3, (Overwritten{}).clause2);
    try std.testing.expect(@hasField(Overwritten, "clause3"));

    const another_contract = Contract(void, .{
        .Item = u8,
        .next = fn (void) u8,
    }, .{});

    const AnotherOverwritten = @TypeOf(another_contract.overwrittenClauses(.{
        .next = fn (*anyopaque) u8,
    }));

    try std.testing.expectEqual(fn (*anyopaque) u8, (AnotherOverwritten{}).next);
    try std.testing.expect(@hasField(AnotherOverwritten, "Item"));
}

/// This function assumes no @"" shenanigans from type names, it also assumes those types
/// are user defined.
fn shortName(comptime type_name: []const u8) []const u8 {
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

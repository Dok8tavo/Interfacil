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

const Contract = ifl.Contract;

pub const IteratorOptions = struct {
    field: ifl.EnumLiteral = .as_iterator,
};

pub fn Iterator(
    comptime Contractor: type,
    comptime clauses: anytype,
    comptime options: IteratorOptions,
) type {
    const contract = Contract(Contractor, options.field, clauses);
    const ItemClause = contract.require(.Item, type);
    const nextClause = contract.require(.next, fn (*Contractor) ?ItemClause);
    return struct {
        const Self = @This();

        pub const Item = ItemClause;

        pub fn next(self: *Self) ?Item {
            const contractor = contract.contractorFromInterface(self);
            return nextClause(contractor);
        }

        pub fn skip(self: *Self) void {
            _ = self.next();
        }
    };
}

test {
    const ByteIterator = struct {
        as_iterator: AsIterator = .{},
        as_capital_iterator: AsCapitalIterator = .{},
        bytes: []const u8 = "Hello, World!",
        index: usize = 0,

        const AsIterator = Iterator(@This(), .{
            .Item = u8,
            .next = next,
        }, .{});

        const AsCapitalIterator = Iterator(@This(), .{
            .Item = u8,
            .next = nextCapital,
        }, .{ .field = .as_capital_iterator });

        pub fn next(self: *@This()) ?u8 {
            if (self.index == self.bytes.len) return null;
            defer self.index += 1;
            return self.bytes[self.index];
        }

        pub fn nextCapital(self: *@This()) ?u8 {
            return while (self.next()) |c| {
                if (std.ascii.isUpper(c)) break c;
            } else null;
        }
    };

    var byte_iterator = ByteIterator{};

    try std.testing.expectEqual('H', byte_iterator.as_iterator.next());
    try std.testing.expectEqual('e', byte_iterator.as_iterator.next());
    byte_iterator.as_iterator.skip();
    byte_iterator.as_iterator.skip();
    try std.testing.expectEqual('o', byte_iterator.as_iterator.next());
    try std.testing.expectEqual('W', byte_iterator.as_capital_iterator.next());
}

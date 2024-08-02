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

const ifl = @import("interfacil.zig");
const std = @import("std");

const Contract = ifl.Contract;
const ContractOptions = ifl.contracts.ContractOptions;

pub inline fn Iterator(
    comptime Contractor: type,
    comptime clauses: anytype,
    comptime options: ContractOptions,
) type {
    return struct {
        pub const contract = Contract(Contractor, clauses, ContractOptions{
            .implementation_field = options.implementation_field orelse .as_iterator,
            .naming = options.naming,
        });

        const Self = @This();

        const ItemClause = contract.require(.Item, type);
        const nextClause = contract.require(.next, fn (*Contractor) ?ItemClause);

        pub const Item = ItemClause;

        pub fn next(self: *Self) ?Item {
            const contractor = contract.contractorFromImplementation(self);
            return nextClause(contractor);
        }

        pub fn skip(self: *Self) void {
            _ = self.next();
        }

        pub fn skipMany(self: *Self, n: usize) void {
            for (0..n) |_| if (self.next() == null) break;
        }

        pub fn consumeIntoBuffer(self: *Self, buffer: []Item) error{BufferTooSmall}![]Item {
            return for (0..buffer.len) |index| {
                const item = self.next() orelse break buffer[0..index];
                buffer[index] = item;
            } else if (self.next() == null) buffer else error.BufferTooSmall;
        }
    };
}

test Iterator {
    const expect = std.testing.expectEqual;
    const Bytes = struct {
        as_iterator: AsIterator = .{},
        bytes: []const u8,
        index: usize = 0,

        const AsIterator = Iterator(Self, .{
            .Item = u8,
            .next = nextByte,
        }, .{});
        const Self = @This();

        fn nextByte(self: *Self) ?u8 {
            if (self.index == self.bytes.len) return null;
            defer self.index += 1;
            return self.bytes[self.index];
        }
    };

    var bytes = Bytes{ .bytes = "Hello world! How are you?" };
    try expect('H', bytes.as_iterator.next());
    try expect('e', bytes.as_iterator.next());
    try expect('l', bytes.as_iterator.next());
    try expect('l', bytes.as_iterator.next());
    try expect('o', bytes.as_iterator.next());
    bytes.as_iterator.skip(); // skipping " "
    try expect('w', bytes.as_iterator.next());
    bytes.as_iterator.skipMany(0); // skiping nothing
    try expect('o', bytes.as_iterator.next());
    bytes.as_iterator.skipMany(1); // skipping "r"
    try expect('l', bytes.as_iterator.next());
    bytes.as_iterator.skipMany(2); // skipping "d!"
    try expect(' ', bytes.as_iterator.next());

    const expected_end = "How are you?";
    var buffer: [expected_end.len]u8 = undefined;
    const end = try bytes.as_iterator.consumeIntoBuffer(&buffer);
    try std.testing.expectEqualStrings(expected_end, end);
}

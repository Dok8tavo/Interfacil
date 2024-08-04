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
const contracts = ifl.contracts;
const std = @import("std");

pub fn Iterator(
    comptime Contractor: type,
    comptime clauses: anytype,
    options: contracts.ContractOptions,
) type {
    return struct {
        pub const contract = contracts.Contract(Contractor, clauses, options);

        contractor: Contractor,

        pub const Item = contract.require(.Item, type);
        pub const BufferError = contract.default(.BufferError, error{BufferTooBig});

        const Self = @This();

        pub fn next(self: *Self) ?Item {
            const function = contract.require(.next, fn (*Contractor) ?Item);
            return function(&self.contractor);
        }

        pub fn skip(self: *Self) void {
            const function = contract.default(.skip, defaultSkip);
            function(&self.contractor);
        }

        pub fn skipMany(self: *Self, n: usize) void {
            const function = contract.default(.skipMany, defaultSkipMany);
            function(&self.contractor, n);
        }

        pub fn intoBuffer(self: *Self, buffer: []Item) BufferError![]Item {
            const function = contract.default(.intoBuffer, defaultIntoBuffer);
            return try function(&self.contractor, buffer);
        }

        // --- Filter ---

        pub fn filter(self: *Self, comptime predicate: fn (Item) bool) *Filter(predicate).AsIterator {
            return ifl.cast(self, Filter(predicate).AsIterator);
        }

        pub fn Filter(comptime predicate: fn (Item) bool) type {
            return struct {
                iterator: Self,

                pub const AsIterator = Iterator(@This(), .{
                    .Item = u8,
                    .next = nextFiltered,
                }, options);

                fn nextFiltered(self: *@This()) ?u8 {
                    return while (self.iterator.next()) |item| {
                        if (predicate(item)) break item;
                    } else null;
                }

                pub fn asIterator(self: *@This()) *AsIterator {
                    return ifl.cast(self, AsIterator);
                }
            };
        }

        // --- Map ---

        pub fn map(self: *Self, comptime Target: type, comptime predicate: fn (Item) Item) *Map(Target, predicate).AsIterator {
            return ifl.cast(self, Map(Target, predicate).AsIterator);
        }

        pub fn Map(comptime Target: type, comptime predicate: fn (Item) Target) type {
            return struct {
                iterator: Self,

                pub const AsIterator = Iterator(@This(), .{
                    .Item = Target,
                    .next = nextMapped,
                }, options);

                fn nextMapped(self: *@This()) ?Target {
                    return if (self.iterator.next()) |item| predicate(item) else null;
                }
            };
        }

        // --- default ---

        fn defaultIntoBuffer(contractor: *Contractor, buffer: []Item) BufferError![]Item {
            const self = ifl.cast(contractor, Self);
            var index: usize = 0;
            return while (self.next()) |item| : (index += 1) {
                if (buffer.len == index) break BufferError.BufferTooBig;
                buffer[index] = item;
            } else buffer[0..index];
        }

        fn defaultSkip(contractor: *Contractor) void {
            const self = ifl.cast(contractor, Self);
            _ = self.next();
        }

        fn defaultSkipMany(contractor: *Contractor, n: usize) void {
            const self = ifl.cast(contractor, Self);
            for (0..n) |_| if (self.next() == null) break;
        }
    };
}

test "Iterator(...).next" {
    const expect = std.testing.expectEqual;
    const Bytes = struct {
        bytes: []const u8,

        const Bytes = @This();
        const AsIterator = Iterator(Bytes, .{
            .next = next,
            .Item = u8,
        }, .{ .interface_name = "Iterator" });

        fn asIterator(self: *Bytes) *AsIterator {
            return ifl.cast(self, AsIterator);
        }

        fn next(self: *Bytes) ?u8 {
            if (self.bytes.len == 0) return null;
            defer self.bytes = self.bytes[1..];
            return self.bytes[0];
        }
    };

    var bytes = Bytes{ .bytes = "Hello world! How are you?" };
    var iterator = bytes.asIterator();
    try expect('H', iterator.next());
    try expect('e', iterator.next());
    try expect('l', iterator.next());
    try expect('l', iterator.next());
    try expect('o', iterator.next());
    iterator.skip(); // skipping ' '
    try expect('w', iterator.next());
    iterator.skipMany(1); // skipping 'o'
    try expect('r', iterator.next());
    iterator.skipMany(0); // skipping nothing
    try expect('l', iterator.next());
    iterator.skipMany(2); // skipping 'd' and '!'
    try expect(' ', iterator.next());

    var buffer: ["How are you?".len]u8 = undefined;
    const result = try iterator.intoBuffer(&buffer);
    try std.testing.expectEqualStrings("How are you?", result);
    try expect(null, iterator.next());

    // shouldn't be an error when both the buffer and the iterator are consumed
    _ = try iterator.intoBuffer(buffer[0..0]);
}

test "Iterator(...).filter" {
    const Bytes = struct {
        bytes: []const u8,

        const Bytes = @This();
        const AsIterator = Iterator(Bytes, .{
            .next = next,
            .Item = u8,
        }, .{ .interface_name = "Iterator" });

        fn asIterator(self: *Bytes) *AsIterator {
            return ifl.cast(self, AsIterator);
        }

        fn next(self: *Bytes) ?u8 {
            if (self.bytes.len == 0) return null;
            defer self.bytes = self.bytes[1..];
            return self.bytes[0];
        }

        fn isVowel(byte: u8) bool {
            return switch (byte) {
                'a', 'e', 'i', 'o', 'u' => true,
                else => false,
            };
        }
    };

    var bytes = Bytes{ .bytes = "Hello world! How are you?" };
    var iterator = bytes.asIterator()
        .filter(Bytes.isVowel);

    var buffer: ["eoooaeou".len]u8 = undefined;
    const result = try iterator.intoBuffer(&buffer);
    try std.testing.expectEqualStrings("eoooaeou", result);
}

test "Iterator(...).map" {
    const Bytes = struct {
        bytes: []const u8,

        const Bytes = @This();
        const AsIterator = Iterator(Bytes, .{
            .next = next,
            .Item = u8,
        }, .{ .interface_name = "Iterator" });

        fn asIterator(self: *Bytes) *AsIterator {
            return ifl.cast(self, AsIterator);
        }

        fn next(self: *Bytes) ?u8 {
            if (self.bytes.len == 0) return null;
            defer self.bytes = self.bytes[1..];
            return self.bytes[0];
        }

        fn intoUpper(byte: u8) u8 {
            return std.ascii.toUpper(byte);
        }
    };

    var bytes = Bytes{ .bytes = "Hello world! How are you?" };
    var iterator = bytes.asIterator()
        .map(u8, Bytes.intoUpper);

    var buffer: ["HELLO WORLD! HOW ARE YOU?".len]u8 = undefined;
    const result = try iterator.intoBuffer(&buffer);
    try std.testing.expectEqualStrings("HELLO WORLD! HOW ARE YOU?", result);
}

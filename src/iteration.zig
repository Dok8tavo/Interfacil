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

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn Iterator(
    comptime Contractor: type,
    comptime clauses: anytype,
    comptime options: contracts.ContractOptions,
) type {
    return struct {
        contractor: Contractor,

        const Self = @This();
        pub const contract = contracts.Contract(
            Contractor,
            clauses,
            options.overwritten(.{ .interface_name = options.interface_name orelse "Iterator" }),
        );

        // --- Next ---
        pub const Item = contract.require(.Item, type);
        pub const IntoBufferError = error{BufferTooSmall};

        pub fn next(self: *Self) ?Item {
            const function = contract.require(.next, fn (*Contractor) ?Item);
            return function(&self.contractor);
        }
        pub fn skip(self: *Self) void {
            _ = self.next();
        }
        pub fn skipMany(self: *Self, n: usize) void {
            for (0..n) |_| if (self.next() == null) break;
        }

        // --- Algebra ---
        /// This function consumes the iterator until it finds an item that doesn't satisfy the
        /// predicate.
        ///
        /// It returns `∀ item ∈ self : predicate(item)`
        pub fn all(self: *Self, comptime predicate: fn (Item) bool) bool {
            return while (self.next()) |item| {
                if (!predicate(item)) break false;
            } else true;
        }

        /// This function consumes the iterator until it finds an item that satisfy the predicate.
        ///
        /// It returns `∃ item ∈ self : predicate(item)`
        pub fn any(self: *Self, comptime predicate: fn (Item) bool) bool {
            return while (self.next()) |item| {
                if (predicate(item)) break true;
            } else false;
        }

        /// This function consumes the iterator until it finds an item that satisfy the predicate.
        ///
        /// It returns `∄ item ∈ self : predicate(item)`
        pub fn none(self: *Self, comptime predicate: fn (Item) bool) bool {
            return !self.any(predicate);
        }
        /// This function consumes the iterator until it finds an item that doesn't satisfy the
        /// predicate.
        ///
        /// It returns `¬∀ item ∈ self : predicate(item)`
        pub fn nall(self: *Self, comptime predicate: fn (Item) bool) bool {
            return !self.all(predicate);
        }

        // --- Collect ---
        /// This function consumes the iterator entirely. The caller owns the result.
        pub fn collectAlloc(self: *Self, allocator: Allocator) Allocator.Error!ArrayList(Item) {
            var list = ArrayList(Item).init(allocator);
            while (self.next()) |item| try list.append(item);
            return list;
        }
        /// This function consumes the iterator entirely, or until the buffer is full. The result
        /// points to the part of the buffer that contains the collected items.
        pub fn collectBuffer(self: *Self, buffer: []Item) IntoBufferError![]Item {
            var index: usize = 0;
            return while (self.next()) |item| : (index += 1) {
                if (buffer.len == index) break IntoBufferError.BufferTooSmall;
                buffer[index] = item;
            } else buffer[0..index];
        }

        // --- Reduce ---

        /// This function consumes the iterator entirely.
        /// Left reducing goes `(a, (b, (...)))`.
        pub fn reduceLeftAllInto(
            self: *Self,
            comptime predicate: fn (Item, Item) Item,
            into: *Item,
        ) void {
            while (self.next()) |item| into.* = predicate(item, into.*);
        }
        /// This function consumes the iterator entirely.
        /// Right reducing goes `(((...), y), z)`.
        pub fn reduceRightAllInto(
            self: *Self,
            comptime predicate: fn (Item, Item) Item,
            into: *Item,
        ) void {
            while (self.next()) |item| into.* = predicate(into.*, item);
        }
        /// This funciton consumes `n` items from the iterator, or the iterator entirely if `n` is
        /// greater than the number of items in the iterator.
        /// Left reducing goes `(a, (b, (...)))`.
        pub fn reduceLeftManyInto(
            self: *Self,
            comptime predicate: fn (Item, Item) Item,
            n: usize,
            into: *Item,
        ) void {
            for (0..n) |_| if (self.next()) |item| {
                into.* = predicate(item, into.*);
            } else break;
        }
        /// This funciton consumes `n` items from the iterator, or the iterator entirely if `n` is
        /// greater than the number of items in the iterator.
        /// Right reducing goes `(((...), y), z)`.
        pub fn reduceRightManyInto(
            self: *Self,
            comptime predicate: fn (Item, Item) Item,
            n: usize,
            into: *Item,
        ) void {
            for (0..n) |_| if (self.next()) |item| {
                into.* = predicate(into.*, item);
            } else break;
        }

        /// This function consumes the iterator entirely.
        /// Left reducing goes `(a, (b, (...)))`.
        /// If the iterator is empty, it returns `null`.
        pub fn reduceLeftAll(self: *Self, comptime predicate: fn (Item, Item) Item) ?Item {
            var into = self.next() orelse return null;
            self.reduceLeftAllInto(predicate, &into);
            return into;
        }
        /// This function consumes the iterator entirely.
        /// Right reducing goes `(((...), y), z)`.
        /// If the iterator is empty, it returns `null`.
        pub fn reduceRightAll(self: *Self, comptime predicate: fn (Item, Item) Item) ?Item {
            var into = self.next() orelse return null;
            self.reduceRightAllInto(predicate, &into);
            return into;
        }

        /// This funciton consumes `n` items from the iterator, or the iterator entirely if `n` is
        /// greater than the number of items in the iterator.
        /// Left reducing goes `(a, (b, (...)))`.
        /// If the iterator is empty, it returns `null`.
        pub fn reduceLeftMany(self: *Self, comptime predicate: fn (Item, Item) Item, n: usize) ?Item {
            if (n == 0) return null;
            var into = self.next() orelse return null;
            if (n == 1) return into;
            self.reduceLeftManyInto(predicate, n - 1, &into);
            return into;
        }
        /// This funciton consumes `n` items from the iterator, or the iterator entirely if `n` is
        /// greater than the number of items in the iterator.
        /// Right reducing goes `(((...), y), z)`.
        /// If the iterator is empty, it returns `null`.
        pub fn reduceRightMany(self: *Self, comptime predicate: fn (Item, Item) Item, n: usize) ?Item {
            if (n == 0) return null;
            var into = self.next() orelse return null;
            if (n == 1) return into;
            self.reduceRightManyInto(predicate, n - 1, &into);
            return into;
        }

        // --- Filter ---
        pub fn filter(
            self: *Self,
            comptime predicate: fn (Item) bool,
        ) *Filter(predicate).AsIterator {
            return ifl.cast(self, Filter(predicate).AsIterator);
        }

        pub fn Filter(comptime predicate: fn (Item) bool) type {
            return struct {
                iterator: Self,

                pub const AsIterator = Iterator(
                    @This(),
                    contract.overwrittenClauses(.{
                        .next = nextFiltered,
                    }),
                    options,
                );

                fn nextFiltered(self: *@This()) ?Item {
                    return while (self.iterator.next()) |item| {
                        if (predicate(item)) break item;
                    } else null;
                }
            };
        }

        // --- Map ---
        pub fn map(
            self: *Self,
            comptime Target: type,
            comptime predicate: fn (Item) Item,
        ) *Map(Target, predicate).AsIterator {
            return ifl.cast(self, Map(Target, predicate).AsIterator);
        }

        pub fn Map(comptime Target: type, comptime predicate: fn (Item) Target) type {
            return struct {
                iterator: Self,

                pub const AsIterator = Iterator(
                    @This(),
                    contract.overwrittenClauses(.{
                        .next = nextMapped,
                    }),
                    options,
                );

                fn nextMapped(self: *@This()) ?Target {
                    return if (self.iterator.next()) |item| predicate(item) else null;
                }
            };
        }

        // --- Map infer ---
        pub fn mapInfer(self: *Self, comptime predicate: anytype) *MapInfer(predicate).AsIterator {
            return ifl.cast(self, MapInfer(predicate).AsIterator);
        }
        pub fn MapInfer(comptime predicate: anytype) type {
            const Target = TargetFromMapPredicate(predicate);
            return Map(Target, predicate);
        }

        pub fn TargetFromMapPredicate(comptime map_predicate: anytype) type {
            const info = @typeInfo(@TypeOf(map_predicate));
            const function_info = switch (info) {
                .Fn => |function_info| function_info,
                else => ifl.compileError(
                    "`{s}` requires `.{s}` to be a function, not `{s}`!",
                    .{ options.interface_name, @typeName(@TypeOf(map_predicate)), @typeName(info) },
                ),
            };

            return function_info.return_type.?;
        }

        // --- Runtime ---
        pub fn asAny(self: *Self) AnyIterator(Item) {
            return AnyIterator(Item){
                .context = @ptrCast(@alignCast(self)),
                .nextFn = struct {
                    fn next(context: *anyopaque) ?Item {
                        const iterator = ifl.cast(context, Self);
                        return iterator.next();
                    }
                }.call,
            };
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
    const result = try iterator.collectBuffer(&buffer);
    try std.testing.expectEqualStrings("How are you?", result);
    try expect(null, iterator.next());

    // shouldn't be an error when both the buffer and the iterator are consumed
    _ = try iterator.collectBuffer(buffer[0..0]);
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
    const result = try iterator.collectBuffer(&buffer);
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
        .mapInfer(Bytes.intoUpper);

    var buffer: ["HELLO WORLD! HOW ARE YOU?".len]u8 = undefined;
    const result = try iterator.collectBuffer(&buffer);
    try std.testing.expectEqualStrings("HELLO WORLD! HOW ARE YOU?", result);
}

pub fn AnyIterator(comptime T: type) type {
    return struct {
        context: *anyopaque,
        nextFn: *const fn (*anyopaque) ?T,

        const Self = @This();

        pub const Item = T;
        pub const AsIterator = Iterator(Self, .{
            .next = next,
            .Item = Item,
        }, .{ .interface_name = "AnyIterator" });

        // --- Next ---
        pub fn next(self: *Self) ?Item {
            return self.nextFn(self.context);
        }

        // --- Conversion ---
        pub fn asIterator(self: *Self) *AsIterator {
            return ifl.cast(self, AsIterator);
        }
    };
}

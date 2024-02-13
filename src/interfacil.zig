//!zig-autodoc-guide: guides/conventions.md
//!zig-autodoc-guide: guides/glossary.md
//!zig-autodoc-section: tutorials
//!zig-autodoc-guide: guides/tutorials/interface-usage.md
//!zig-autodoc-guide: guides/tutorials/interface-writing.md

pub const comparison = @import("comparison.zig");
pub const contracts = @import("contracts.zig");
pub const io = @import("io.zig");
pub const collections = @import("collections.zig");
pub const members = @import("members.zig");
pub const memory = @import("memory.zig");
pub const utils = @import("utils.zig");

test {
    _ = comparison;
    _ = contracts;
    _ = io;
    _ = collections;
    _ = members;
    _ = memory;
    _ = utils;
}

const std = @import("std");
const expect = std.testing.expect;

const Version = struct {
    maj: u16 = 0,
    min: u16 = 1,
    patch: u32 = 0,

    fn cmpFn(self: Version, other: Version) comparison.Order {
        return if (self.maj < other.maj)
            .forwards
        else if (other.maj < self.maj)
            .backwards
        else if (self.min < other.min)
            .forwards
        else if (other.min < self.min)
            .backwards
        else if (self.patch < other.patch)
            .forwards
        else if (other.patch < self.patch)
            .backwards
        else
            .equals;
    }

    pub usingnamespace comparison.Ordered(Version, .{ .cmp = cmpFn });

    fn from(maj: u16, min: u16, patch: u32) Version {
        return .{
            .maj = maj,
            .min = min,
            .patch = patch,
        };
    }
};

test "Versioning: basic comparisons" {
    const v1 = Version.from(1, 1, 10);
    const v2 = Version.from(2, 1, 0);
    const v3 = Version.from(5, 0, 2);

    // v1 vs v2

    try expect(v1.lt(v2));
    try expect(v1.le(v2));
    try expect(!v1.eq(v2));
    try expect(!v1.ge(v2));
    try expect(!v1.gt(v2));

    try expect(!v2.lt(v1));
    try expect(!v2.le(v1));
    try expect(!v2.eq(v1));
    try expect(v2.ge(v1));
    try expect(v2.gt(v1));

    // v2 vs v3

    try expect(v2.lt(v3));
    try expect(v2.le(v3));
    try expect(!v2.eq(v3));
    try expect(!v2.ge(v3));
    try expect(!v2.gt(v3));

    try expect(!v3.lt(v2));
    try expect(!v3.le(v2));
    try expect(!v3.eq(v2));
    try expect(v3.ge(v2));
    try expect(v3.gt(v2));

    // v1 vs v3

    try expect(v1.lt(v3));
    try expect(v1.le(v3));
    try expect(!v1.eq(v3));
    try expect(!v1.ge(v3));
    try expect(!v1.gt(v3));

    try expect(!v3.lt(v1));
    try expect(!v3.le(v1));
    try expect(!v3.eq(v1));
    try expect(v3.ge(v1));
    try expect(v3.gt(v1));

    // self vs self

    try expect(!v1.lt(v1));
    try expect(v1.le(v1));
    try expect(v1.eq(v1));
    try expect(v1.ge(v1));
    try expect(!v1.gt(v1));

    try expect(!v2.lt(v2));
    try expect(v2.le(v2));
    try expect(v2.eq(v2));
    try expect(v2.ge(v2));
    try expect(!v2.gt(v2));

    try expect(!v3.lt(v3));
    try expect(v3.le(v3));
    try expect(v3.eq(v3));
    try expect(v3.ge(v3));
    try expect(!v3.gt(v3));
}

pub const Container = struct {
    items: []i32,

    fn getFn(self: Container, index: usize) ?i32 {
        return if (self.items.len <= index) null else self.items[index];
    }

    fn setFn(self: *Container, index: usize, value: i32) error{OutOfBounds}!void {
        if (self.items.len <= index) return error.OutOfBounds;
        self.items[index] = value;
    }

    pub usingnamespace collections.indexing.Indexable(Container, .{
        .Item = i32,
        .get = getFn,
        .set = setFn,
    });
};

test "Container: indexing" {
    var array = [_]i32{ 0, 1, 2, 3 };
    var container = Container{ .items = &array };
    try expect(container.getItem(0).? == 0);
    try expect(container.getItem(1).? == 1);
    try expect(container.getItem(2).? == 2);
    try expect(container.getItem(3).? == 3);
    const old_item = try container.setItem(0, -1000);
    try expect(container.getItem(0).? == -1000);
    try expect(old_item.? == 0);
    try expect(array[0] == -1000);
    try std.testing.expectError(error.OutOfBounds, container.setItem(4, 1000));
}

test "Container: indexer" {
    //pub fn main() !void {
    var array = [_]i32{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '!', '\n' };
    var container = Container{ .items = &array };
    const indexer = container.asIndexer();
    try expect(indexer.getItem(0).? == 'h');
    try expect(indexer.getItem(1).? == 'e');
    try expect(indexer.getItem(2).? == 'l');
    try expect(indexer.getItem(3).? == 'l');
    const old_item = try indexer.setItem(0, -1000);
    try expect(indexer.getItem(0).? == -1000);
    try expect(old_item.? == 'h');
    try expect(array[0] == -1000);
    try std.testing.expectError(error.OutOfBounds, indexer.setItem(100, 1000));
}

test "Container: indexable iterator" {
    var array = [_]i32{ -4, 0, 4, 8 };
    var container = Container{ .items = &array };
    var indexable_iterator = container.iterator();

    try std.testing.expectEqualDeep(indexable_iterator.next(), -4);
    try std.testing.expectEqualDeep(indexable_iterator.next(), 0);
    try std.testing.expectEqualDeep(indexable_iterator.next(), 4);
    try std.testing.expectEqualDeep(indexable_iterator.next(), 8);
    try std.testing.expectEqualDeep(indexable_iterator.next(), null);
}

test "Container: iterator" {
    var array = [_]i32{ -4, 0, 4, 8 };
    var container = Container{ .items = &array };
    var indexable_iterator = container.iterator();
    var iterator = indexable_iterator.asIterator();

    try std.testing.expectEqualDeep(iterator.next(), -4);
    try std.testing.expectEqualDeep(iterator.next(), 0);
    try std.testing.expectEqualDeep(iterator.next(), 4);
    try std.testing.expectEqualDeep(iterator.next(), 8);
    try std.testing.expectEqualDeep(iterator.next(), null);
}

test "Non-zeros: iterating, filtering and mapping" {
    var start: u8 = 1;
    const NonZero = struct {
        pub fn curr(ctx: *anyopaque) ?u8 {
            const context: *u8 = @alignCast(@ptrCast(ctx));
            return if (context.* == 0) null else context.*;
        }
        pub fn skip(ctx: *anyopaque) void {
            const context: *u8 = @alignCast(@ptrCast(ctx));
            if (context.* != 0) context.* +%= 1;
        }
    };
    
    var non_zeros = collections.iterating.Iterator(u8){
        .ctx = &start,
        .vtable = .{
            .curr = &NonZero.curr,
            .skip = &NonZero.skip,
        },
    };

    {
        defer start = 1;
        for (1..256) |i| {
            try std.testing.expectEqual(@as(u8, @intCast(i)), non_zeros.next());
        }

        try expect(non_zeros.next() == null);
    }

    {
        defer start = 1;
        const condition = struct {
            pub fn call(n: u8) bool {
                return n % 4 == 0;
            }
        }.call;

        const filtered = non_zeros.filter(&condition);
        while (filtered.next()) |num| {
            try expect(condition(num));
        }
    }

    {
        defer start = 1;
        const translator = struct {
            var buffer: [16]u8 = undefined;
            pub fn call(n: u8) []const u8 {
                return std.fmt.bufPrint(&buffer, "{}", .{n}) catch unreachable;
            }
        }.call;

        const mapped = non_zeros.map([]const u8, &translator);
        for (1..256) |i| {
            const item = mapped.next() orelse return error.Unreachable;
            const parsed = try std.fmt.parseInt(u8, item, 10);
            try std.testing.expectEqual(i, parsed);
        }
    }
}

const std = @import("std");
const utils = @import("utils.zig");
const contracts = @import("contracts.zig");
const comparison = @import("comparison.zig");

pub fn Iterable(
    comptime Contractor: type,
    comptime Provider: type,
    comptime options: contracts.Options(Contractor),
) type {
    const contract = contracts.Contract(Contractor, Provider, options);
    return struct {
        const Self = contract.Self;
        const VarSelf = contract.VarSelf;
        const Item = contract.require(.Item, type);

        pub fn next(self: VarSelf) ?Item {
            const function = contract.require(.next, fn (VarSelf) ?Item);
            return function(self);
        }

        pub fn reduce(self: *Self, predicate: *const fn (Item, Item) Item) ReducePeeker(Item) {
            return ReducePeeker(Item){
                .iterator = asIterator(self),
                .predicate = predicate,
                .peek_item = next(contract.asVarSelf(self)),
            };
        }

        pub fn filter(self: *Self, predicate: *const fn (Item) bool) FilterIterator(Item) {
            return FilterIterator(Item){
                .iterator = asIterator(self),
                .predicate = predicate,
            };
        }

        pub fn map(
            self: *Self,
            comptime ToItem: type,
            predicate: *const fn (Item) ToItem,
        ) MapIterator(Item, ToItem) {
            return MapIterator(Item, ToItem){
                .iterator = asIterator(self),
                .predicate = predicate,
            };
        }

        const VTable = struct {
            pub fn nextFunction(self: *anyopaque) ?Item {
                const self_ptr = utils.cast(Self, self);
                return next(contract.asVarSelf(self_ptr));
            }
        };

        pub fn asIterator(self: *Self) Iterator(Item) {
            return Iterator(Item){
                .context = self,
                .vtable = &.{
                    .next = &VTable.nextFunction,
                },
            };
        }

        pub fn asPeekableIterator(self: *Self) PeekableIterator(Item) {
            return PeekableIterator(Item){
                .iterator = asIterator(self),
                .peek_item = next(contract.asVarSelf(self)),
            };
        }
    };
}

test Iterable {
    const expect = std.testing.expectEqualDeep;
    const Naturals = struct {
        inner: ?usize = 0,

        const Self = @This();
        pub usingnamespace Iterable(Self, struct {
            pub const Item = usize;
            pub fn next(self: *Self) ?Item {
                const old = self.inner orelse return null;
                self.inner = if (old == std.math.maxInt(Item)) null else self.inner.? + 1;
                return old;
            }
        }, .{});
    };

    var naturals = Naturals{};

    {
        defer naturals.inner = 0;
        try expect(@as(?usize, 0), naturals.next());
        try expect(@as(?usize, 1), naturals.next());
        try expect(@as(?usize, 2), naturals.next());
        try expect(@as(?usize, 3), naturals.next());
        try expect(@as(?usize, 4), naturals.next());
    }

    {
        defer naturals.inner = 0;
        var evens = naturals.filter(&struct {
            pub fn isEven(x: usize) bool {
                return x % 2 == 0;
            }
        }.isEven);

        try expect(@as(?usize, 0), evens.next());
        try expect(@as(?usize, 2), evens.next());
        try expect(@as(?usize, 4), evens.next());
        try expect(@as(?usize, 6), evens.next());
        try expect(@as(?usize, 8), evens.next());
    }

    {
        defer naturals.inner = 0;
        var negatives = naturals.map(isize, &struct {
            pub fn negate(x: usize) isize {
                return -@as(isize, @intCast(x));
            }
        }.negate);

        try expect(@as(?isize, 0), negatives.next());
        try expect(@as(?isize, -1), negatives.next());
        try expect(@as(?isize, -2), negatives.next());
        try expect(@as(?isize, -3), negatives.next());
        try expect(@as(?isize, -4), negatives.next());
    }

    {
        defer naturals.inner = 0;
        var reduced = naturals.reduce(&struct {
            pub fn mul(x: usize, y: usize) usize {
                return if (x == 0) 1 else x * y;
            }
        }.mul);
        var factorials = reduced.map(usize, &struct {
            pub fn call(x: usize) usize {
                return if (x == 0) 1 else x;
            }
        }.call);

        try expect(@as(?usize, 1), factorials.next());
        try expect(@as(?usize, 1), factorials.next());
        try expect(@as(?usize, 2), factorials.next());
        try expect(@as(?usize, 6), factorials.next());
        try expect(@as(?usize, 24), factorials.next());
    }
}

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        context: *anyopaque,
        vtable: *const struct {
            next: *const fn (*anyopaque) ?T,
        },

        pub usingnamespace Iterable(Self, struct {
            pub const Item = T;
            pub fn next(self: Iterator(Item)) ?Item {
                return self.vtable.next(self.context);
            }
        }, .{ .mutability = .by_val });

        pub fn fromIterable(iterable: anytype) Self {
            const Type = @TypeOf(iterable);
            const info = @typeInfo(Type);
            if (Type == Self) return iterable;

            // todo: support more cases and update test accordingly
            // todo: refactor this unreadable mess
            return switch (info) {
                .Pointer => |Pointer| switch (Pointer.size) {
                    .One => if (Pointer.child == Self) iterable.* else {
                        const child_info = @typeInfo(Pointer.child);
                        switch (child_info) {
                            .Struct, .Enum, .Union, .Opaque => if (@hasDecl(Pointer.child, "asIterator")) {
                                const asIterator = @field(Pointer.child, "asIterator");
                                return switch (@TypeOf(asIterator)) {
                                    fn (Pointer.child) Self => asIterator(iterable.*),
                                    fn (*const Pointer.child) Self => asIterator(iterable),
                                    fn (*Pointer.child) Self => if (Pointer.is_const) 
                                        fromIterableError(Type)
                                     else asIterator(iterable),
                                    else => {
                                        @compileLog(@TypeOf(asIterator));
                                        fromIterableError(Type);
                                    },
                                };
                            },
                            else => fromIterableError(Type),
                        }
                    },
                    else => fromIterableError(Type),
                },
                else => fromIterableError(Type),
            };
        }

        inline fn fromIterableError(comptime Type: type) noreturn {
            utils.compileError(
                "`Iterator.fromIterable` can't be used (yet?) on the type `{s}`!",
                .{@typeName(Type)},
            );
        }
    };
}

pub fn PeekableIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(T),
        peek_item: ?T,

        pub usingnamespace Peekable(Self, struct {
            pub const Item = T;
            pub fn peek(self: Self) ?Item {
                return self.peek_item;
            }

            pub fn skip(self: *Self) void {
                self.peek_item = self.iterator.next();
            }
        }, .{});
    };
}

pub fn ReducePeeker(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(T),
        predicate: *const fn (T, T) T,
        peek_item: ?T,

        pub usingnamespace Peekable(Self, struct {
            pub const Item = T;
            pub fn peek(self: Self) ?Item {
                return self.peek_item;
            }

            pub fn skip(self: *Self) void {
                const next_item = self.iterator.next() orelse return {
                    self.peek_item = null;
                };

                if (self.peek_item) |peek_item| {
                    self.peek_item = self.predicate(peek_item, next_item);
                } else self.peek_item = next_item;
            }
        }, .{});
    };
}

pub fn FilterIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(T),
        predicate: *const fn (T) bool,

        pub usingnamespace Iterable(Self, struct {
            pub const Item = T;
            pub fn next(self: Self) ?Item {
                return while (self.iterator.next()) |item| {
                    if (self.predicate(item))
                        break item;
                } else null;
            }
        }, .{ .mutability = .by_val });
    };
}

pub fn MapIterator(comptime FromItem: type, comptime ToItem: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(FromItem),
        predicate: *const fn (FromItem) ToItem,

        pub usingnamespace Iterable(Self, struct {
            pub const Item = ToItem;
            pub fn next(self: Self) ?Item {
                return if (self.iterator.next()) |item| self.predicate(item) else null;
            }
        }, .{ .mutability = .by_val });
    };
}

pub fn Peekable(
    comptime Contractor: type,
    comptime Provider: type,
    comptime options: contracts.Options(Contractor),
) type {
    const contract = contracts.Contract(Contractor, Provider, options);
    return struct {
        const Self = contract.Self;
        const VarSelf = contract.VarSelf;
        const T = contract.require(.Item, type);

        pub fn peek(self: Self) ?T {
            const function = contract.require(.peek, fn (Self) ?T);
            return function(self);
        }

        pub fn skip(self: VarSelf) void {
            const function = contract.require(.skip, fn (VarSelf) void);
            function(self);
        }

        pub usingnamespace Iterable(Self, struct {
            pub const Item = T;
            pub fn next(self: VarSelf) ?Item {
                const item = self.peek() orelse return null;
                self.skip();
                return item;
            }
        }, options);
    };
}

pub fn Peeker(comptime T: type) type {
    return struct {
        const Self = @This();

        context: *anyopaque,
        vtable: struct {
            skip: *const fn (*anyopaque) void,
            peek: *const fn (*anyopaque) ?T,
        },

        pub usingnamespace Peekable(Self, struct {
            pub const Item = T;
            pub fn peek(self: Self) ?Item {
                return self.vtable.peek(self.context);
            }

            pub fn skip(self: Self) void {
                self.vtable.skip(self.context);
            }
        }, .{ .mutability = .by_val });

        pub fn fromPeekable(peekable: anytype) Self {
            const Type = @TypeOf(peekable);

            if (Type == Self) return peekable;
            if (@hasDecl(Type, "asPeeker")) {
                const asPeeker = @field(Type, "asPeeker");
                if (@TypeOf(asPeeker) == fn (*Type) Self) {
                    return asPeeker(peekable);
                }
            }

            utils.compileError(
                "The `Peeker.fromPeekable` function can't be used (yet?) with `{s}`!",
                .{@typeName(Type)},
            );
        }
    };
}

pub fn SlicePeeker(comptime T: type, comptime mutable: bool) type {
    return struct {
        const Self = @This();
        const Slice = if (mutable) []T else []const T;

        slice: Slice,
        index: usize = 0,

        pub fn from(slice: Slice) Self {
            return Self{ .slice = slice };
        }

        pub fn reinit(self: *Self) void {
            self.index = 0;
        }

        pub usingnamespace Peekable(Self, struct {
            pub const Item = Slice;
            pub fn peek(self: Self) ?Slice {
                if (self.slice.len <= self.index) return null;
                return self.slice[self.index..];
            }

            pub fn skip(self: *Self) void {
                self.index += 1;
            }
        }, .{});

        pub fn asItemPeeker(self: *Self) Peeker(T) {
            const VTable = struct {
                fn peekItem(context: *anyopaque) ?T {
                    const cast = utils.cast(Self, context);
                    const slice = cast.peek();
                    return if (slice) |s| (if (mutable) &s[0] else s[0]) else null;
                }

                fn skipItem(context: *anyopaque) void {
                    const cast = utils.cast(Self, context);
                    cast.skip();
                }
            };

            return Peeker(if (mutable) *T else T){
                .context = self,
                .vtable = .{
                    .skip = VTable.skipItem,
                    .peek = VTable.peekItem,
                },
            };
        }
    };
}

test SlicePeeker {
    const expect = std.testing.expectEqualSlices;
    const set = [_]isize{ 0, 1, 2, 3, 4, 5 };
    var slice_peeker = SlicePeeker(isize, false).from(&set);

    {
        defer slice_peeker.reinit();

        try expect(isize, &[_]isize{ 0, 1, 2, 3, 4, 5 }, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try expect(isize, &[_]isize{ 1, 2, 3, 4, 5 }, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try expect(isize, &[_]isize{ 2, 3, 4, 5 }, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try expect(isize, &[_]isize{ 3, 4, 5 }, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try expect(isize, &[_]isize{ 4, 5 }, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try expect(isize, &[_]isize{5}, slice_peeker.peek() orelse &[_]isize{});
        slice_peeker.skip();

        try std.testing.expectEqualDeep(@as(?[]const isize, null), slice_peeker.peek());
        slice_peeker.skip();

        try std.testing.expectEqualDeep(@as(?[]const isize, null), slice_peeker.peek());
        slice_peeker.skip();
    }

    {
        defer slice_peeker.reinit();
        try expect(isize, &[_]isize{ 0, 1, 2, 3, 4, 5 }, slice_peeker.next() orelse &[_]isize{});
        try expect(isize, &[_]isize{ 1, 2, 3, 4, 5 }, slice_peeker.next() orelse &[_]isize{});
        try expect(isize, &[_]isize{ 2, 3, 4, 5 }, slice_peeker.next() orelse &[_]isize{});
        try expect(isize, &[_]isize{ 3, 4, 5 }, slice_peeker.next() orelse &[_]isize{});
        try expect(isize, &[_]isize{ 4, 5 }, slice_peeker.next() orelse &[_]isize{});
        try expect(isize, &[_]isize{5}, slice_peeker.next() orelse &[_]isize{});
        try std.testing.expectEqualDeep(@as(?[]const isize, null), slice_peeker.next());
        try std.testing.expectEqualDeep(@as(?[]const isize, null), slice_peeker.next());
    }

    var peeker = slice_peeker.asItemPeeker();
    var buffer: [set.len]isize = undefined;
    var index: usize = 0;

    {
        defer {
            slice_peeker.reinit();
            index = 0;
        }

        var odds = peeker.filter(&struct {
            pub fn isOdd(n: isize) bool {
                return @rem(n, 2) != 0;
            }
        }.isOdd);

        while (odds.next()) |odd| : (index += 1) {
            buffer[index] = odd;
        }

        try expect(isize, &[_]isize{ 1, 3, 5 }, buffer[0..index]);
    }

    {
        defer {
            slice_peeker.reinit();
            index = 0;
        }

        var evens = peeker.filter(&struct {
            pub fn isEven(self: isize) bool {
                return @rem(self, 2) == 0;
            }
        }.isEven);

        while (evens.next()) |even| : (index += 1) {
            buffer[index] = even;
        }

        try expect(isize, &[_]isize{ 0, 2, 4 }, buffer[0..index]);
    }

    {
        defer {
            slice_peeker.reinit();
            index = 0;
        }
        var i128_buffer: [6]i128 = undefined;

        var doubles = peeker.map(i128, struct {
            pub fn double(self: isize) i128 {
                return 2 * self;
            }
        }.double);

        while (doubles.next()) |double| : (index += 1) {
            i128_buffer[index] = double;
        }

        try expect(i128, &[_]i128{ 0, 2, 4, 6, 8, 10 }, i128_buffer[0..index]);
    }

    {
        defer {
            slice_peeker.reinit();
            index = 0;
        }

        var sum = peeker.reduce(&struct {
            pub fn add(self: isize, other: isize) isize {
                return self + other;
            }
        }.add);

        while (sum.next()) |partial| : (index += 1) {
            buffer[index] = partial;
        }

        try expect(isize, &[_]isize{ 0, 1, 3, 6, 10, 15 }, buffer[0..index]);
    }
}

pub fn MultIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        iterators: Peeker(Iterator(T)),

        pub usingnamespace Iterable(Self, struct {
            pub const Item = T;
            pub fn next(self: *Self) ?Item {
                return while (self.iterators.peek()) |iterator| : (self.iterators.skip()) {
                    if (iterator.next()) |item| break item;
                } else null;
            }
        }, .{});
    };
}

pub fn MultPeeker(comptime T: type) type {
    return struct {
        const Self = @This();

        peekers: Peeker(Peeker(T)),

        pub usingnamespace Peekable(Self, struct {
            pub const Item = T;
            pub fn skip(self: *Self) void {
                while (self.peekers.peek()) |peeker| : (self.peekers.skip()) {
                    if (peeker.peek()) |_| {
                        peeker.skip();
                        return;
                    }
                }
            }

            pub fn peek(self: Self) ?Item {
                return while (self.peekers.peek()) |peeker| : (self.peekers.skip()) {
                    if (peeker.next()) |item| break item;
                } else null;
            }
        }, .{});
    };
}

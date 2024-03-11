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

        const vtable = VTable{};
        const VTable = struct {
            next: *const fn (*anyopaque) ?Item = &nextFunction,

            pub fn nextFunction(self: *anyopaque) ?Item {
                const self_ptr: *Self = utils.cast(self);
                return next(self_ptr);
            }
        };

        pub fn asIterator(self: *Self) Iterator(Item) {
            return Iterator(Item){
                .context = self,
                .vtable = &vtable,
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

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        context: *anyopaque,
        vtable: *const struct {
            next: fn (*anyopaque) ?T,
        },

        pub usingnamespace Iterable(Self, struct {
            pub const Item = T;
            pub fn next(self: Iterator) ?Item {
                return self.vtable.next(self.context);
            }
        }, .{ .mutability = .by_val });

        pub fn fromIterable(iterable: anytype) Self {
            const Type = @TypeOf(iterable);
            if (Type == Self) return iterable;
            if (@hasDecl(Type, "asIterator")) {
                const asIterator = @field(Type, "asIterator");
                if (@TypeOf(asIterator) == fn (Type) Self) {
                    return asIterator(iterable);
                }
            }

            const info = @typeInfo(Type);
            return switch (info) {
                // todo
                else => utils.compileError(
                    "`Iterator.fromAny` can't be used (yet?) on the type `{s}`!",
                    .{@typeName(Type)},
                ),
            };
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
                self.peek_item = self.iterator.next();
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
            pub fn next(self: *Self) ?Item {
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
            pub fn next(self: *Self) ?Item {
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
                const item = self.peek() orelse return;
                self.skip();
                return item;
            }
        }, .{});
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

            pub fn next(self: *Self) void {
                self.vtable.next(self.context);
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
                    const cast: *Self = utils.cast(context);
                    const slice = cast.curr();
                    return if (slice) |s| (if (mutable) &s[0] else s[0]) else null;
                }
            };

            return Peeker(if (mutable) *T else T){
                .context = self,
                .vtable = .{
                    .skip = Self.skip,
                    .peek = VTable.peekItem,
                },
            };
        }
    };
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

const contracts = @import("../contracts.zig");
const iterating = @import("iterating.zig");

pub fn Indexable(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.getSelf();
    const VarSelf: type = contract.getVarSelf();
    const Item = contract.require(.Item, type);
    const set = contract.require(.set, fn (self: VarSelf, index: usize, item: Item) error{OutOfBounds}!void);

    return struct {
        pub const getItem = contract.require(.get, fn (self: Self, index: usize) ?Item);

        pub fn setItem(self: VarSelf, index: usize, item: Item) error{OutOfBounds}!?Item {
            const old = getItem(contract.asValue(self), index);
            try set(self, index, item);
            return old;
        }

        pub const IndexableIterator = struct {
            context: *Self,
            index: usize = 0,

            fn currWrapper(self: IndexableIterator) ?Item {
                return getItem(self.context.*, self.index);
            }

            fn skipWrapper(self: *IndexableIterator) void {
                self.index += 1;
            }

            fn skipBackWrapper(self: *IndexableIterator) void {
                self.index -|= 1;
            }

            pub usingnamespace iterating.BidirectionIterable(Contractor, .{
                .Self = IndexableIterator,
                .Item = Item,
                .curr = currWrapper,
                .skip = skipWrapper,
                .skipBack = skipBackWrapper,
            });
        };

        pub fn iterator(self: *Self) IndexableIterator {
            return IndexableIterator{ .context = self };
        }

        pub fn asIndexer(self: *Self) Indexer(Item) {
            return Indexer(Item){
                .context = self,
                .vtable = .{
                    .get = &struct {
                        pub fn call(context: *anyopaque, index: usize) ?Item {
                            const ctx: *Self = @alignCast(@ptrCast(context));
                            return getItem(ctx.*, index);
                        }
                    }.call,
                    .set = &struct {
                        pub fn call(
                            context: *anyopaque,
                            index: usize,
                            value: Item,
                        ) error{OutOfBounds}!void {
                            const ctx: *Self = @alignCast(@ptrCast(context));
                            return set(ctx, index, value);
                        }
                    }.call,
                },
            };
        }
    };
}

pub fn Indexer(comptime Item: type) type {
    return struct {
        const Self = @This();

        context: *anyopaque,
        vtable: struct {
            get: *const fn (*anyopaque, usize) ?Item,
            set: *const fn (*anyopaque, usize, Item) error{OutOfBounds}!void,
        },

        fn getWrapper(self: Self, index: usize) ?Item {
            return self.vtable.get(self.context, index);
        }

        fn setWrapper(self: Self, index: usize, item: Item) error{OutOfBounds}!void {
            try self.vtable.set(self.context, index, item);
        }

        pub usingnamespace Indexable(Self, .{
            .mutation = contracts.Mutation.by_val,
            .Item = Item,
            .get = getWrapper,
            .set = setWrapper,
        });
    };
}

const contracts = @import("../contracts.zig");
const iterating = @import("iterating.zig");

pub fn Indexable(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);
        const Self: type = contract.default(.Self, Contractor);
        const mut_by_value: bool = contract.default(.mut_by_value, false);
        const VarSelf = if (mut_by_value) Self else *Self;
        const Item = contract.require(.Item, type);

        pub const getItem = contract.require(.get, fn (self: Self, index: usize) ?Item);
        const set = contract.require(.set, fn (self: VarSelf, index: usize, item: Item) error{OutOfBounds}!void);

        pub fn setItem(self: VarSelf, index: usize, item: Item) error{OutOfBounds}!?Item {
            const old = getItem(index, item) orelse return null;
            try set(self, index, item);
            return old;
        }

        pub const IndexableIterator = struct {
            context: *const Self,
            index: usize = 0,

            fn currWrapper(self: IndexableIterator) ?Item {
                return getItem(self.index, self.context.*);
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

        pub fn iterator(self: Self) IndexableIterator {
            return IndexableIterator{ .context = &self };
        }

        pub fn asIndexer(self: Self) Indexer(Item) {
            return Indexer(Item){
                .context = &self,
                .vtable = .{
                    .get = &getItem,
                    .set = &set,
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
            .mut_by_value = true,
            .Item = Item,
            .get = getWrapper,
            .set = setWrapper,
        });
    };
}

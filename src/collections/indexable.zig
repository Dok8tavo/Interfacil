const contracts = @import("../contracts.zig");

pub fn Indexable(comptime Contract: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contract, clauses);
        const Self: type = contract.default(.Self, Contract);
        const VarSelf: type = contract.default(.VarSelf, *Self);
        const Item = contract.require(.Item, type);

        pub const getItem = contract.require(.get, fn (self: Self, index: usize) ?Item);
        const set = contract.require(.set, fn (self: *Self, index: usize, item: Item) void);

        pub fn setItem(self: *Self, index: usize, item: Item) ?Item {
            const old = getItem(index, item) orelse return null;
            set(self, index, item);
            return old;
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
            set: *const fn (*anyopaque, usize, Item) void,
        },

        fn getFn(self: Self, index: usize) ?Item {
            return self.vtable.get(self.context, index);
        }

        fn setFn(self: Self, index: usize, item: Item) void {
            self.vtable.set(self.context, index, item);
        }

        pub usingnamespace Indexable(Self, .{
            .VarSelf = Self,
            .Item = Item,
            .get = getFn,
            .set = setFn,
        });
    };
}

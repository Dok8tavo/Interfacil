const contracts = @import("contracts.zig");

pub fn Iterable(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        const Self: type = contract.default(.Self, Contractor);
        const VarSelf: type = contract.default(.VarSelf, *Self);
        const Item = contract.require(.Item, type);

        pub const curr = contract.require(.curr, fn (Self) ?Item);
        pub const skip = contract.require(.skip, fn (VarSelf) void);

        pub fn next(self: VarSelf) ?Item {
            skip(self);
            return curr(self);
        }

        pub fn skipTimes(self: VarSelf, times: usize) void {
            for (0..times) |_| if (next(self) == null) return null;
        }

        pub fn nextTimes(self: VarSelf, times: usize) ?Item {
            skipTimes(self, times);
            return curr(self);
        }

        pub fn asIterator(self: VarSelf) Iterator(Item) {
            return Iterator(Item){
                .ctx = self,
                .vtable = .{
                    .skip = &skip,
                    .curr = &curr,
                },
            };
        }
    };
}

pub fn Iterator(comptime Item: type) type {
    return struct {
        const Self = @This();

        ctx: *anyopaque,
        vtable: struct {
            skip: *const fn (*anyopaque) void,
            curr: *const fn (*anyopaque) ?Item,
        },

        fn currFn(self: Self) ?Item {
            return self.vtable.curr(self.ctx);
        }

        fn skipFn(self: Self) void {
            self.vtable.skip(self.ctx);
        }

        pub usingnamespace Iterable(Self, .{
            .VarSelf = Self,
            .Item = Item,
            .curr = currFn,
            .skip = skipFn,
        });
    };
}

pub fn BidirectionIterable(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        const Self: type = contract.default(.Self, Contractor);
        const VarSelf: type = contract.default(.VarSelf, *Self);
        const Item = contract.require(.Item, type);
        const skipBack = contract.require(.skipBack, fn (Self) Item);

        const forwards_iterable = Iterable(Contractor, clauses);
        const backwards_iterable = Iterable(Contractor, .{
            .Self = Self,
            .VarSelf = VarSelf,
            .Item = Item,
            .skip = skipBack,
            .curr = forwards_iterable.curr,
        });

        pub usingnamespace forwards_iterable;
        pub const prevTimes = backwards_iterable.nextTimes;
        pub const prev = backwards_iterable.next;
        pub const skipBackTimes = backwards_iterable.skipTimes;

        pub fn asBidirectionIterator(self: Self) BidirectionIterator(Item) {
            return BidirectionIterator(Item){
                .ctx = self,
                .vtable = .{
                    .skip = &forwards_iterable.skip,
                    .curr = &forwards_iterable.curr,
                    .skipBack = &skipBack,
                },
            };
        }

        pub fn asBackwardsIterator(self: Self) Iterator(Item) {
            return Backwards.asIterator(self);
        }

        pub const Backwards = BidirectionIterable(Contractor, .{
            .Self = Self,
            .VarSelf = VarSelf,
            .Item = Item,
            .skip = backwards_iterable.skip,
            .skipBack = forwards_iterable.skip,
            .curr = forwards_iterable.curr,
        });
    };
}

pub fn BidirectionIterator(comptime Item: type) type {
    return struct {
        const Self = @This();

        ctx: *anyopaque,
        vtable: struct {
            skip: *const fn (*anyopaque) void,
            curr: *const fn (*anyopaque) ?*Item,
            skipBack: *const fn (*anyopaque) void,
        },

        fn skipBackFn(self: Self) void {
            self.vtable.skipBack(self.ctx);
        }

        fn currFn(self: Self) ?Item {
            return self.vtable.curr(self.ctx);
        }

        fn skipFn(self: Self) void {
            self.vtable.skip(self.ctx);
        }

        pub usingnamespace Iterable(Iterator, .{
            .VarSelf = Iterator,
            .Item = Item,
            .curr = currFn,
            .skip = skipFn,
            .skipBack = skipBackFn,
        });
    };
}

pub fn SliceIterator(comptime Item: type) type {
    return struct {
        const Self = @This();

        index: usize = 0,
        slice: []const Item,

        fn currWrapper(self: Self) ?Item {
            return if (self.index <= self.slice.len) null else self.slice[self.index];
        }

        fn skipWrapper(self: *Self) void {
            self.index +|= 1;
        }

        fn skipBackWrapper(self: *Self) void {
            self.index -|= 1;
        }

        pub usingnamespace BidirectionIterable(SliceIterator, .{
            .curr = currWrapper,
            .skip = skipWrapper,
            .skipBack = skipBackWrapper,
        });
    };
}

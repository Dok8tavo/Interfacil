const std = @import("std");
const contracts = @import("../contracts.zig");

/// # Iterable
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
///
pub fn Iterable(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.getSelf();
    const VarSelf: type = contract.getVarSelf();
    const Item = contract.require(.Item, type);

    return struct {
        pub const curr = contract.require(.curr, fn (Self) ?Item);
        pub const skip = contract.require(.skip, fn (VarSelf) void);

        pub fn next(self: VarSelf) ?Item {
            if (curr(contract.asSelf(self))) |item| {
                defer skip(self);
                return item;
            } else return null;
        }

        pub fn skipTimes(self: VarSelf, times: usize) void {
            for (0..times) |_| if (next(self) == null) return null;
        }

        pub fn nextTimes(self: VarSelf, times: usize) ?Item {
            skipTimes(self, times);
            return curr(self);
        }

        pub fn populateSliceBuffer(self: VarSelf, buffer: []Item) error{OutOfBounds}![]Item {
            var index: usize = 0;
            return while (next(self)) |item| {
                if (index == buffer.len) break error.OutOfBounds;
                buffer[index] = item;
                index += 1;
            } else buffer[0..index];
        }

        pub fn populateSliceAlloc(
            self: VarSelf,
            allocator: std.mem.Allocator,
        ) error{OutOfMemory}![]Item {
            var array_list = std.ArrayList(Item).init(allocator);
            while (next(self)) |item| {
                try array_list.append(item);
            }

            array_list.shrinkRetainingCapacity(array_list.items.len);
            return array_list.items;
        }

        pub fn asIterator(self: *Self) Iterator(Item) {
            return Iterator(Item){
                .ctx = self,
                .vtable = .{
                    .skip = &struct {
                        pub fn call(context: *anyopaque) void {
                            const ctx: *Self = @alignCast(@ptrCast(context));
                            skip(contract.asVarSelf(ctx));
                        }
                    }.call,
                    .curr = &struct {
                        pub fn call(context: *anyopaque) ?Item {
                            const ctx: *Self = @alignCast(@ptrCast(context));
                            return curr(ctx.*);
                        }
                    }.call,
                },
            };
        }
    };
}

/// TODO
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
            .mutation = contracts.Mutation.by_val,
            .Item = Item,
            .curr = currFn,
            .skip = skipFn,
        });
    };
}

/// # BidirectionIterable
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
///
pub fn BidirectionIterable(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.default(.Self, Contractor);
    const VarSelf: type = contract.getVarSelf();
    const Item = contract.require(.Item, type);
    const skipBack = contract.require(.skipBack, fn (VarSelf) void);
    const forwards_iterable = Iterable(Contractor, clauses);
    const backwards_iterable = Iterable(Contractor, .{
        .Self = Self,
        .mutation = contract.getMutation(),
        .Item = Item,
        .skip = skipBack,
        .curr = forwards_iterable.curr,
    });

    return struct {
        pub usingnamespace forwards_iterable;
        pub const prevTimes = backwards_iterable.nextTimes;
        pub const prev = backwards_iterable.next;
        pub const skipBackTimes = backwards_iterable.skipTimes;

        pub fn asBidirectionIterator(self: *Self) BidirectionIterator(Item) {
            return BidirectionIterator(Item){
                .ctx = self,
                .vtable = .{
                    .skip = &forwards_iterable.skip,
                    .curr = &forwards_iterable.curr,
                    .skipBack = &skipBack,
                },
            };
        }

        pub fn asBackwardsIterator(self: *Self) Iterator(Item) {
            return Backwards.asIterator(self);
        }

        pub const Backwards = BidirectionIterable(Contractor, .{
            .Self = Self,
            .mutation = contract.getMutation(),
            .Item = Item,
            .skip = backwards_iterable.skip,
            .skipBack = forwards_iterable.skip,
            .curr = forwards_iterable.curr,
        });
    };
}

/// TODO
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
            .mutation = contracts.Mutation.by_val,
            .Item = Item,
            .curr = currFn,
            .skip = skipFn,
            .skipBack = skipBackFn,
        });
    };
}

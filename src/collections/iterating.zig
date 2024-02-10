const std = @import("std");
const utils = @import("../utils.zig");
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
    const Self: type = contract.Self;
    const VarSelf: type = contract.VarSelf;
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

        pub fn filter(self: *Self, condition: *const fn (Item) bool) Filter(Item) {
            return Filter(Item){
                .iterator = asIterator(self),
                .condition = condition,
            };
        }

        pub fn reduce(self: *Self, operation: *const fn (Item, Item) Item) Reduce(Item) {
            return Reduce(Item){
                .iterator = asIterator(self),
                .operation = operation,
            };
        }

        pub fn map(
            self: *Self,
            comptime To: type,
            translator: *const fn (Item) To,
        ) Map(Item, To) {
            return Map(Item, To){
                .iterator = asIterator(self),
                .translator = translator,
            };
        }

        pub fn asIterator(self: *Self) Iterator(Item) {
            const Fn = struct {
                pub fn skipFn(context: *anyopaque) void {
                    const ctx: *Self = utils.cast(Self, context);
                    skip(contract.asVarSelf(ctx));
                }
                pub fn currFn(context: *anyopaque) ?Item {
                    const ctx: *Self = utils.cast(Self, context);
                    return curr(ctx.*);
                }
            };
            return Iterator(Item){
                .ctx = self,
                .vtable = .{
                    .skip = &Fn.skipFn,
                    .curr = &Fn.currFn,
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

pub fn Filter(comptime Item: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(Item),
        condition: *const fn (Item) bool,

        fn skipFn(self: Self) void {
            self.iterator.skip();
            while (self.iterator.curr()) |item| {
                if (self.condition(item)) break;
                self.iterator.skip();
            }
        }

        fn currFn(self: Self) ?Item {
            const item = self.iterator.curr() orelse return null;
            if (self.condition(item)) return item;
            skipFn(self);
            return self.iterator.curr();
        }

        pub usingnamespace Iterable(Self, .{
            .mutation = contracts.Mutation.by_val,
            .Item = Item,
            .skip = skipFn,
            .curr = currFn,
        });
    };
}

pub fn Map(comptime From: type, comptime To: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(From),
        translator: *const fn (From) To,

        fn skipFn(self: Self) void {
            self.iterator.skip();
        }

        fn currFn(self: Self) ?To {
            const item = self.iterator.curr() orelse return null;
            return self.translator(item);
        }

        pub usingnamespace Iterable(Self, .{
            .mutation = contracts.Mutation.by_val,
            .Item = To,
            .skip = skipFn,
            .curr = currFn,
        });
    };
}

pub fn Reduce(comptime Item: type) type {
    return struct {
        const Self = @This();

        iterator: Iterator(Item),
        current: ?Item,
        operation: *const fn (Item, Item) Item,

        fn currFn(self: Self) ?Item {
            return self.current;
        }

        fn skipFn(self: Self) void {
            const current_item = self.current orelse return;
            const next_item = self.iterator.next() orelse {
                self.current = null;
                return;
            };

            self.current = self.operation(current_item, next_item);
        }

        pub usingnamespace Iterable(Self, .{
            .mutation = contracts.Mutation.by_val,
            .Item = Item,
            .skip = skipFn,
            .curr = currFn,
        });

        pub fn eval(self: Self) ?Item {
            var result = self.curr() orelse return null;
            while (self.next()) |item| result = item;
            return result;
        }
    };
}

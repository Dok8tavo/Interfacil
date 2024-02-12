const std = @import("std");
const utils = @import("../utils.zig");
const contracts = @import("../contracts.zig");

/// # Iterable
///
/// The `Iterable` interface is the base of the collections interfaces. It allows the user to
/// iterate through the implementor, using a `next` function. It also lazily can be used as a map,
/// a filter, or a reducer.
///
/// ## Clauses
///
/// - `Self` is the type that will use the namespace returned by the interface. It shouldn't be a
/// pointer. By default `Self` is the contractor.
/// - `mutation` determine whether `VarSelf` is `*Self` or `Self`. By default `mutation` is
/// `by_ref`.
/// - `Item` is the return type of the items the iterator will return, it's required.
/// - `curr: fn (Self) ?Item` is a function that returns the current item, it doesn't consume it
/// nor should it mutate the iterable. It returns null when the iterable has been consumed.
/// - `skip: fn (VarSelf) void` is a function that modify the iterable so that the `curr` function
/// will return the next item.
///
/// ## Declarations
///
/// 1. the current function `curr: fn (Self) ?Item`,
/// 2. the filter function `filter: fn (*Self, *const fn (Item) bool) Filter(Item)`,
/// 2. the map function `map: fn (*Self, To, *const fn (Item) To) Map(Item, To)`,
/// 2. the next function `next: fn (VarSelf) ?Item`:
///     - the multiple nexts function `nextTimes: fn (VarSelf, usize) ?Item`,
/// 3. the reduce function `reduce: fn (*Self, *const fn (Item, Item) Item) Reduce(Item)`,
/// 3. the skip function `skip: fn (VarSelf) void`:
///     - the multiple skips function `skipTimes: fn (VarSelf, usize) void`,
/// 4. the iterator function `asIterator: fn (*Self) Iterator(Item)`.
///
/// ### The current function `curr: fn (Self) ?Item`
///
/// This function returns the iterable currently "points" to. It's taken right from the clauses.
///
/// #### Usage
///
/// When an iterable is created, it should points to the first element:
///
/// ```zig
/// const string = "Hello world!";
/// var iteratable = StringIterable.from(string);
/// assert(iterable.curr().? == 'H');
/// ...
/// ```
///
/// Once the `next`, `nextTimes`, `skip` or `skipTimes` function has been used, it should points to
/// other elements:
///
/// ```zig
/// ...
/// const e = iterable.next();
/// assert(iterable.curr().? == e);
/// iterable.skip();
/// assert(iterable.curr().? == 'l');
/// iterable.skipTimes(2);
/// assert(iterable.curr().? == 'o');
/// const w = iterable.nextTimes(2);
/// assert(iterable.curr().? == w);
/// ```
///
/// Note that whenever `curr` is used right after `next` or `nextTimes`, their results are the
/// equal to one another.
///
/// ### The skip function `skip: fn (self: VarSelf) void`
///
/// This function modifiy the state of the iterable so that it points to the very next item. If
/// there's no next item, it'll point to null. If there's not even a current item, it won't do
/// anything. It is equivalent to ignoring the result of the `next` function.
///
/// #### Usage
///
/// ```zig
/// const array = [_]Enum{v1, v2, v3};
/// var iterable = ArrayIterable(Enum).from(array);
/// iterable.skip();
/// assert(iterable.curr().? == v2);
/// iterable.skip();
/// assert(iterable.curr().? == v3);
/// iterable.skip();
/// assert(iterable.curr() == null);
/// iterable.skip();
/// assert(iterable.curr() == null);
/// ```
///
/// #### The multiple skip function `skipTimes: fn (self: VarSelf, times: usize) void`
///
/// This function uses `skip` the given number of times, or until the `curr` function returns
/// `null`.
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
    const skipClause = contract.require(.skip, fn (VarSelf) void);
    return struct {
        /// This function returns the iterable currently "points" to.
        pub const curr = contract.require(.curr, fn (Self) ?Item);

        /// TODO
        pub fn next(self: VarSelf) ?Item {
            if (curr(contract.asSelf(self))) |item| {
                defer skip(self);
                return item;
            } else return null;
        }

        /// TODO
        pub fn nextTimes(self: VarSelf, times: usize) ?Item {
            skipTimes(self, times);
            return curr(self);
        }

        /// This function modifiy the state of the iterable so that it points to the very next
        /// item. If there's no next item, it'll point to `null`. If there's not even a current
        /// item, it won't do anything. It is equivalent to ignoring the result of the `next`
        /// function.
        pub fn skip(self: VarSelf) void {
            if (curr(self)) |_| skipClause(self);
        }

        /// This function uses `skip` the given number of times, or until the `curr` function
        /// returns `null`.
        pub fn skipTimes(self: VarSelf, times: usize) void {
            for (0..times) |_| if (next(self) == null) return null;
        }

        /// TODO
        pub fn filter(self: *Self, condition: *const fn (Item) bool) Filter(Item) {
            return Filter(Item){
                .iterator = asIterator(self),
                .condition = condition,
            };
        }

        /// TODO
        pub fn reduce(self: *Self, operation: *const fn (Item, Item) Item) Reduce(Item) {
            return Reduce(Item){
                .iterator = asIterator(self),
                .operation = operation,
            };
        }

        /// TODO
        pub fn map(
            self: *Self,
            comptime To: type,
            mapper: *const fn (Item) To,
        ) Map(Item, To) {
            return Map(Item, To){
                .iterator = asIterator(self),
                .translator = mapper,
            };
        }

        /// TODO
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

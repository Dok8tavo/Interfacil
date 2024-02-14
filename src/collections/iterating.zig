const std = @import("std");
const utils = @import("../utils.zig");
const contracts = @import("../contracts.zig");
const comparison = @import("../comparison.zig");

/// # Iterable
///
/// The `Iterable` interface is the base of the collections interfaces. It allows the user to
/// iterate through the implementor, using a `next` function. It also lazily can be used as a map,
/// a filter, or a reducer.
///
/// ## Clauses
///
/// - `Self` is the type that will use the namespace returned by the interface. By default `Self`
/// is the contractor.
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
/// 2. the next function `next: fn (VarSelf) ?Item`,
/// 3. the reduce function `reduce: fn (*Self, *const fn (Item, Item) Item) Reduce(Item)`,
/// 3. the skip function `skip: fn (VarSelf) void`,
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
/// iterable.skip();
/// iterable.skip();
/// assert(iterable.curr().? == 'o');
/// iterable.next();
/// assert(iterable.curr().? == w);
/// ```
///
/// Note that whenever `curr` is used right before `next`, their results are equal to
/// one another.
///
/// ### The next function `next: fn (self: VarSelf) ?Item`
///
/// This function returns the current item then skip. If there's no current item, it only returns
/// `null`.
///
/// #### Usage
///
/// ```zig
/// var iterable = ...;
/// while (iterable.next()) |item| {
///     // do smth with the item
/// }
/// // now the iterable has been consumed
/// ```
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
/// ### The filter function: `filter: fn (self: *Self, condition: fn (Item) bool) Filter(Item)`
///
/// This function's return will iterate through the items of `self`, skipping those that
/// don't fulfill the `condition` parameter. Calling the `condition` on any item of the
/// `filter`s result is guaranteed to return `true`. If the iterable represents a sequence,
/// then the `filter`s result is a subsequence.
///
/// #### Usage
///
/// Discards invalid items.
///
/// ```zig
/// var iterable = ...;
/// const items = iterable.filter(isValid);
/// while (items) |valid_item| {
///     // it's guaranteed that the `valid_item` passed to `isValid` returned `true`.
///     ...
/// }
/// ```
///
/// ### The mapping function: `map: fn (self: *Self, comptime To: type, mapper: fn (Item) To) Map(Item, To)`
///
/// This function returns an iterable that will pass its items through the mapper before
/// returning them.
///
/// #### Usage
///
/// ```zig
/// const numbers_as_strings = ...;
/// var iterable = from(numbers_as_strings);
/// const numbers = iterable.map(ParseIntError!usize, parseInt(usize)).filter(noError);
/// while (numbers) |number| {
///     // number is a `usize`, strings that couldn't be parsed were discarded.
///     ...
/// }
/// ```
///
/// ### The reduce function: `reduce: fn (self: *Self, operation: fn (Item, Item) Item) Reduce(Item)`
///
/// This function's return will iterate through the partial of `self`. Which means it'll
/// apply the operation on the preceding item and the current item before returning.
///
/// #### Usage
///
/// ```zig
/// var iterable = sequence(.{0, 1, 2, 3, 4});
/// const reduced_iterable = iterable.reduce(sum);
/// assert(reduced_iterable.next().? == 0);
/// // the `sum` of 0 and 1
/// assert(reduced_iterable.next().? == 1);
/// // the `sum` of 0 and 1, and then 2
/// assert(reduced_iterable.next().? == 3);
/// // the `sum` of 0 and 1, and then 2, and then 3
/// assert(reduced_iterable.next().? == 6);
/// // the `sum` of 0 and 1, and then 2, and then 3, and then 4,
/// assert(reduced_iterable.next().? == 10);
/// assert(reduced_iterable.next() == null);
/// ```
///
/// ### The interfacing function: `asIterator: fn (self: *Self) Iterator(Item)`
///
/// This function returns a dynamic interface for iterating through `self`. It's type
/// agnostic of `self`, so you can pass it to precompiled functions, no need to use
/// `anytype`.
///
/// ## Testing
///
/// TODO
///
pub fn Iterable(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    return struct {
        const Self: type = contract.Self;
        const VarSelf: type = contract.VarSelf;
        const Item: type = contract.require(.Item, type);
        const skipClause = contract.require(.skip, fn (VarSelf) void);
        const currClause = contract.require(.curr, fn (Self) ?Item);

        /// This function returns the iterable currently "points" to.
        pub fn curr(self: Self) ?Item {
            return currClause(self);
        }

        /// This function returns the current item then skip. If there's no current item, it only
        /// returns `null`.
        pub fn next(self: VarSelf) ?Item {
            if (curr(contract.asSelf(self))) |item| {
                defer skip(self);
                return item;
            } else return null;
        }

        /// This function modifiy the state of the iterable so that it points to the very next
        /// item. If there's no next item, it'll point to `null`. If there's not even a current
        /// item, it won't do anything. It is equivalent to ignoring the result of the `next`
        /// function.
        pub fn skip(self: VarSelf) void {
            if (curr(contract.asSelf(self))) |_| skipClause(self);
        }

        /// This function's return will iterate through the items of `self`, skipping those that
        /// don't fulfill the `condition` parameter. Calling the `condition` on any item of the
        /// `filter`s result is guaranteed to return `true`. If the iterable represents a sequence,
        /// then the `filter`s result is a subsequence.
        pub fn filter(self: *Self, condition: *const fn (Item) bool) Filter(Item) {
            return Filter(Item){
                .iterator = asIterator(self),
                .condition = condition,
            };
        }

        /// This function's return will iterate through the partial of `self`. Which means it'll
        /// apply the operation on the preceding item and the current item before returning.
        pub fn reduce(self: *Self, operation: *const fn (Item, Item) Item) Reduce(Item) {
            return Reduce(Item){
                .iterator = asIterator(self),
                .operation = operation,
            };
        }

        /// This function returns an iterable that will pass its items through the mapper before
        /// returning them.
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

        /// This function returns a dynamic interface for iterating through `self`. It's type
        /// agnostic of `self`, so you can pass it to precompiled functions, no need to use
        /// `anytype`.
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

        pub const iterable_testing = struct {
            pub const sample = contract.sample;
            pub const expect = switch (sample.len) {
                0 => .{},
                else => contract.require(.expect, [sample.len][]const Item),
            };

            const equality = comparison.Equivalent(Contractor, .{
                .Self = Item,
                .eq = contract.default(.equals, comparison.equalsFn(Item)),
                .sample = sample: {
                    var concat: []const Item = &.{};
                    for (sample) |items| {
                        concat = concat ++ items;
                    }

                    break :sample concat;
                },
            });

            /// TODO: use `Result` for better detailed errors
            pub fn isSliceIsomorphic(self: VarSelf, slice: []const Item) bool {
                return for (slice) |item| {
                    const curr_item = curr(self) orelse break false;
                    const next_item = next(self) orelse break false;
                    if (!equality.eq(curr_item, next_item)) break false;
                    if (!equality.eq(curr_item, item)) break false;
                } else true;
            }

            test "Iterable: Items equality" {
                _ = equality;
            }

            test "Iterable: isSliceIsomorphic" {
                for (sample, expect) |a, b| {
                    try std.testing.expect(isSliceIsomorphic(a, b));
                }
            }
        };
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

const std = @import("std");
const misc = @import("../misc.zig");
const contracts = @import("../contracts.zig");
const indexing = @import("indexing.zig");

pub fn Sliceable(comptime Contractor: type, comptime clauses: anytype) type {
    const contract = contracts.Contract(Contractor, clauses);
    const Self: type = contract.default(.Self, Contractor);
    const mut_by_value: bool = contract.default(.mut_by_value, false);
    const VarSelf: type = if (mut_by_value) Self else *Self;
    const Item = contract.require(.Item, type);
    const sliceFn = contract.require(.sliceFn, fn (
        self: Self,
        start: usize,
        length: usize,
    ) []const Item);
    const max_usize = std.math.maxInt(usize);
    return struct {
        pub fn getAllSlice(self: Self) []const Item {
            return sliceFn(self, 0, max_usize);
        }

        pub fn getAllVarSlice(self: VarSelf) []Item {
            return @constCast(getAllSlice(self));
        }

        pub fn asVarSlice(self: VarSelf) []Item {
            return @constCast(getAllSlice(asValue(self)));
        }

        pub fn getLength(self: Self) usize {
            return getAllSlice(self).len;
        }

        pub fn getSliced(self: Self, start: ?usize, length: ?usize) []const Item {
            const s = start orelse 0;
            const l = length orelse max_usize;
            return sliceFn(self, s, l);
        }

        pub fn getVarSliced(self: VarSelf, start: ?usize, length: ?usize) []Item {
            return @constCast(getSliced(asValue(self), start, length));
        }

        pub fn getRanged(self: Self, start: ?usize, end: ?usize) []const Item {
            const s = start orelse 0;
            const e = end orelse getLength(self);
            return sliceFn(self, s, e - s);
        }

        pub fn getVarRanged(self: VarSelf, start: ?usize, end: ?usize) []Item {
            const s = start orelse 0;
            const e = end orelse getLength(asValue(self));
            return getVarSliced(self, start, e - s);
        }

        pub fn getRangedTrunc(self: Self, start: ?usize, end: ?usize) []const Item {
            const s = start orelse 0;
            const e = end orelse getLength(self);
            return sliceFn(self, s, e -| s);
        }

        pub fn getVarRangedTrunc(self: VarSelf, start: ?usize, end: ?usize) []Item {
            const s = start orelse 0;
            const e = end orelse getLength(asValue(self));
            return getVarSliced(self, s, e -| s);
        }

        pub fn getRangedWrapped(self: Self, start: ?usize, end: ?usize) []const Item {
            const s = start orelse 0;
            const e = end orelse getLength(self);
            return sliceFn(self, @min(s, e), @max(s, e) - @min(s, e));
        }

        pub usingnamespace indexing.Indexable(Contractor, .{
            .Self = Self,
            .mut_by_value = mut_by_value,
            .Item = Item,
            .get = getItemWrapper,
            .set = setItemWrapper,
        });

        pub fn asSlicer(self: Self) Slicer(Item) {
            return Slicer(Item){
                .context = &self,
                .vtable = .{
                    .slice = &sliceFn,
                },
            };
        }

        fn getItemWrapper(self: Self, index: usize) ?Item {
            const s = getSliced(self, index, 1) orelse return null;
            return s[0];
        }

        fn setItemWrapper(self: VarSelf, index: usize, value: Item) void {
            const s = getVarSliced(self, index, 1);
            s[0] = value;
        }

        fn asValue(self: VarSelf) Self {
            return if (mut_by_value) self else self.*;
        }
    };
}

pub fn Slicer(comptime Item: type) type {
    return struct {
        const Self = @This();

        context: *anyopaque,
        vtable: struct {
            slice: *const fn (*anyopaque, usize, usize) []const Item,
        },

        fn sliceWrapper(self: Self, start: usize, length: usize) []const Item {
            return self.vtable.slice(self.context, start, length);
        }

        pub usingnamespace Sliceable(Self, .{
            .mut_by_value = true,
            .Item = Item,
            .sliceFn = sliceWrapper,
        });
    };
}

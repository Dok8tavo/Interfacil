# Interfacil

Interfacil is a Zig package for making and using interfaces easily in Zig.

[You can find guides here.](src/guides)

Here are a few projects with similar purpose:

- [zig_interfaces by yglcode](https://github.com/yglcode/zig_interfaces),
- [zimpl by permutationlock](https://github.com/permutationlock/zimpl),
- [zig-interface by bluesillybeard](https://github.com/bluesillybeard/zig-interface),

ZLS works well enough with `interfacil`, it can figure out the declarations and their docs. Unfortunatly, as of today, it still doesn't do well with return types as those are generics and go through a little bit of comptime computation. You might need to use a few type annotations here and there to get it working properly.

## Static interfaces

Interfacil's static interfaces designate a consistent set of declarations that a type must provide. One could also call them "mixin"s as they effectively extends the set of declerations available from the type. However, they still must be declared from within the type, they can't be declared afterwards. Here's how one could implement a static interface:

```zig
const MyIterableType = struct {
    // this is just an example of fields, this could be anything really
    field: MyField,
    index: usize = 0,

    // Here's the fun part: the interface `Iterable` is a function that generates a namespace in
    // your stead, by passing the type and the necessary declarations. And makes it available from
    // the type with the help of `usingnamespace`.
    pub usingnamespace Iterable(MyIterableType, struct {
        pub const Item = MyItem;
        pub fn next(self: *MyIterableType) ?Item {
            if (self.field.len <= self.index) return null;
            defer self.index += 1;
            return self.field.getMyItem(self.index);
        }
    // There's a defined set of options, that can come handy when implementing a static interface.
    }, .{});
};

fn someFunction() void {
    ...
    // Now you can use the `next` function you've defined from your type
    const my_item = my_iterable.next() orelse return;
    ...
    // But you can also filter them
    var filtered = my_iterable.filter(isValidMyItem);
    const next_valid_item = filtered.next() orelse return;
    ...
    // Or map them to another type
    var mapped = my_iterable.map(myOtherItemFromMyItem);
    const my_other_item = mapped.next() orelse return;
    ...
    // Or both
    var mapped_and_filtered = filtered.map(myOtherItemFromMyItem);
    const my_other_item_from_my_valid_item = mapped_and_filtered.next() orelse return;
    ...
    // You can also reduce them
    var reduced = my_iterable.reduce(sumMyItems);
    const sum = reduced.next() orelse return;
    const sum_plus_one = reduced.next() orelse return;
    const sum_plus_two = reduced.next() orelse return;
    ...
}
```

## Dynamic interfaces

Dynamic interfaces bundle a type-erased pointer to a type implementing the equivalent static interface, with a corresponding virtual table, a set of function pointers that are used internally. They're a simple type.

## Quick Overview

For now, the main implementations of interfaces are those related to [iterators](https://github.com/Dok8tavo/Interfacil/blob/0.2.0/src/iteration.zig):

### `Iteratable`

An iteratable type is a type with a `next` function that returns an optional item (`null` is when it has reached its end, when it has been consumed entirely).

Iterable types can be abstracted into an `Iterator` allowing to make a ton of things in a type independent way.

Iterable types also automatically provide the `reduce`, `filter` and `map` higher order functions.

### `Peekable`

A peekeable type is a type that inherit from an iterable, meaning that it can absolutly be used exactly like an iterable. But it also has a `peek` function that basically does the same as `next` but without consuming the item, and without needing a mutable reference to self.

### `SlicePeeker`

A `SlicePeeker` is a peekable type that return sub-slices of a given slice. One can also use the `asItemPeeker` in order to iterate over the items instead of the sub-slices.

### `MultIterator`, `MultPeeker`

The `MultIterator` is an iterable type that chains multiple iterators together. The `MultPeeker` obviously does the same, but as a peekable type, for peekers instead.

### No allocations

Iteration is completly independent of any kind of memory allocation that could happen under the hood. If your iterable requires allocation or another operation that could fail, you can define an appropriate error union as the returned items.

```zig
const MyIterable = struct {
    ...

    // check whether an error occurs during the iteration
    pub fn noErrors(self: *MyIterable) bool {
        return while (self.next()) |item| {
            const actual_item = item catch break false;
            _ = actual_item;
        } else true;
    }

    pub usingnamespace Iterable(MyIterable, struct {
        pub const Item = error{OutOfMemory}!ActualItem;
        pub fn next(self: *MyIterable) ?Item {
            ...
        }
    }, .{});
}


```

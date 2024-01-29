# How to use an interface

Interfaces are functions with the `fn (comptime Contractor: type, comptime clauses: anytype) type` signature. They're quite easy to use.

## Interfaces as namespaces

An interface returns a namespace (a type with only declarations, no members). So you can use it like a namespace. This is a naked interface. Let's take the `Equivalent` interface that provides the `eq` function with the following prototype: `fn (self: Self, other: Self)`.

```zig
const naked = interfacil.Equivalent(u32, .{});
comptime {
    assert(!naked.eq(0, 8));
    assert(naked.eq(8, 8));
    const unsigned: u32 = 4;
    assert(naked.eq(4, 8));
    ...
}
```

It automatically generated a function that returns `true` in case of equality, and `false` otherwise. It can do so for many types: all integers, floats, booleans, as well as enums, errors, arrays, single pointers, slices, structs, tagged unions, etc. But this is not all:

```zig
...
comptime {
    ...
    const slice_of_u32: []const u32 = &[_]u32{0, 1, 2, 3, 4};
    assert(!naked.anyEq(5, slice_of_u32));
    assert(naked.anyEq(3, slice_of_u32));
    ...
}
```

It also generated a function named `anyEq` that checks if there's an item in `slice_of_u32` that's equivalent to its first parameter. Interfaces contains multiple useful related declarations.

## Interfaces as type extensions

Naked interfaces can be funny and practical, but the real thing is using them as type extensions.

If you don't know about the `usingnamespace` keyword, it's a keyword that allows you to redeclare every declaration of a type, inside another type. For example:

```zig
const SomeType = struct {
    pub const declaration = "This is a declaration";
};

const SomeOtherType = struct {
    // now `SomeOtherType.declaration` is possible, and its the same as `SomeType.declaration`.
    pub usingnamespace SomeType;
};
```

Since interfaces return namespaces you can use this trick:

```zig
const Vector2D = struct {
    x: i32,
    y: i32,

    pub usingnamespace interfacil.Equivalent(Vector2D, .{});
}
...
```

And now every declaration we've seen before for `u32` are available for `Vector2D` and __from__ `Vector2D`! This means that Zig now allows the method syntax:

```zig
...
comptime {
    const v1 = Vector2D{ .x = 0, .y = 0 };
    const v2 = Vector2D{ .x = -1, .y = 1 };
    const v3 = v1;
    // `v1.eq(v2)` is effectively the same as `@TypeOf(v1).eq(v1, v2)`, so `Vector2D.eq(v1, v2)`
    assert(!v1.eq(v2));
    assert(!v2.eq(v3));
    assert(v3.eq(v1));
}
```

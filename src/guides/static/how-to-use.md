# How to use a static interface

Static interfaces are `fn (comptime Contractor, comptime clauses: anytype) type` functions. They return a namespace containing the declarations you want to use. Most interfaces should be used like this:

```zig
const MyType = struct {
    field: Field,
    ...

    const declaration = my_declaration;
    ...

    pub usingnamespace Interface(MyType, .{
        .some_clause = declaration,
        ...
    });
};
```

A static interface is used from a container type, a type that's also a namespace. Either a `struct` (the most common), an `enum`, a `union` or an `opaque` (the least common). Here `MyType` is the container type.

In this example, `MyType` is also the `Contractor` of the interface, i.e. the type that's passed as a first argument. The contractor is considered responsible for providing the `clauses`. If something goes wrong, a compile error will mention that this type doesn't provide the clauses correctly. It does not mean that the clauses must actually be from its namespace, even if it makes sense most of the time. 

The second parameter of the interface is passed a struct literal. The fields of this struct are called "clauses", some of them are mandatory sometimes, others aren't. They define how the interface will implement the namespace.

## A few common clauses

### `.Self`

The self clause is defaulted to the contractor of the interface. You should only override it when the contractor and the type on which the interface is implemented are different.

### `.mutation`

The mutation clause is either `.by_ref` or `.by_val`. Some types can be mutated from their value, because they don't hold their data, but a reference to it instead. In this case, you should set the mutation clause to `.by_val`. Then even when a method asks for a `VarSelf` parameter, it's actually just `Self`. Otherwise, you can just leave it and `VarSelf` will be `*Self`.

The mutation clause is a `interfacil.contracts.Mutation` instance, but it's implementation is made so that passing an enum literal will work just the same.

### `.sample`

In order to make meaningful tests available from the returned namespace, you must provide a sample of valid instances of your type. The sample clause takes a const slice to these instances and apply the tests on each of them, or their subsets.

Another reason why you could want to give a sample clause is because there are some edge cases that might not respect some invariants.

### `.Item`

The collection interfaces of `interfacil` takes a mandatory item clause to determine the type of their content. Other collections should also ask for an item clause, except when there's a well established other name for it, like "key" and "value" for hashable interface.

### A few functions

Interfaces are typically a set of utils that rely just on two or three basic functions. Like the `Readable` and the `Writeable` that are entirely build on `read` and `write` functions. The `Allocating` is based on the `alloc`, `resize` and `free` functions.

These functions are typically wrappers around the vtable of the corresponding dynamic interface.

## Path Access

Interfaces return namespaces. Those namespaces can be accessed in different manners. Let's use the `interfacil.comparison.Equivalent` interface to demonstrate these.

### Short path access (SPA)

The short path access is the prefered way to use a static interface. It makes use of the `usingnamespace` keyword. You can then use the method syntax to call some functions:

```zig
const Vec2 = struct {
    x: i32,
    y: i32,

    pub  usingnamespace Equivalent(Vec2, .{});
};

test {
    const v1 = Vec2{ .x = -9, .y = 10 };
    const v2 = Vec2{ .x = -9, .y = -1 };

    // the `eq` method was in the namespace returned by `Equivalent`.
    try expect(v1.eq(v1));
    try expect(!v1.eq(v2));
    try expect(v2.eq(v2));
    try expect(!v2.eq(v1));
}
```

### Full path access (FPA)

The short path access isn't always possible, because namespaces can be in conflict:

```zig
const String = struct {
    buf: [32]u8,

    // This makes a few declarations available, and one in particular: the `eq` function
    pub usingnamespace Equivalent(String, .{});
    
    // This badly named function checks if all bytes in the buffer are the same.
    pub fn eq(self: String) bool {
        return inline for (self.buf.len - 1) |i| {
            if (self.buf[i] != self.buf[i + 1]) 
                break false;
        } else true;
    }
};

test {
    const string = String{
        .buf = .{0} ** 32,
    };

    // here, even though it seems clear which function we're using since there's only one argument,
    // Zig doesn't want to figure it out. It results in a compilation error.
    expect(string.eq());
}
```

The solution is to use the namespace as a declaration instead of `usingnamespace`.

```zig
const String = struct {
    buf: [32]u8,

    pub const equality = Equivalent(String, .{});
    
    pub fn eq(self: String) bool {
        return inline for (self.buf.len - 1) |i| {
            if (self.buf[i] != self.buf[i + 1]) 
                break false;
        } else true;
    }
};

test {
    const string = String{
        .buf = .{0} ** 32,
    };

    // here, there's no other `eq` function accessible this way.
    try expect(string.eq());

    // we call the other `eq` function like this:
    try expect(String.equality.eq(string, string));
}
``` 

### Mixed path access (MPA)

```zig
const String = struct {
    bytes: []const u8,

    fn isEqual(self: String, other: String) bool {
        if (self.len != other.len) return false;
        return for (self.bytes, other.bytes) |s, o| {
            if (s != o) break false;
        } else true;
    }

    fn hasSameLength(self: String, other: String) bool {
        return self.len == other.len;
    }

    // instead of using the default `eq` function, which doesn't work on slices, we're using our 
    // own implementation.
    pub usingnamespace Equivalent(String, .{ .eq = isEqual });

    // Here we can't use it in the same namespace.
    pub const len_equality = Equivalent(String, .{ .eq = hasSameLength });
};

test {
    const hello = String{ .bytes = "Hello" };
    const world = String{ .bytes = "world" };

    // those two strings aren't the same
    expect(!hello.eq(world)); 

    // but they're length-equal
    expect(String.len_eq(hello, world));
}
```

## Testing

One big advantage of static interfaces is that some unit tests are already written. You only need to give them a sample on which they will run.

In order to automatically use the unit tests, you should pass the `.sample` clause to the interface. It must be a const slice of `Self`.

```zig
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn from(r: u8, g: u8, b: u8) Color {
        return .{
            .r = r,
            .g = g,
            .b = b,
        };
    }

    pub const black = from(0, 0, 0);
    pub const red = from(255, 0, 0);
    pub const green = from(0, 255, 0);
    pub const yellow = from(255, 255, 0);
    pub const blue = from(0, 0, 255);
    pub const violet = from(255, 0, 255);
    pub const cyan = from(0, 255, 255);
    pub const white = from(255, 255, 255);

    fn hasSameRed(self: Color, other: Color) bool {
        return self.r == other.r;
    }

    pub const redeq = Equivalent(Color, .{
        .eq = hasSameRed,
        .sample = utils.slice(Color, .{
            black, red,          
            green, yellow,
            blue,  violet,
            cyan,  white,
        }),
    });
};

test {
    // the `testing_equivalency` namespace was in the namespace returned by `Equivalent`
    _ = Color.testing_equivalency;
}
```

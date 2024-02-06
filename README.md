# Interfacil

Interfacil is a Zig package for making and using interfaces easily in Zig.

[You can find guides here.](src/guides)

Here are a few projects with similar purpose:

- [zig_interfaces by yglcode](https://github.com/yglcode/zig_interfaces),
- [zimpl by permutationlock](https://github.com/permutationlock/zimpl),
- [zig-interface by bluesillybeard](https://github.com/bluesillybeard/zig-interface),

These interfaces work well with zls, you can see their type (though sometimes a type annotation 
makes it better), and their doc comments. Props to the zls people!

## Currently implemented in Interfacil

- [`Allocating`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/mem.zig#L4C1-L425C2) and [`Allocator`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/mem.zig#L428C1-L472C3) (for showcasing, do not use),
- [`BidirectionIterable`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/iteration.zig#L67C1-L114C2) and [`BidirectionIterator`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/iteration.zig#L116C1-L147C2),
- [`Equivalent`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/comparison/equivalent.zig#L85C1-L414C2),
- [`Iterable`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/iteration.zig#L3C1-L38C2) and [`Iterator`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/iteration.zig#L40C1-L65C2),
- [`Ordered`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/comparison/ordered.zig#L19C1-L98C2),
- [`PartialEquivalent`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/comparison/equivalent.zig#L560C1-L766C2),
- [`PartialOrdered`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/comparison/ordered.zig#L144C1-L177C2),
- [`Readable`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/io.zig#L9C1-L306C2) and [`Reader`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/io.zig#L308C1-L319C3),
- [`SliceIterator`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/iteration.zig#L149C1-L174C2),
- [`Writeable`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/io.zig#L322C1-L390C2) and [`Writer`](https://github.com/Dok8tavo/Interfacil/blob/2f73d24eadc19821d77566744984a1e7ee060558/src/io.zig#L392C1-L406C3),

## How to use static interfaces

```zig
// The accessor is the type from which you can access the interface's return.
const Accessor = struct {
    ...

    // The following line declares a set of declarations that'll be useable from the Accessor.
    pub usingnamespace interfacil.Interface(
        // The contractor is the type that must fill the interface's `contract`. This is useful for
        // meaningful compile error messages! In practice, it's almost always the Accessor.
        Contractor,
        // The clauses of the interface's contract are filled by passing an anonymous struct as the
        // second parameter. Most interfaces require at least one clause because there's no clear
        // default from just knowing the contractor.
        .{ .clause = some_value },
    );
};

// Now, from the accessor, you can use the declarations of the namespace returned by the interface.
const zero = Accessor.zero;
const one = Accessor.one;
const two = Accessor.add(zero, one);

// If the contractor and the accessor are the same type, you can even use the method syntax.
const three= two.add(one);
```

## How to make static interfaces

```zig
pub fn MyInterface(comptime Contractor: type, comptime clauses: anytype) type {
    return struct {
        // The contract will make sure the passed clauses are valid.
        const contract = interfacil.Contract(Contractor, clauses);

        // You can now require a clause from the contractor by using the contract.
        const required = contract.require(
            // This is the name of the field where the contract should look for the clause.
            .clause_name,
            // This is the type of the field ...
            SomeType,
        );

        // You can also use a default.
        const has_clause = contract.default(
            // Usually, it's better to use the same name for both the clause and the declaration.
            .has_clause,
            // The contract will infer what should be the type of the clause.
            false,
        );

        // All the public declarations are those the accessor will have access to.
        pub const pi = 3.14159;

        // You can make it so that the result depends on a clause.
        pub const message = if (has_clause) "I love you!" else "You piece of crap!";

        // You can define new functions, or methods, or anything really.
        pub fn method(self: *Contractor) void {
            ...
        }

        // You can also use other interfaces for better composition.
        pub usingnamespace interfacil.OtherInterface(Contractor, clauses);
    };
}
```

## How to use dynamic interfaces

If you don't really know what kind of `Iterable` will be passed to your function, and you can't really use `anytype` (or don't want to), you can just pass an `Iterator(Item)` instead. Here you go:

```zig
fn someFunction(iterable: anytype) void {
    // here there can be no autocompletion from zls, because the type of `iterable` will be 
    // resolved at each call of `someFunction`.
    ...
}

// becomes:
fn someFunction(iterator: Iterator(Item)) void {
    // here there can be autocompletion from zls, because it's smart enough to figure what methods
    // will have a type resulting from `Iterator`
    ...
}

// and at call site:
someFunction(iterable);

// becomes:
someFunction(iterable.asIterator());
```

If the static interface has an `asDynamic` method, it's the easiest thing in the world to use dynamic interfaces.


## How to make dynamic interfaces

We already have dynamic interfaces at home, the [`std.mem.Allocator`](https://github.com/ziglang/zig/blob/master/lib/std/mem/Allocator.zig) is the perfect example. They hold a pointer to something, and a virtual table (a bunch of pointers to functions):

```zig
ptr: *anyopaque,
vtable: struct {
    alloc: *const fn (
        ctx: *anyopaque,
        len: usize,
        ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8,

    resize: *const fn (
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool,

    free: *const fn (
        ctx: *anyopaque,
        buf: []u8, buf_align: u8,
        ret_addr: usize,
    ) void,
},
```

And then there's a bunch of functions that internally use the vtable and the pointer. 

Now, dynamic interfaces in Interfacil aren't much different. What's different is that you can use static interfaces to define them, take a look at the [`Reader`](https://github.com/Dok8tavo/Interfacil/blob/main/src/io.zig) interface:

```zig
pub const Reader = struct {
    ctx: *anyopaque,
    vtable: struct {
        read: *const fn (self: *anyopaque, buffer: []u8) anyerror!usize,
    },

    fn readFn(self: Reader, buffer: []u8) anyerror!usize {
        return self.vtable(self.ctx, buffer);
    }

    pub usingnamespace Readable(Reader, .{ .read = readFn, .Self = Reader });
};
```

And this is all there is to it! You just need to write wrappers around the vtable's functions, and pass them to the static interface that'll define all the methods for you! And since composing static interfaces is the easiest thing in the world, it's also quite easy to compose dynamic ones:

```zig
const ReaderAndWriter = struct {
    ctx: *anyopaque,
    vtable: struct {
        read: *const fn (self: *anyopaque, buffer: []u8) anyerror!usize,
        write: *const fn (self: *anyopaque, bytes: []const u8) anyerror!usize,
    }

    fn readFn(self: ReaderAndWriter, buffer: []u8) anyerror!usize {
        return self.vtable(self.ctx, buffer);
    }

    fn writeFn(self: ReaderAndWriter, bytes: []const u8) anyerror!usize {
        return self.vtable(self.ctx, bytes);
    }

    // Boom! Composition!
    pub usingnamespace Readable(ReaderAndWriter, .{ .read = readFn, .Self = ReaderAndWriter });
    pub usingnamespace Writeable(ReaderAndWriter, .{ .read = readFn, .Self = ReaderAndWriter });
}
```

If you got access to the corresponding static interface, you should also add a `asDynamic` method to it. This way, any function that takes in the dynamic interface can be called and be passed a `with_static.asDynamic()` argument. For example, the `Readable` interface has a `fn asReader(self: *Self) Reader` method. The `Writeable` interface has a `fn asWriter(self: *Self) Writer` method. The `Allocating` has a `fn asAllocator(self: *Self) Allocator` method, and so on.

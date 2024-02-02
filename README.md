# Interfacil

Interfacil is a Zig package for making and using interfaces easily in Zig.

[You can find guides here.](src/guides)

Disclaimer: These are static interfaces using `comptime`. This is not about dynamic polymorphism,
or inheritance, there's no dynamic dispatch happening here. If you want runtime interfaces check
these repos:

- [zig_interfaces by yglcode](https://github.com/yglcode/zig_interfaces),
- [zimpl by permutationlock](https://github.com/permutationlock/zimpl) has both static and dynamic dispatch,
- [zig-interface by bluesillybeard](https://github.com/bluesillybeard/zig-interface),

This is more in response of [this issue](https://github.com/ziglang/zig/issues/1268).

These interfaces work well with zls, you can see their type (though sometimes a type annotation 
makes it better), and their doc comments. Props to the zls people!

## How to use interfaces

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

## How to make interfaces

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

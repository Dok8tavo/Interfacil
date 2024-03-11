
# Glossary

## API (Application Programming Interface)

In the context of `interfacil`, an _api_ refers to all the public _declarations_ of the _namespace_ that's returned by an _interface_. The "interface" in "Application Programming Interface" doesn't refers to `interfacil`'s _interfaces_!

## Clause

The _clauses_ of a _contract_ are the different parts of a _contract_ that are passed to an _interface_ through its `Provider` type parameter. They are often directly or indirectly assigned to the _declarations_ within the _namespace_ that the _interface_ returns.

_Clauses_ can be required, when they're "declared" in the _contract_ by calling the `Contract(...).require` function,  or defaulted, when they're "declared" in the _contract_ by calling the `Contract(...).default` function.

## Contract

A _contract_ is the result of a `Contract(comptime Contractor: type, comptime Provider: type,comptime options: Options(Contractor)) type` function. It's responsible for making sure that a `Provider` provides all the necessary _clauses_ to an _interface_ that calls the `Contract(...).require` and `Contract(...).default` functions. It's responsible for erroring at compile-time with helpful messages when the requirements of a _contract_ aren't met.

Note that a the `Contract` function actually is an _interface_. I don't know what to do with this information though.

## Contractor

The _contractor_ type refers to the type that's passed as the first argument to an interface. It's the type that will receive the declarations of the namespace returned by the interface.

## Declaration

A _declaration_ exists at the level of the zig language. It's anything that starts with or can be preceded by `pub`. It can be a function, a constant, a variable, or even a _namespace_ containing other _declarations_.

```zig
// All these four are public declarations. They and their private equivalent are the only kind of
// declaration in Zig.
pub var some_variable = ...;
pub const some_constant = ...;
pub fn someFunction() void {
    ...
}
pub usingnamespace SomeNamespace;
```

A _declaration_ "declare" something new, that can be used later, or even before in a declarative context.

When it's public, a _declaration_ makes itself accessible from outside via the `@import` function or the `usingnamespace` keyword.

## Member

A member can be a variant in the context of an `enum` or a `union`, or it can be a field in the context of a `struct`. Zig's terminology seems to use the word "field" instead when you look at `std.builtin.Type`, but I find it confusing.

## Mutability

Mutability is the ability for an instance to modify the data it holds. Zig's terminology tends to consider that data is only held by value, not reference. In `interfacil`, it's different. Some interface implementors hold their data by reference, they can be passed by value and modify the data still. 

## Namespace

A _namespace_ exists at the level of the zig language. It's something that can hold _declarations_, and from which we can access the public ones using the `.` operator. A _namespace_ can be:

- a `struct` type,
- a `union` type,
- an `enum` type,
- an `opaque` type,
- a source file,

All declarative contexts are a _namespace_.

## Trait

A trait is a condition that a type must fulfill. In Zig, they take the form of `fn (comptime T: type) bool` functions.

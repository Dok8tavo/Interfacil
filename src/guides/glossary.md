
# Glossary

## API (Application Programming Interface)

In the context of `interfacil`, an _api_ refers to all the public declarations of the namespace that's returned by an interface. The "interface" in "Application Programming Interface" doesn't refers to `interfacil`'s interfaces!

## Clause

The _clauses_ of a _contract_ are the different parts of a _contract_ that are passed to an _interface_ through its `clauses` parameter. They are often directly or indirectly assigned to the _declarations_ within the _namespace_ that the _interface_ returns.

_Clauses_ can be required, when they're "declared" in the _contract_ by calling the `Contract(...).require` function,  or defaulted, when they're "declared" in the _contract_ by calling the `Contract(...).default` function.

## Contract

A _contract_ is the result of the `Contract(comptime Contractor: type, comptime clauses: anytype) type` function. It's responsible for making sure that a `Contractor` provides all the necessary `clauses` to an interface that calls the `Contract(...).require` and `Contract(...).default` functions. It's responsible for erroring at compile-time with helpful messages when the requirements of a _contract_ aren't met.

Note that a the `Contract` function actually is an interface. I don't know what to do with this information though.

## Contractor

The _contractor_ type refers to the type that provides the declarations for the _clauses_ of a given _contract_. It's also usually the _namespace_ that receive the _interface_'s result.

## Declaration

A _declaration_ exists at the level of the zig language.   It's anything that starts with or can be preceded by `pub`. It can be a function, a constant, a variable, or even a namespace.

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

When it is public, a _declaration_ makes itself accessible from outside via the `@import` function or the `usingnamespace` keyword.

## Interface

An _interface_ is a function with this kind of prototype: `fn (comptime Contractor: type, comptime clauses: anytype) type`.

It takes two parameters:
1. The type that will serve as the _contractor_,
2. A struct literal containing _clauses_ as fields.

It internally uses a _contract_. And then it returns a namespace, that'll be used from usually the same type. 

## Member

A member can be a variant in the context of an `enum` or a `union`, or it can be a field in the context of a `struct`. Zig's terminology seems to use the word "field" instead when you look at `std.builtin.Type`, but I find it confusing.

## Namespace

A _namespace_ exists at the level of the zig language. It's something that can holds declarations, and from which we can access the public ones using the `.` operator. A _namespace_ can be:

- a `struct` type,
- a `union` type,
- an `enum` type,
- an `opaque` type,
- a source file,

All declarative contexts are a _namespace_.

## Trait

A trait is a condition that a type must fulfill. In Zig, they take the form of `fn (comptime T: type) bool` functions.

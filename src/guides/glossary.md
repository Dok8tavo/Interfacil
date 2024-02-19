
# Glossary

## API (Application Programming Interface)

In the context of `interfacil`, an _api_ refers to all the public _declarations_ of the _namespace_ that's returned by an _interface_. The "interface" in "Application Programming Interface" doesn't refers to `interfacil`'s _interfaces_!

## Clause

The _clauses_ of a _contract_ are the different parts of a _contract_ that are passed to an _interface_ through its `clauses` parameter. They are often directly or indirectly assigned to the _declarations_ within the _namespace_ that the _interface_ returns.

_Clauses_ can be required, when they're "declared" in the _contract_ by calling the `Contract(...).require` function,  or defaulted, when they're "declared" in the _contract_ by calling the `Contract(...).default` function.

### Special clauses

The `Contract` _interface_ provides a few common and useful special _clauses_. These can directly be accessed by the _contract_, instead of using `Contract(...).require` or `Contract(...).default`.

- `.Self`: This _clause_ refers to the type that'll benefit from the methods of the _namespace_, it's the `Contractor` by default.
- `.mutation`: This _clause_ determines whether mutation should occur by reference or by value (when a reference is held by `Self`). By default it's `.by_ref` and then `VarSelf` is actually `*Self`. It can be set to `.by_val` and then `VarSelf` is `Self`.
- `.sample`: This _clause_ is a const slice of `Self`. It's what the tests of the returned namespace will use.
- `.VarSelf`: This isn't a _clause_, but it's a _declaration_ that's also accessible from the _contract_. It only depends on the `.mutation` and `.Self` _clauses_. It can be either `*Self` if `mutation` is `.by_ref` (default) or `Self` if it's `.by_val`. 

## Contract

A _contract_ is the result of the `Contract(comptime Contractor: type, comptime clauses: anytype) type` function. It's responsible for making sure that a `Contractor` provides all the necessary `clauses` to an _interface_ that calls the `Contract(...).require` and `Contract(...).default` functions. It's responsible for erroring at compile-time with helpful messages when the requirements of a _contract_ aren't met.

Note that a the `Contract` function actually is an _interface_. I don't know what to do with this information though.

## Contractor

The _contractor_ type refers to the type that provides the _declarations_ for the _clauses_ of a given _contract_. It's also usually the _namespace_ that receives the _interface_'s result.

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

## Interface

An _interface_ is a set of _declarations_ that a type must provide, and a set of _declarations_ that are provided to the type. These two sets can overlap. _Interfaces_ are useful for providing consistent _API_, avoid rewriting code when different types must implement a similar logic.

Unlike many modern languages, in Zig interfaces aren't a language construct. They must (and can!) be implemented by the programmer. This is what `interfacil` is for.

### In Zig

There's a well written and commonly used _interface_ in the standard library that intermediate Zig users should be familiar with: the `std.mem.Allocator`.

The allocator, and other similar _interfaces_ implementation, has three interesting parts:

- the _virtual table_ field,
- the _context_ field,
- the _declarations_,

The virtual table is set of functions that will be used to generate the _declarations_. The _context_ is a type-erased (a pointer to `anyopaque`) state that the allocator can pass to the functions of the _virtual table_.

This is what's called a _dynamic interface_, because it's type-erased, and in code you can pass an `Allocator` instance, without worrying about the actual type of its context.

### In `Interfacil`

The implementation of _dynamic interfaces_ in `interfacil` are pretty much the same. But what's new is the use of _static interfaces_. Now look at the `interfacil.memory.Allocator` implementation. There's still a _context_, a _virtual table_, in addition there's a few wrapper functions, but the declarations are returned by the `interfacil.memory.Allocating` function.

What's really different is _static interfaces_, the functions like `fn Allocating(comptime Contractor: type, comptime clauses: anytype) type`. They take the set of functions/_declarations_ provided **by** the _contractor_ in argument and return a _namespace_ that contains the _declarations_ provided **to** the _contractor_.

These _static interfaces_ are different in that they aren't type-erased. Their advantages are:

- they trivially support composition (a.k.a. using multiple interfaces on the same type at the same time),
- they avoid a lot of code duplication,
- _dynamic interfaces_ rely on the compiler optimization in order to be as fast as _static interfaces_

Their disadvantages are:

- they're not type-erased, so you might have to rely on `anytype` to use generics, which isn't the most convenient way to convey intent,
- they're not type-erased, so you can't use them properly for dynamic libraries.

## Member

A member can be a variant in the context of an `enum` or a `union`, or it can be a field in the context of a `struct`. Zig's terminology seems to use the word "field" instead when you look at `std.builtin.Type`, but I find it confusing.

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

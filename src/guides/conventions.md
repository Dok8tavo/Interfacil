
# Conventions

## Naming

### Casing

TLDR: Interfaces should be PascalCased.

In Zig, the convention is to PascalCase the types. The exception is when they're only namespaces (when they have no members), then they should be snake_cased.

But the reason for this exception is that types don't carry the same meaning, don't serve the same function when they're namespaces. The reason we like to differentiate types from other data, is that we can make instances of them. Shortly, they're not instancianted (that's in the Zig documentation's style guide).

However in the case of interfaces, they're kind of part of another type. There are instances, that can access the methods inside the interface's result. I think it makes more sense to PascalCase them.

### Interface

The name of an interface should be a descriptor of the type that'll receive the generated namespace. Assuming most types will be names, an interface should be an adjective or an adjectival sentence.

- Making a type support iteration:
    - no: `Iterator`, `Iteration`, `Iterate`,
    - yes: `Iterable`, `WithIteration`,
- Giving a type some kind of manager:
    - no: `Manager`, `Manage`, `Management`,
    - yes: `Manageable`, `Managed`, `WithManager`,
- Defining an equivalence into the type:
    - no: `Equivalency`,
    - yes: `Equivalent`, `WithEquivalency`,
- Defining an order into the type:
    - no: `Order`, `Ordering`,
    - yes: `Ordered`, `WithOrder`,
- Giving the possibility of coercing to a given type:
    - no: `CoerceTo`, `CoercionTo`,
    - yes: `CoercingTo`, `WithCoercionTo`,
- Defining a counter into the type:
    - no: `Count`, `Counter`
    - yes: `Counting`, `WithCounter`
- Defining an algebraic structure inside the type:
    - no: `Algebra`,
    - yes: `Alsebraic`, `WithAlgebra`,
- Defining a default:
    - no: `Default`,
    - yes: `Defaulting`, `WithDefault`,
    
Most of the time, when there's a name that describe well the interface, `WithName` is just as good. 

### Parameters

The parameters of an interface should always be the same. An interface is not `fn (type, anytype) type`, it's `fn (comptime Contractor: type, comptime clauses: anytype) type`. This is taken into account by the `isInterface` trait.

## Order

As interfaces aren't a builtin construct of zig, they're a bit less readable than the definition of your typical type. To compensate this, it can be useful to have some conventions that will let the user of interfaces quickly find what they're looking for. Let's make this nice and tidy!

An interface's body should consist of a simple `return` statement. It should be a `struct`. The only exception is the dependency on mandatory traits. If the contractor needs to be a struct for example, you can do a simple check that'll result in a compiling error. If the trait depends on the presence or the absence of a given declaration, you can use it later, since the `clauses` is precisely intended for this purpose. Avoid nesting, and you're good to go.

Inside the returned struct, the contract should be declared immediatly:

```zig
return struct {
    const contract = contracts.Contract(Contractor, clauses);
    ....
};
```

After the contract everything should follow these rules in this order (by index sort of):

- usingnamespace < everything else
- usingnamespace interface_generated < usingnamespace other_namespaces
- require < default,
- public < private,
- provided (require & default) < generated,
- variables < methods < functions < constants < types < namespaces
- everything < tests

Also, whenever there's a public declaration, it shouldn't be assigned a complicated block or expression. Keep it simple by breaking it down into smaller private declarations. This way, the api can be grouped together nicely.

These rules are more a style guide, they're not mandatory at all, of course.

### Exhaustive example

```zig
pub fn Interface(comptime Contractor: type, comptime clauses: anytype) type {
    // traits
    if (!hasTrait(Contractor)) misc.compileError(
        "The contractor `{s}` should have the trait `hasTrait` for implementing `Interface`!",
        .{@typeName(Contractor)},
    );

    return struct {
        // the contract
        const contract = contracts.Contract(Contractor, clauses);

        // usingnamespace
        pub usingnamespace PublicInterface(Contractor, clauses);
        pub usingnamespace public_namespace;
        usingnamespace PrivateInterface(Contractor, clauses);
        usingnamespace private_namespace;

        // provided
        // public 
        // variables
        pub var requiredPublicVariable = contract.require(..., Variable);
        pub var defaultedPublicVariable = contract.default(..., privateConst);

        // methods
        pub const requiredPublicMethod = contract.require(..., fn (Self, ...) Return);
        pub const defaultedPublicMethod = contract.default(..., privateMethod);

        // other functions
        pub const requiredPublicFunction = contract.require(...);
        pub const defaultedPublicFunction = contract.default(...);

        // constants
        pub const required_public_constant = contract.require(...);
        pub const defaulted_public_constant = contract.default(...);

        // types
        pub const RequiredPublicType = contract.require(..., type);
        pub const DefaultedPublicType = contract.default(..., PrivateType);

        // namespaces
        pub const required_public_namespace = contract.require(..., type);
        pub const defaulted_public_namespace = contract.default(..., PrivateNamespace);

        // private
        // first
        var requiredPrivateVariable = contract.require(..., Variable);
        var defaultedPrivateVariable = contract.default(..., privateConst);

        // methods
        const requiredPrivateMethod = contract.require(..., fn (Self, ...) Return);
        const defaultedPrivateMethod = contract.default(..., privateMethod);

        // other functions
        const requiredPrivateFunction = contract.require(...);
        const defaultedPrivateFunction = contract.default(...);

        // constants
        const required_private_constant = contract.require(...);
        const defaulted_private_constant = contract.default(...);

        // types
        const RequiredPrivateType = contract.require(..., type);
        const DefaultedPrivateType = contract.default(..., u32);

        // namespaces
        pub const required_public_namespace = contract.require(..., type);
        pub const defaulted_public_namespace = contract.default(..., struct {
            pub const hello_world = "Hello world!";
        });

        // generated
        // public 
        pub var public_variable: u32 = 0;
        pub fn publicMethod(self: Contractor, ...) Result {
            ...
        }
        pub const publicFunction(...) Result {
            ....
        } 

        pub const public_constant = 3.14159265;
        pub const PublicType = ArrayList(Contractor);
        pub const public_namespace = struct {
            pub const lol = private_constant;
        };

        // private
        var private_variable: u32 = -1;
        fn privateMethod(self: Contractor, ...) Result {
            ...
        }
        fn privateFunction(...) Result {
            ....
        } 

        const private_constant = 22/7;
        const PrivateType = ArrayListUnmanaged(Contractor);
        const private_namespace = struct {
            pub const hello = requiredPrivateMethod;
        };

        // tests
        test "Some test" {
            ...
        }
    };
}
```

## Path Access

### Short Path Access (_SPA_)

The _SPA_ (short path access) is the default convention for calling a method (or access any declaration actually) that's implemented by a single interface.

#### Example

```zig
// Let's assume that `FieldXManaged`` and `FieldYManaged` both implements a `getField` method.
// The `FieldXManaged` also implements `getX`, and `FieldYManaged` implements a `getY`.
const interfaces = @import("interfaces.zig");
const FieldXManaged = interfaces.FieldXManaged;
const FieldYManaged = interfaces.FieldYManaged;

const Type = struct {
    ...
    pub usingnamespace FieldXManaged(Type, .{});
    pub usingnamespace FieldYManaged(Type, .{});
};

pub fn main() !void {
    const spa = Type.new();
    // This works, because it's unambiguous which `getX` we're referring to.
    const x = try spa.getX();
    // This works, because it's unambiguous which `getY` we're referring to.
    const y = try spa.getY();
    // This doesn't work, because it's ambiguous which `getField` we're referring to. 
    const field = try spa.getField();
}
```

### Full Path Access (_FPA_)

The _FPA_ (full path access) is a convention for disambiguating the access of declarations with the same name that comes from different interfaces.

#### Example

```zig
// Let's assume that `FieldXManaged`` and `FieldYManaged` both implements a `getField` method.
// The `FieldXManaged` also implements `getX`, and `FieldYManaged` implements a `getY`.
const interfaces = @import("interfaces.zig");
const FieldXManaged = interfaces.FieldXManaged;
const FieldYManaged = interfaces.FieldYManaged;

const Type = struct {
    ... 
    pub const XManaged = FieldXManaged(Type, .{});
    pub const YManaged = FieldYManaged(Type, .{});
};

pub fn main() !void {
    const fpa = Type.new();
    // This works, because it's unambiguous which `getX` we're referring to.
    const x = try Type.XManaged.getX(fpa);
    // This works, because it's unambiguous which `getY` we're referring to.
    const y = try Type.YManaged.getY(fpa);
    // This also works, because it's unambiguous which `getField` we're referring to. 
    const field = try Type.XManaged.getField(fpa);;
}
```

### Mixed Path Access (_MPA_)

Sometimes it's to use both _SPA_ and _FPA_. You can use _SPA_ on a prevalent interface, and _FPA_ on the secondary ones. Or you can use both on all of them, and use _SPA_ whenever it's unambiguous, and _FPA_ when it's ambiguous.


#### Example

```zig
// Let's assume that `FieldXManaged`` and `FieldYManaged` both implements a `getField` method.
// The `FieldXManaged` also implements `getX`, and `FieldYManaged` implements a `getY`.
const interfaces = @import("interfaces.zig");
const FieldXManaged = interfaces.FieldXManaged;
const FieldYManaged = interfaces.FieldYManaged;

const Type = struct {
    ...
    pub const XManaged = FieldXManaged(Type, .{});
    pub const YManaged = FieldYManaged(Type, .{});
    pub usingnamespace XManaged;
    pub usingnamespace YManaged;
};

pub fn main() !void {
    const fpa = Type.new();
    // This works, because it's unambiguous which `getX` we're referring to.
    const x = try fpa.getX();
    // This works, because it's unambiguous which `getY` we're referring to.
    const y = try fpa.getY();
    // This also works, because it's unambiguous which `getField` we're referring to. 
    const field = try Type.XManaged.getField(fpa);;
}
```


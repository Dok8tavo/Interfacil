
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


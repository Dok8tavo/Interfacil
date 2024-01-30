const std = @import("std");
const builtin = @import("builtin");

/// This function allows the use custom undefined behaviour. If `is_ub` is true, this function will
/// reach `unreachable`. In debug build though, it'll panic with the formatted error message. See
/// `std.fmt.format` for documentation about the formatting rules.
///
/// ## Usage
///
/// ```zig
/// const num: u64 = shouldReturnPair();
/// checkUB(num % 2 != 0,
///     \\The `shouldReturnPair` function should return a pair number, yet it returned {}!
///     \\Source: `{s}` at {s}:{}:{}
///     \\
/// , .{
///     num,
///     @src().fn_name,
///     @src().file,
///     @src().line,
///     @src().column,
/// });
/// ```
pub inline fn checkUB(is_ub: bool, comptime fmt: []const u8, args: anytype) void {
    if (is_ub) cold(
        if (builtin.mode != .Debug)
            unreachable
        else
            std.debug.panic(fmt, args),
    );
}

/// The `cold` and `hot` functions are used for helping the compiler figure out what's more likely
/// to happen in a control flow. Which return statement will return, which branch will be executed,
/// which break will occur, etc. It might not be useful at all, but it could maybe, perhaps improve
/// performance by a tiny bit. You should benchmark anyway. Heck I don't even know if it works!
///
/// ## Usage
/// Usually, it's interesting to use it when there's control flow involved. Like in an `if` or a
///`switch` statement:
/// ```zig
/// if (condition) cold({
///     unlikely();
///     stillUnlikely();
/// })
/// else moreLikely();
///
/// switch (value) {
///     likely => hot({
///         doThis();
///         doThat();
///     }),
///     unlikely => cold({
///         this();
///         is();
///         often();
///         error_handling();
///     }),
///     in_between => normal(),
/// }
/// ```
pub inline fn cold(value: anytype) @TypeOf(value) {
    @setCold(true);
    return value;
}

/// This function is just a formatted version of `@compileError`. See `@import("std").fmt.format` for
/// documentation about the formatting rules.
pub inline fn compileError(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}

/// This function logs the value that it returns together with its type in debug builds. It's a
/// compile error when used in release builds. It's probably a better practice than using
/// `std.debug.print` everywhere.
///
/// ## Usage
/// ```zig
/// pub fn main() void {
///     const boolean = true;
///     const number: i32 = if (boolean) 1 else -1;
///     // this line will log "dbg(1: i32)", as well as assigning `inverse` to `-1`.
///     const inverse = -dbg(number);
///     ...
/// }
/// ```
pub inline fn dbg(value: anytype) @TypeOf(value) {
    std.log.debug("dbg({any}: {s})\n", .{
        value,
        @typeName(@TypeOf(value)),
    });
    return todo(value);
}

pub fn emptySlice(comptime Item: type) []Item {
    return &[_]Item{};
}

/// Enum literals should be preferred over strings when using metaprogramming. A string represents
/// text, something that's supposed to be printed somewhere. For representing code, especially
/// fields and declarations whose access syntax ressembles enum literals, it's just ideal. Let's
/// not use strings as a metaprogramming interface. What are we? C macros? Come on!
///
/// Using strings is unavoidable when using the following functions:
/// - `@hasDecl(comptime Container: type, comptime name: []const u8) bool`,
/// - `@hasField(comptime Container: type, comptime name: []const u8) bool`,
/// - `@field(lhs: anytype, comptime name: []const u8) ...`,
/// - `@typeName(comptime T: type) []const u8`,
/// - `@errorName(err: anyerror) []const u8`,
/// - `@tagName(tag: anytype) []const u8`,
///
/// But those returning strings are actually mostly meant for being printed at some point. So it
/// makes sense to use strings. The others should be used when writing metaprogramming, not when
/// using it. For this, `EnumLiteral` is a better fit, just like struct literals actually.
///
/// Seeing `EnumLiteral` in a function signature is a little cleaner and prettier than some dirty
/// `@TypeOf(.enum_literal)`.
pub const EnumLiteral = @TypeOf(.enum_literal);

/// This function converts a string into an enum literal.
///
/// If we're using enum literals instead of strings when using metaprogramming, a little tooling
/// can be appreciated for interacting with builtin functions.
///
/// ## Usage
/// ```zig
/// const variant_as_enum_literal = enumLiteral(@tagName(union_instance));
/// const type_as_enum_literal = enumLiteral(@typeName(Type));
/// const error_as_enum_literal = enumLiteral(@errorName(err));
/// ```
pub inline fn enumLiteral(comptime name: []const u8) EnumLiteral {
    const WithNameAsField = @Type(.{ .Enum = std.builtin.Type.Enum{
        .decls = &.{},
        .is_exhaustive = true,
        .tag_type = u1,
        .fields = &[_]std.builtin.Type.EnumField{.{
            .name = name,
            .value = 0,
        }},
    } });
    return @as(EnumLiteral, @field(undef(WithNameAsField), name));
}

/// The `cold` and `hot` functions are used for helping the compiler figure out what's more likely
/// to happen in a control flow. Which return statement will return, which branch will be executed,
/// which break will occur, etc. It might not be useful at all, but it could maybe, perhaps improve
/// performance by a tiny bit. You should benchmark anyway. Heck I don't even know if it works!
///
/// ## Usage
/// Usually, it's interesting to use it when there's control flow involved. Like in an `if` or a
///`switch` statement:
/// ```zig
/// if (condition) cold({
///     unlikely();
///     stillUnlikely();
/// })
/// else moreLikely();
///
/// switch (value) {
///     likely => hot({
///         doThis();
///         doThat();
///     }),
///     unlikely => cold({
///         this();
///         is();
///         often();
///         error_handling();
///     }),
///     in_between => normal(),
/// }
/// ```
pub inline fn hot(value: anytype) @TypeOf(value) {
    @setCold(false);
    return value;
}

/// This function cast the given value into an optional.
pub inline fn maybe(value: anytype) ?@TypeOf(value) {
    return value;
}

/// In Zig, errors are values. You can't carry much information in them, apart from the kind of
/// error it is. Sometimes it would be interesting to do so, like if you'd want some about who
/// emitted the error, when, from where, what can be done to fix it, etc.
///
/// The `Result` type is meant to fix that. You can store a successful result in the
/// `pass: Pass` variant, or an errorful result in the `fail: Fail` variant. In order to get the
/// result, you should use the `get` or `nab` method, which will force you to handle the error if
/// there's one.
pub fn Result(comptime P: type, comptime F: type) type {
    return union(enum) {
        const Self = @This();
        pub const Pass = P;
        pub const Fail = F;

        /// This variant is active when the `Result` is considered successful
        pass: Pass,

        /// This variant is active when the `Result` isn't considered successful
        fail: Fail,

        /// This function returns the `pass` variant if it's active. Otherwise it ignores the
        /// `fail` variant, and you can `orelse` it with a default or a block that's independent
        /// of the error.
        ///
        /// ## Usage
        ///  ```zig
        /// const defaulted = result1.get() orelse default;
        /// const early_return = result2.get() orelse {
        ///     std.debug.print("It didn't work!\n", .{});
        ///     return;
        /// };
        /// ```
        pub fn get(self: Self) ?Pass {
            return switch (self) {
                .pass => |pass| hot(pass),
                .fail => cold(null),
            };
        }

        /// This function returns the `pass` variant if it's active. Otherwise it captures the
        /// `fail` variant into its `capture` parameter. You can then use it in an `orelse` block.
        ///
        /// ## Usage
        /// ```zig
        /// var fail = undef(Fail);
        /// const pass = result.nab(&fail) orelse {
        ///     fail.dump(stderr);
        ///     ...
        /// };
        /// ```
        pub fn nab(self: Self, capture: *Fail) ?Pass {
            return switch (self) {
                .pass => |pass| hot(pass),
                .fail => |fail| cold({
                    capture.* = fail;
                    return null;
                }),
            };
        }
    };
}

/// This function is here to provide a default value, when its computing isn't implemented yet. If
/// used in release build, it'll trigger a compile error and display the given error message. See
/// `std.fmt.format` for documentation about the formatting rules.
pub inline fn todo(
    default: anytype,
    comptime fmt: []const u8,
    comptime args: anytype,
) @TypeOf(default) {
    return if (builtin.mode != .Debug) compileError("todo: value {any} of type {s}!\n {s}", .{
        default,
        @typeName(@TypeOf(default)),
        std.fmt.comptimePrint(fmt, args),
    }) else default;
}

/// This function generate an undefined value of the given type.
pub inline fn undef(comptime Undefined: type) Undefined {
    return @as(Undefined, undefined);
}

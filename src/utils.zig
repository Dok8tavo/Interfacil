const std = @import("std");
const builtin = @import("builtin");

/// This function allows enables custom undefined behaviour. If `is_ub` is true, this function will
/// reach `unreachable`. In debug build though, it'll panic with the formatted error message. See
/// `std.fmt.format` for documentation about the formatting rules. If it's run during compile-time
/// it will trigger a compile error of the same format instead.
///
/// ## Usage
///
/// ```zig
/// const num: u64 = shouldReturnPair();
/// const src = @src();
/// /// This will panic in debug mode, reach `unreachable` in release modes.
/// checkUB(num % 2 != 0, \\The `shouldReturnPair` function should return a pair number, yet it returned {}!
///     \\Source: `{s}` at {s}:{}:{}
///     \\
/// , .{ num, src.fn_name, src.file, src.line, src.column });
/// ```
pub inline fn checkUB(is_ub: bool, comptime fmt: []const u8, args: anytype) void {
    if (@inComptime() and is_ub) compileError(fmt, args);
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
///
// ? does it even work ?
pub inline fn cold(value: anytype) @TypeOf(value) {
    @setCold(true);
    return value;
}

/// This function is just a formatted version of `@compileError`. See `std.fmt.format` for
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
///
/// ! Only available in debug builds !
pub inline fn dbg(value: anytype) @TypeOf(value) {
    std.log.debug("dbg({any}: {s})\n", .{
        value,
        @typeName(@TypeOf(value)),
    });
    return todo(value);
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
/// }) else moreLikely();
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
///
// ? does it even work ?
pub inline fn hot(value: anytype) @TypeOf(value) {
    @setCold(false);
    return value;
}

/// # Result
///
/// In Zig, errors are values. You can't carry much information in them, apart from the kind of
/// error it is. Sometimes it would be interesting to do so, like if you'd want some about who
/// emitted the error, when, from where, what can be done to fix it, etc.
///
/// The `Result` type is meant to fix that. You can store a successful result in the
/// `pass: Pass` variant, or an errorful result in the `fail: Fail` variant. In order to get the
/// result, you should use the `get` or `nab` method, which will force you to handle the error if
/// there's one.
///
/// ## Usage
///
/// ### Passing error messages
///
/// ```zig
/// fn failing() Result(Success, []const u8) {
///     return .{ .fail = "The `failing` function did an oopsie!" };
/// }
///
/// pub fn main() void {
///     var fail_message: []const u8 = undefined;
///     const success = failing().nab(&fail_message) orelse @panic(fail_message);
///     _ = success
/// }
/// ```
///
/// ### Passing multiple errors
///
/// ```zig
/// const Res = Result(Success, ArrayList(anyerror));
/// fn failing(allocator: Allocator) Res {
///     var errors = ArrayList(anyerror).init(allocator);
///     // ...
///     errors.append(error.FirstFail) catch @panic("OOM!");
///     // ...
///     errors.append(error.SecondFail) catch @panic("OOM!");
///     // ...
///
///     return if (errors.items.len == 0) .{
///         .pass = ...,
///     } else .{ .fail = errors };
/// }
///
/// pub fn main() !void {
///     var errors: Res.Fail = undefined;
///     errdefer errors.deinit();
///     const res = failing(allocator);
///     const pass = res.nab(&errors) orelse {
///         const stderr = std.io.getStdErr().writer();
///         for (errors.items) |e| {
///             try stderr.print("{any}\n", .{e});
///         }
///
///         return error.Fail;
///     };
///
///     _ = pass;
/// }
/// ```
///
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

        // This function asserts that the `Result` is successful.
        // During compile time,
        pub fn assert(self: Self, comptime fmt: []const u8, args: anytype) Pass {
            if (self == .pass) return hot(self.pass);
            checkUB(self == .pass, fmt, args);
            if (@inComptime()) compileError(fmt, args);
            std.debug.panic(fmt, args);
        }
    };
}

test Result {
    const Closure = struct {
        pub const ParseError = struct {
            non_cifer: u8,
            index: usize,
        };
        pub const Parse = Result(u32, ParseError);
        pub fn parseInt(str: []const u8) Parse {
            var parsed: u32 = 0;
            return for (str, 0..) |c, i| switch (c) {
                '0'...'9' => {
                    parsed *= 10;
                    parsed += c - '0';
                },
                '_' => {},
                else => break Parse{ .fail = .{ .non_cifer = c, .index = i } },
            } else Parse{ .pass = parsed };
        }
    };

    const good_result = Closure.parseInt("12_345");
    try std.testing.expectEqualDeep(@as(?u32, 12_345), good_result.get());

    const bad_result = Closure.parseInt("12_E45");
    var fail = undef(Closure.ParseError);
    const pass = bad_result.nab(&fail) orelse 0;
    try std.testing.expectEqual(pass, 0);
    try std.testing.expectEqual(fail, Closure.ParseError{ .non_cifer = 'E', .index = 3 });
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

/// This function returns an undefined value of the given type.
pub inline fn undef(comptime Undefined: type) Undefined {
    return @as(Undefined, undefined);
}

/// This function cast an opaque pointer to a typed pointer.
/// It's comes handy when implementing dynamic interfaces.
pub inline fn cast(comptime T: type, ptr: *anyopaque) *T {
    return @alignCast(@ptrCast(ptr));
}

/// This function is a tool for making comptime-known slices easily.
/// It comes handy when a static interface requires a slice.
///
/// ## Warning
/// It will be deprecated when automatic coercion is supported by `contracts.Contract`.
///
/// ## Usage
///
/// ```zig
/// const my_slice = slice(bool, .{true, false, true, true});
/// ```
pub inline fn slice(comptime T: type, comptime from: anytype) []const T {
    comptime {
        const From = @TypeOf(from);
        const info = @typeInfo(From);
        switch (info) {
            .Array => |Array| if (Array.child != T) compileError(
                "The `{s}` type must be an array of `{s}`, not `{s}`!",
                .{ @typeName(From), @typeName(T), @typeName(Array.child) },
            ),
            .Struct => |Struct| if (!Struct.is_tuple) compileError(
                "The `{s}` type must be an array, slice or tuple, not a struct!",
                .{@typeName(From)},
            ) else for (Struct.fields) |field| if (field.type != T) compileError(
                "All the members of `{s}` should be `{s}`, but the n°{s} is `{s}` instead",
                .{ @typeName(From), @typeName(T), field.name, @typeName(field.type) },
            ),
            .Pointer => |Pointer| switch (Pointer.size) {
                .Slice => if (Pointer.child != T) compileError(
                    "The `{s}` type must be a slice of `{s}`, not `{s}`!",
                    .{ @typeName(From), @typeName(T), @typeName(Pointer.child) },
                ),
                .One => return slice(T, from.*),
                else => if (Pointer.sentinel == null) compileError(
                    "The `{s}` type should have a known size or a sentinel!",
                    .{@typeName(From)},
                ),
            },
            else => compileError(
                "The `{s}` must be an array, slice or tuple, not a `.{s}`!",
                .{ @typeName(From), @tagName(info) },
            ),
        }

        var s: []const T = &[_]T{};
        for (from) |item| {
            s = s ++ &[_]T{item};
        }

        return s;
    }
}

test slice {
    const my_slice = slice(bool, .{ true, false, true, true });
    try std.testing.expectEqual(@TypeOf(my_slice), []const bool);
    try std.testing.expectEqual(my_slice.len, 4);
    try std.testing.expectEqual(my_slice[0], true);
    try std.testing.expectEqual(my_slice[1], false);
    try std.testing.expectEqual(my_slice[2], true);
    try std.testing.expectEqual(my_slice[3], true);

    const string = "This is a string";
    const another_slice = slice(u8, string);
    try std.testing.expectEqual(@TypeOf(another_slice), []const u8);
    try std.testing.expectEqual(@TypeOf(string), *const [string.len:0]u8);
    try std.testing.expectEqualStrings(string, another_slice);
}

pub const EnumLiteral = @TypeOf(.enum_literal);

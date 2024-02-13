pub const equivalent = @import("comparison/equivalent.zig");
pub const ordered = @import("comparison/ordered.zig");

pub usingnamespace equivalent;
pub usingnamespace ordered;

test {
    _ = equivalent;
    _ = ordered;
}

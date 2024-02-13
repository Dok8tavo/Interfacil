pub const iterating = @import("collections/iterating.zig");
pub const slicing = @import("collections/slicing.zig");
pub const indexing = @import("collections/indexing.zig");

pub usingnamespace iterating;
pub usingnamespace slicing;
pub usingnamespace indexing;

test {
    _ = iterating;
    _ = slicing;
    _ = indexing;
}

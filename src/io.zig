const std = @import("std");
const utils = @import("utils.zig");
const contracts = @import("contracts.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// # Readable
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
pub fn Readable(comptime Contractor: type, comptime clauses: type) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);
        const Self: type = contract.default(.Self, Contractor);
        const mut_by_value: bool = contract.default(.mut_by_value, false);
        const VarSelf = if (mut_by_value) Self else *Self;
        pub const ReadError: type = contract.default(.ReadError, anyerror);
        const AllocReadError = ReadError || Allocator.Error || error{StreamTooLong};
        const StreamError = ReadError || error{EndOfStream};

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub const read: fn (self: VarSelf, buffer: []u8) ReadError!usize =
            contract.require(.read, fn (VarSelf, []u8) ReadError!usize);

        /// Returns the number of bytes read. If the number read is smaller than `buffer.len`, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn readAll(self: VarSelf, buffer: []u8) ReadError!usize {
            return readAtLeast(self, buffer, buffer.len);
        }

        /// Returns the number of bytes read, calling the underlying read
        /// function the minimal number of times until the buffer has at least
        /// `len` bytes filled. If the number read is less than `len` it means
        /// the stream reached the end. Reaching the end of the stream is not
        /// an error condition.
        pub fn readAtLeast(self: VarSelf, buffer: []u8, len: usize) ReadError!usize {
            std.debug.assert(len <= buffer.len);
            var index: usize = 0;
            while (index < len) {
                const amt = try read(self, buffer[index..]);
                if (amt == 0) break;
                index += amt;
            }
            return index;
        }

        /// If the number read would be smaller than `buf.len`, `error.EndOfStream` is returned instead.
        pub fn readNoEof(self: VarSelf, buf: []u8) StreamError!void {
            const amt_read = try readAll(self, buf);
            if (amt_read < buf.len) return StreamError.EndOfStream;
        }

        /// Appends to the `std.ArrayList` contents by reading from the stream
        /// until end of stream is found.
        /// If the number of bytes appended would exceed `max_append_size`,
        /// `error.StreamTooLong` is returned
        /// and the `std.ArrayList` has exactly `max_append_size` bytes appended.
        pub fn readAllArrayList(
            self: VarSelf,
            array_list: *ArrayList(u8),
            max_append_size: usize,
        ) AllocReadError!void {
            return readAllArrayListAligned(self, null, array_list, max_append_size);
        }

        pub fn readAllArrayListAligned(
            self: VarSelf,
            comptime alignment: ?u29,
            array_list: *std.ArrayListAligned(u8, alignment),
            max_append_size: usize,
        ) AllocReadError!void {
            try array_list.ensureTotalCapacity(@min(max_append_size, 4096));
            const original_len = array_list.items.len;
            var start_index: usize = original_len;
            while (true) {
                array_list.expandToCapacity();
                const dest_slice = array_list.items[start_index..];
                const bytes_read = try readAll(self, dest_slice);
                start_index += bytes_read;

                if (start_index - original_len > max_append_size) {
                    array_list.shrinkAndFree(original_len + max_append_size);
                    return AllocReadError.StreamTooLong;
                }

                if (bytes_read != dest_slice.len) {
                    array_list.shrinkAndFree(start_index);
                    return;
                }

                // This will trigger ArrayList to expand superlinearly at whatever its growth rate is.
                try array_list.ensureTotalCapacity(start_index + 1);
            }
        }

        /// Allocates enough memory to hold all the contents of the stream. If the allocated
        /// memory would be greater than `max_size`, returns `error.StreamTooLong`.
        /// Caller owns returned memory.
        /// If this function returns an error, the contents from the stream read so far are lost.
        pub fn readAllAlloc(
            self: VarSelf,
            allocator: Allocator,
            max_size: usize,
        ) AllocReadError![]u8 {
            var array_list = ArrayList(u8).init(allocator);
            defer array_list.deinit();
            try readAllArrayList(self, &array_list, max_size);
            return try array_list.toOwnedSlice();
        }

        /// Appends to the `writer` contents by reading from the stream until `delimiter` is found.
        /// Does not write the delimiter itself.
        /// If `optional_max_size` is not null and amount of written bytes exceeds `optional_max_size`,
        /// returns `error.StreamTooLong` and finishes appending.
        /// If `optional_max_size` is null, appending is unbounded.
        pub fn streamUntilDelimiter(
            self: VarSelf,
            writer: Writer,
            delimiter: u8,
            optional_max_size: ?usize,
        ) anyerror!void {
            if (optional_max_size) |max_size| {
                for (0..max_size) |_| {
                    const byte: u8 = try readByte(self);
                    if (byte == delimiter) return;
                    try writer.writeByte(byte);
                }
                return error.StreamTooLong;
            } else {
                while (true) {
                    const byte: u8 = try readByte(self);
                    if (byte == delimiter) return;
                    try writer.writeByte(byte);
                }
                // Can not throw `error.StreamTooLong` since there are no boundary.
            }
        }

        /// Reads from the stream until specified byte is found, discarding all data,
        /// including the delimiter.
        /// If end-of-stream is found, this function succeeds.
        pub fn skipUntilDelimiterOrEof(self: VarSelf, delimiter: u8) ReadError!void {
            while (true) {
                const byte = readByte(self) catch |err| switch (err) {
                    StreamError.EndOfStream => return,
                    else => |e| return e,
                };
                if (byte == delimiter) return;
            }
        }

        /// Reads 1 byte from the stream or returns `error.EndOfStream`.
        pub fn readByte(self: VarSelf) StreamError!u8 {
            var result: [1]u8 = undefined;
            const amt_read = try read(self, result[0..]);
            if (amt_read < 1) return StreamError.EndOfStream;
            return result[0];
        }

        /// Same as `readByte` except the returned byte is signed.
        pub fn readByteSigned(self: VarSelf) StreamError!i8 {
            return @as(i8, @bitCast(try readByte(self)));
        }

        /// Reads exactly `num_bytes` bytes and returns as an array.
        /// `num_bytes` must be comptime-known
        pub fn readBytesNoEof(self: VarSelf, comptime num_bytes: usize) StreamError![num_bytes]u8 {
            var bytes: [num_bytes]u8 = undefined;
            try readNoEof(self, &bytes);
            return bytes;
        }

        /// Reads bytes until `bounded.len` is equal to `num_bytes`,
        /// or the stream ends.
        ///
        /// * it is assumed that `num_bytes` will not exceed `bounded.capacity()`
        pub fn readIntoBoundedBytes(
            self: VarSelf,
            comptime num_bytes: usize,
            bounded: *std.BoundedArray(u8, num_bytes),
        ) ReadError!void {
            while (bounded.len < num_bytes) {
                // get at most the number of bytes free in the bounded array
                const bytes_read = try read(self, bounded.unusedCapacitySlice());
                if (bytes_read == 0) return;

                // bytes_read will never be larger than @TypeOf(bounded.len)
                // due to `self.read` being bounded by `bounded.unusedCapacitySlice()`
                bounded.len += @as(@TypeOf(bounded.len), @intCast(bytes_read));
            }
        }

        /// Reads at most `num_bytes` and returns as a bounded array.
        pub fn readBoundedBytes(
            self: VarSelf,
            comptime num_bytes: usize,
        ) ReadError!std.BoundedArray(u8, num_bytes) {
            var result = std.BoundedArray(u8, num_bytes){};
            try readIntoBoundedBytes(self, num_bytes, &result);
            return result;
        }

        pub inline fn readInt(
            self: VarSelf,
            comptime T: type,
            endian: std.builtin.Endian,
        ) StreamError!T {
            const bytes = try readBytesNoEof(self, @divExact(@typeInfo(T).Int.bits, 8));
            return std.mem.readInt(T, &bytes, endian);
        }

        pub fn readVarInt(
            self: VarSelf,
            comptime ReturnType: type,
            endian: std.builtin.Endian,
            size: usize,
        ) StreamError!ReturnType {
            std.debug.assert(size <= @sizeOf(ReturnType));
            var bytes_buf: [@sizeOf(ReturnType)]u8 = undefined;
            const bytes = bytes_buf[0..size];
            try readNoEof(self, bytes);
            return std.mem.readVarInt(ReturnType, bytes, endian);
        }

        /// Optional parameters for `skipBytes`
        pub const SkipBytesOptions = struct {
            buf_size: usize = 512,
        };

        // `num_bytes` is a `u64` to match `off_t`
        /// Reads `num_bytes` bytes from the stream and discards them
        pub fn skipBytes(
            self: VarSelf,
            num_bytes: u64,
            comptime options: SkipBytesOptions,
        ) StreamError!void {
            var buf: [options.buf_size]u8 = undefined;
            var remaining = num_bytes;

            while (remaining > 0) {
                const amt = @min(remaining, options.buf_size);
                try readNoEof(self, buf[0..amt]);
                remaining -= amt;
            }
        }

        /// Reads `slice.len` bytes from the stream and returns if they are the same as the passed slice
        pub fn isBytes(self: VarSelf, slice: []const u8) StreamError!bool {
            var i: usize = 0;
            var matches = true;
            while (i < slice.len) : (i += 1) {
                if (slice[i] != try readByte(self)) {
                    matches = false;
                }
            }
            return matches;
        }

        pub fn readStruct(self: VarSelf, comptime T: type) StreamError!T {
            // Only extern and packed structs have defined in-memory layout.
            comptime std.debug.assert(@typeInfo(T).Struct.layout != .Auto);
            var res: [1]T = undefined;
            try readNoEof(self, std.mem.sliceAsBytes(res[0..]));
            return res[0];
        }

        pub fn readStructEndian(
            self: VarSelf,
            comptime T: type,
            endian: std.builtin.Endian,
        ) StreamError!T {
            var res = try readStruct(self, T);
            if (std.mem.native_endian != endian) {
                std.mem.byteSwapAllFields(T, &res);
            }
            return res;
        }

        /// Reads an integer with the same size as the given enum's tag type. If the integer matches
        /// an enum tag, casts the integer to the enum tag and returns it. Otherwise, returns an `error.InvalidValue`.
        /// TODO optimization taking advantage of most fields being in order
        pub fn readEnum(
            self: VarSelf,
            comptime Enum: type,
            endian: std.builtin.Endian,
        ) (StreamError || error{InvalidValue})!Enum {
            const type_info = @typeInfo(Enum).Enum;
            const tag = try readInt(self, type_info.tag_type, endian);

            inline for (std.meta.fields(Enum)) |field| {
                if (tag == field.value) {
                    return @field(Enum, field.name);
                }
            }

            return error.InvalidValue;
        }

        pub fn asReader(self: *Self) Reader {
            return Reader{
                .ctx = self,
                .vtable = .{ .read = &read },
            };
        }
    };
}

/// TODO
pub const Reader = struct {
    ctx: *anyopaque,
    vtable: struct {
        read: *const fn (self: *anyopaque, buffer: []u8) anyerror!usize,
    },

    fn readWrapper(self: Reader, buffer: []u8) anyerror!usize {
        return self.vtable(self.ctx, buffer);
    }

    pub usingnamespace Readable(Reader, .{ .read = readWrapper, .mut_by_value = true });
};

/// # Writeable
///
/// TODO
///
/// ## Clauses
///
/// TODO
///
/// ## Declarations
///
/// TODO
///
/// ## Usage
///
/// TODO
///
/// ## Testing
///
/// TODO
pub fn Writeable(comptime Contractor: type, comptime clauses: type) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        pub const write = contract.require(.write, fn (VarSelf, []const u8) WriteError!usize);
        pub const WriteError: type = contract.default(.WriteError, anyerror);
        const Self: type = contract.default(.Self, Contractor);
        const mut_by_value = contract.default(.mut_by_value, false);
        const VarSelf = if (mut_by_value) Self else *Self;

        pub fn writeAll(self: VarSelf, bytes: []const u8) WriteError!void {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try write(self, bytes[index..]);
            }
        }

        pub fn print(self: VarSelf, comptime format: []const u8, args: anytype) WriteError!void {
            return std.fmt.format(asWriter(self), format, args);
        }

        pub fn writeByte(self: VarSelf, byte: u8) WriteError!void {
            const array = [1]u8{byte};
            return writeAll(self, &array);
        }

        pub fn writeByteNTimes(self: VarSelf, byte: u8, n: usize) WriteError!void {
            var bytes: [256]u8 = undefined;
            @memset(bytes[0..], byte);

            var remaining: usize = n;
            while (remaining > 0) {
                const to_write = @min(remaining, bytes.len);
                try writeAll(self, bytes[0..to_write]);
                remaining -= to_write;
            }
        }

        pub fn writeBytesNTimes(self: VarSelf, bytes: []const u8, n: usize) WriteError!void {
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try writeAll(self, bytes);
            }
        }

        pub inline fn writeInt(
            self: VarSelf,
            comptime T: type,
            value: T,
            endian: std.builtin.Endian,
        ) WriteError!void {
            var bytes: [@divExact(@typeInfo(T).Int.bits, 8)]u8 = undefined;
            std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
            return writeAll(self, &bytes);
        }

        pub fn writeStruct(self: VarSelf, value: anytype) WriteError!void {
            // Only extern and packed structs have defined in-memory layout.
            comptime std.debug.assert(@typeInfo(@TypeOf(value)).Struct.layout != .Auto);
            return writeAll(self, std.mem.asBytes(&value));
        }

        pub fn asWriter(self: *Self) Writer {
            return Writer{
                .ctx = self,
                .write = &write,
            };
        }
    };
}

/// TODO
pub const Writer = struct {
    ctx: *anyopaque,
    vtable: struct {
        write: *const fn (self: *anyopaque, bytes: []const u8) anyerror!usize,
    },

    fn writeWrapper(self: Writer, bytes: []const u8) anyerror!usize {
        return try self.vtable.write(self.ctx, bytes);
    }

    pub usingnamespace Writeable(Writer, .{
        .mut_by_value = true,
        .write = writeWrapper,
    });
};

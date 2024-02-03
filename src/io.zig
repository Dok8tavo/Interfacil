const std = @import("std");
const misc = @import("misc.zig");
const contracts = @import("contracts.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListAligned = std.ArrayListAligned;

/// This interface is straightly taken from `std.io.AnyReader`.
pub fn Readable(comptime Contractor: type, comptime clauses: type) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub const read: fn (self: Self, buffer: []u8) Error!usize =
            contract.require(.read, fn (Self, []u8) Error!usize);

        /// Returns the number of bytes read. If the number read is smaller than `buffer.len`, it
        /// means the stream reached the end. Reaching the end of a stream is not an error
        /// condition.
        pub fn readAll(self: Self, buffer: []u8) Error!usize {
            return readAtLeast(self, buffer, buffer.len);
        }

        /// Returns the number of bytes read, calling the underlying read
        /// function the minimal number of times until the buffer has at least
        /// `len` bytes filled. If the number read is less than `len` it means
        /// the stream reached the end. Reaching the end of the stream is not
        /// an error condition.
        pub fn readAtLeast(self: Self, buffer: []u8, len: usize) Error!usize {
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
        pub fn readNoEof(self: Self, buf: []u8) Error!void {
            const amt_read = try readAll(self, buf);
            if (amt_read < buf.len) return Error.EndOfStream;
        }

        /// Appends to the `std.ArrayList` contents by reading from the stream
        /// until end of stream is found.
        /// If the number of bytes appended would exceed `max_append_size`,
        /// `error.StreamTooLong` is returned
        /// and the `std.ArrayList` has exactly `max_append_size` bytes appended.
        pub fn readAllArrayList(
            self: Self,
            array_list: *ArrayList(u8),
            max_append_size: usize,
        ) Error!void {
            return readAllArrayListAligned(self, null, array_list, max_append_size);
        }

        pub fn readAllArrayListAligned(
            self: Self,
            comptime alignment: ?u29,
            array_list: *ArrayListAligned(u8, alignment),
            max_append_size: usize,
        ) Error!void {
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
                    return Error.StreamTooLong;
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
        pub fn readAllAlloc(self: Self, allocator: Allocator, max_size: usize) Error![]u8 {
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
            self: Self,
            writer: anytype,
            delimiter: u8,
            optional_max_size: ?usize,
        ) Error!void {
            if (optional_max_size) |max_size| {
                for (0..max_size) |_| {
                    const byte: u8 = try readByte(self);
                    if (byte == delimiter) return;
                    try writer.writeByte(byte);
                }
                return Error.StreamTooLong;
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
        pub fn skipUntilDelimiterOrEof(self: Self, delimiter: u8) Error!void {
            while (true) {
                const byte = readByte(self) catch |err| switch (err) {
                    Error.EndOfStream => return,
                    else => |e| return e,
                };
                if (byte == delimiter) return;
            }
        }

        /// Reads 1 byte from the stream or returns `error.EndOfStream`.
        pub fn readByte(self: Self) Error!u8 {
            var result: [1]u8 = undefined;
            const amt_read = try read(self, result[0..]);
            if (amt_read < 1) return Error.EndOfStream;
            return result[0];
        }

        /// Same as `readByte` except the returned byte is signed.
        pub fn readByteSigned(self: Self) Error!i8 {
            return @as(i8, @bitCast(try readByte(self)));
        }

        /// Reads exactly `num_bytes` bytes and returns as an array.
        /// `num_bytes` must be comptime-known
        pub fn readBytesNoEof(self: Self, comptime num_bytes: usize) Error![num_bytes]u8 {
            var bytes: [num_bytes]u8 = undefined;
            try readNoEof(self, &bytes);
            return bytes;
        }

        /// Reads bytes until `bounded.len` is equal to `num_bytes`,
        /// or the stream ends.
        ///
        /// * it is assumed that `num_bytes` will not exceed `bounded.capacity()`
        pub fn readIntoBoundedBytes(
            self: Self,
            comptime num_bytes: usize,
            bounded: *std.BoundedArray(u8, num_bytes),
        ) Error!void {
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
            self: Self,
            comptime num_bytes: usize,
        ) Error!std.BoundedArray(u8, num_bytes) {
            var result = std.BoundedArray(u8, num_bytes){};
            try readIntoBoundedBytes(self, num_bytes, &result);
            return result;
        }

        pub inline fn readInt(self: Self, comptime T: type, endian: std.builtin.Endian) Error!T {
            const bytes = try readBytesNoEof(self, @divExact(@typeInfo(T).Int.bits, 8));
            return std.mem.readInt(T, &bytes, endian);
        }

        pub fn readVarInt(
            self: Self,
            comptime ReturnType: type,
            endian: std.builtin.Endian,
            size: usize,
        ) Error!ReturnType {
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
        pub fn skipBytes(self: Self, num_bytes: u64, comptime options: SkipBytesOptions) Error!void {
            var buf: [options.buf_size]u8 = undefined;
            var remaining = num_bytes;

            while (remaining > 0) {
                const amt = @min(remaining, options.buf_size);
                try readNoEof(self, buf[0..amt]);
                remaining -= amt;
            }
        }

        /// Reads `slice.len` bytes from the stream and returns if they are the same as the passed slice
        pub fn isBytes(self: Self, slice: []const u8) Error!bool {
            var i: usize = 0;
            var matches = true;
            while (i < slice.len) : (i += 1) {
                if (slice[i] != try readByte(self)) {
                    matches = false;
                }
            }
            return matches;
        }

        pub fn readStruct(self: Self, comptime T: type) Error!T {
            // Only extern and packed structs have defined in-memory layout.
            comptime std.debug.assert(@typeInfo(T).Struct.layout != .Auto);
            var res: [1]T = undefined;
            try readNoEof(self, std.mem.sliceAsBytes(res[0..]));
            return res[0];
        }

        pub fn readStructEndian(self: Self, comptime T: type, endian: std.builtin.Endian) Error!T {
            var res = try readStruct(self, T);
            if (std.mem.native_endian != endian) {
                std.mem.byteSwapAllFields(T, &res);
            }
            return res;
        }

        /// Reads an integer with the same size as the given enum's tag type. If the integer matches
        /// an enum tag, casts the integer to the enum tag and returns it. Otherwise, returns an `error.InvalidValue`.
        /// TODO optimization taking advantage of most fields being in order
        pub fn readEnum(self: Self, comptime Enum: type, endian: std.builtin.Endian) Error!Enum {
            const E = error{
                /// An integer was read, but it did not match any of the tags in the supplied enum.
                InvalidValue,
            };
            const type_info = @typeInfo(Enum).Enum;
            const tag = try readInt(self, type_info.tag_type, endian);

            inline for (std.meta.fields(Enum)) |field| {
                if (tag == field.value) {
                    return @field(Enum, field.name);
                }
            }

            return E.InvalidValue;
        }

        pub const Self: type = contract.default(.Self, Contractor);

        // TODO: more restrictive errors
        pub const Error: type = anyerror;
    };
}

/// This interface is straightly taken from `std.io.Writer`.
pub fn Writeable(comptime Contractor: type, comptime clauses: type) type {
    return struct {
        const contract = contracts.Contract(Contractor, clauses);

        pub const write = contract.require(.write, fn (Self, []const u8) Error!usize);

        pub fn writeAll(self: Self, bytes: []const u8) Error!void {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try write(self, bytes[index..]);
            }
        }

        pub fn print(self: Self, comptime format: []const u8, args: anytype) Error!void {
            return std.fmt.format(self, format, args);
        }

        pub fn writeByte(self: Self, byte: u8) Error!void {
            const array = [1]u8{byte};
            return writeAll(self, &array);
        }

        pub fn writeByteNTimes(self: Self, byte: u8, n: usize) Error!void {
            var bytes: [256]u8 = undefined;
            @memset(bytes[0..], byte);

            var remaining: usize = n;
            while (remaining > 0) {
                const to_write = @min(remaining, bytes.len);
                try writeAll(self, bytes[0..to_write]);
                remaining -= to_write;
            }
        }

        pub fn writeBytesNTimes(self: Self, bytes: []const u8, n: usize) Error!void {
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try writeAll(self, bytes);
            }
        }

        pub inline fn writeInt(self: Self, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
            var bytes: [@divExact(@typeInfo(T).Int.bits, 8)]u8 = undefined;
            std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
            return writeAll(self, &bytes);
        }

        pub fn writeStruct(self: Self, value: anytype) Error!void {
            // Only extern and packed structs have defined in-memory layout.
            comptime std.debug.assert(@typeInfo(@TypeOf(value)).Struct.layout != .Auto);
            return writeAll(self, std.mem.asBytes(&value));
        }

        // TODO: incompatible interfacing with std when Self isn't Contractor, how to fix?
        const Self: type = if (contract.hasClause(.Self)) misc.compileError(
            "The `Writeable` can't interact well with the `std` when `Self` isn't the " ++
                "contractor! Please use don't pass a `Self` clause and use the interface both " ++
                "from and for `{s}`!",
            .{@typeName(Contractor)},
        ) else Contractor;
        const Error: type = contract.default(.Error, anyerror);
    };
}

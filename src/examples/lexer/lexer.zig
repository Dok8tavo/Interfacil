const std = @import("std");
const ifl = @import("interfacil");

const Tag = enum {
    invalid_character,
    identifier,
    number,
    string,
    dot,
    eql,
    comma,
    add,
    sub,
    mul,
    div,
    mod,
    lt,
    gt,
    lbracket,
    rbracket,
    semicolon,
    colon,
    lparen,
    rparen,
    lcurly,
    rcurly,

    @"const",
    fun,
    @"else",
    @"if",
    let,
    loop,
    @"return",
    then,
    @"var",
    @"while",

    pub usingnamespace ifl.comparison.Equivalent(Tag, struct {
        pub const is_reflexive = false;
        pub fn eq(self: Tag, other: Tag) bool {
            return self != .invalid_character and self == other;
        }
    }, .{});
};

const Token = struct {
    tag: Tag,
    str: []const u8,

    pub usingnamespace ifl.comparison.Equivalent(Token, struct {
        pub fn eq(self: Token, other: Token) bool {
            const is_eq = std.mem.eql(u8, self.str, other.str);
            std.debug.assert(!is_eq or (self.tag == other.tag));
            return is_eq;
        }
    }, .{});

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}: \"{s}\"", .{ @tagName(self.tag), self.str });
    }
};

const Lexer = struct {
    source: ifl.iteration.SlicePeeker(u8, false),

    pub usingnamespace ifl.iteration.Iterable(Lexer, struct {
        pub const Item = Token;
        pub fn next(self: *Lexer) ?Item {
            const first_byte = while (self.source.peek()) |bytes| {
                switch (bytes[0]) {
                    ' ', '\t', '\r', '\n' => self.source.skip(),
                    else => break bytes[0],
                }
            } else return null;
            return switch (first_byte) {
                'a'...'z', 'A'...'Z', '_' => self.nextName(),
                '0'...'9' => self.nextNumber(),
                '#' => self.nextComment(),
                '\"' => self.nextString(),
                else => {
                    defer self.source.skip();
                    return Token{
                        .tag = switch (first_byte) {
                            '.' => .dot,
                            ',' => .comma,
                            '=' => .eql,
                            '+' => .add,
                            '-' => .sub,
                            '*' => .mul,
                            '/' => .div,
                            '%' => .mod,
                            '<' => .lt,
                            '>' => .gt,
                            ';' => .semicolon,
                            ':' => .colon,
                            '(' => .lparen,
                            ')' => .rparen,
                            '[' => .lbracket,
                            ']' => .rbracket,
                            '{' => .lcurly,
                            '}' => .rcurly,
                            else => .invalid_character,
                        },
                        .str = self.source.slice[self.source.index .. self.source.index + 1],
                    };
                },
            };
        }
    }, .{});

    fn tagFromName(name: []const u8) Tag {
        const eq = struct {
            pub fn eq(comptime tag: Tag, str: []const u8) bool {
                return std.mem.eql(u8, @tagName(tag), str);
            }
        }.eq;

        return inline for ([_]Tag{
            .@"const",
            .fun,
            .@"else",
            .@"if",
            .let,
            .loop,
            .@"return",
            .then,
            .@"var",
            .@"while",
        }) |tag| {
            if (eq(tag, name)) break tag;
        } else .identifier;
    }

    fn nextName(self: *Lexer) Token {
        const start = self.source.index;
        while (self.source.peek()) |bytes| switch (bytes[0]) {
            'a'...'z', 'A'...'Z', '_', '0'...'9' => self.source.skip(),
            else => break,
        };

        const name = self.source.slice[start..self.source.index];
        return Token{
            .tag = tagFromName(name),
            .str = name,
        };
    }

    fn nextNumber(self: *Lexer) Token {
        const start = self.source.index;
        while (self.source.peek()) |bytes| switch (bytes[0]) {
            '0'...'9' => self.source.skip(),
            else => break,
        };

        return Token{
            .tag = .number,
            .str = self.source.slice[start..self.source.index],
        };
    }

    fn nextComment(self: *Lexer) Token {
        const start = self.source.index;
        while (self.source.peek()) |bytes| switch (bytes[0]) {
            '\n' => break,
            else => self.source.skip(),
        };

        self.source.skip();
        return Token{
            .tag = .string,
            .str = self.source.slice[start..self.source.index],
        };
    }

    fn nextString(self: *Lexer) Token {
        const start = self.source.index;
        self.source.skip();

        while (self.source.peek()) |bytes| switch (bytes[0]) {
            '\"' => break,
            '\\' => {
                self.source.skip();
                self.source.skip();
            },
            else => self.source.skip(),
        };

        self.source.skip();
        return Token{
            .tag = .string,
            .str = self.source.slice[start..self.source.index],
        };
    }
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer {
        std.process.argsFree(allocator, args);
        _ = gpa.deinit();
    }

    if (args.len < 1) return;
    const arg = args[1];
    const startsWith = struct {
        pub fn call(str: []const u8, comptime with: []const u8) bool {
            return std.mem.startsWith(u8, str, with);
        }
    }.call;

    std.debug.print("args: {s}\n", .{arg});
    var array_list = std.ArrayList(u8).init(allocator);
    const slice = if (startsWith(arg, "--file=")) slice: {
        const filename = arg["--file=".len..];
        const file = try std.fs.cwd().openFile(filename, .{});
        const reader = file.reader();
        try reader.readAllArrayList(&array_list, std.math.maxInt(usize));
        break : slice array_list.items;
    } else if (startsWith(arg, "--source=")) arg["--source=".len..] else {
        std.debug.print("Usage: lexer [--file=<filename> | --source=<source>]\n", .{});
        return;
    };

    defer array_list.deinit();

    var lexer = Lexer{ .source = .{ .slice = slice } };
    while (lexer.next()) |token| {
        std.debug.print("{any}\n", .{token});
    }
}

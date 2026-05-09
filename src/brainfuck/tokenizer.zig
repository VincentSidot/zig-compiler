const std = @import("std");
const helper = @import("types.zig");

const Position = helper.Position;

/// Kinds of Brainfuck source tokens preserved by the tokenizer.
pub const TokenKind = enum {
    move_right,
    move_left,
    increment,
    decrement,
    output,
    input,
    loop_start,
    loop_end,
};

/// Token with source position metadata.
pub const Token = struct {
    kind: TokenKind,
    position: Position,
    index: usize,
};

// pub fn load_file(allocator: std.mem.Allocator, path: []const u8) ![]Token {
//     const source = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
//     defer allocator.free(source);

//     return tokenize(allocator, source);
// }

/// Scans Brainfuck source text and returns one token per significant character.
pub fn tokenize(allocator: std.mem.Allocator, source: []const u8) ![]Token {
    var line: usize = 1;
    var column: usize = 1;

    var count: usize = 0;
    for (source) |ch| {
        if (kind_from_char(ch) != null) {
            count += 1;
        }
    }

    const tokens = try allocator.alloc(Token, count);
    var index: usize = 0;

    for (source, 0..) |ch, source_index| {
        if (ch == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }

        if (kind_from_char(ch)) |kind| {
            tokens[index] = .{
                .kind = kind,
                .position = .{
                    .line = line,
                    .column = column,
                },
                .index = source_index,
            };
            index += 1;
        }
    }

    return tokens;
}

fn kind_from_char(ch: u8) ?TokenKind {
    return switch (ch) {
        '>' => .move_right,
        '<' => .move_left,
        '+' => .increment,
        '-' => .decrement,
        '.' => .output,
        ',' => .input,
        '[' => .loop_start,
        ']' => .loop_end,
        else => null,
    };
}

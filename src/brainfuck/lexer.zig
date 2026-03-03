const std = @import("std");
const helper = @import("types.zig");
const tokenizer = @import("tokenizer.zig");

const Position = helper.Position;
const Token = tokenizer.Token;

pub const LexerKind = union(enum) {
    move: i32,
    add: i32,
    output,
    input,
    loop_start,
    loop_end,
};

pub const Lexer = struct {
    kind: LexerKind,
    pos: Position,
    index: usize,
};

pub fn lex(allocator: std.mem.Allocator, tokens: []const Token) ![]Lexer {
    var lexers = std.ArrayList(Lexer).empty;
    defer lexers.deinit(allocator);

    var i: usize = 0;
    while (i < tokens.len) {
        const token = tokens[i];
        switch (token.kind) {
            .move_left, .move_right => {
                var delta: i32 = 0;
                const pos = token.position;

                while (i < tokens.len) : (i += 1) {
                    delta += switch (tokens[i].kind) {
                        .move_left => -1,
                        .move_right => 1,
                        else => break,
                    };
                }

                if (delta != 0) {
                    try lexers.append(allocator, .{
                        .kind = .{ .move = delta },
                        .pos = pos,
                        .index = lexers.items.len,
                    });
                }
                continue;
            },
            .increment, .decrement => {
                var delta: i32 = 0;
                const pos = token.position;

                while (i < tokens.len) : (i += 1) {
                    delta += switch (tokens[i].kind) {
                        .increment => 1,
                        .decrement => -1,
                        else => break,
                    };
                }

                if (delta != 0) {
                    try lexers.append(allocator, .{
                        .kind = .{ .add = delta },
                        .pos = pos,
                        .index = lexers.items.len,
                    });
                }
                continue;
            },
            .output => {
                try lexers.append(allocator, .{
                    .kind = .output,
                    .pos = token.position,
                    .index = lexers.items.len,
                });
            },
            .input => {
                try lexers.append(allocator, .{
                    .kind = .input,
                    .pos = token.position,
                    .index = lexers.items.len,
                });
            },
            .loop_start => {
                try lexers.append(allocator, .{
                    .kind = .loop_start,
                    .pos = token.position,
                    .index = lexers.items.len,
                });
            },
            .loop_end => {
                try lexers.append(allocator, .{
                    .kind = .loop_end,
                    .pos = token.position,
                    .index = lexers.items.len,
                });
            },
        }

        i += 1;
    }

    return lexers.toOwnedSlice(allocator);
}

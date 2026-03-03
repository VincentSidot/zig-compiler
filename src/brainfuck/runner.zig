const std = @import("std");
const lexer = @import("lexer.zig");
const tokenizer = @import("tokenizer.zig");

pub const Token = tokenizer.Token;
pub const TokenKind = tokenizer.TokenKind;
pub const Lexer = lexer.Lexer;
pub const LexerKind = lexer.LexerKind;

pub const BrainfuckInterpreter = @This();

allocator: std.mem.Allocator,
program: []Lexer,

pub fn load_file(allocator: std.mem.Allocator, path: []const u8) !BrainfuckInterpreter {
    const source = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    defer allocator.free(source);

    return try from_source(allocator, source);
}

pub fn deinit(self: *BrainfuckInterpreter) void {
    self.allocator.free(self.program);
}

pub fn interpret(self: *const BrainfuckInterpreter, mem: []u8) !void {
    if (mem.len == 0) {
        return error.EmptyMemory;
    }

    const stdout = std.fs.File.stdout();
    const stdin = std.fs.File.stdin();

    var ip: usize = 0;
    var ptr: usize = 0;

    while (ip < self.program.len) {
        switch (self.program[ip].kind) {
            .move => |delta| {
                if (delta >= 0) {
                    const step = std.math.cast(usize, delta) orelse return error.MemoryPointerOutOfBounds;
                    const next_ptr = std.math.add(usize, ptr, step) catch return error.MemoryPointerOutOfBounds;
                    if (next_ptr >= mem.len) return error.MemoryPointerOutOfBounds;
                    ptr = next_ptr;
                } else {
                    const step_i64 = -@as(i64, delta);
                    const step = std.math.cast(usize, step_i64) orelse return error.MemoryPointerOutOfBounds;
                    if (step > ptr) return error.MemoryPointerOutOfBounds;
                    ptr -= step;
                }
            },
            .add => |delta| {
                const wrapped_delta: u8 = @intCast(@mod(delta, 256));
                mem[ptr] +%= wrapped_delta;
            },
            .output => {
                const out = [1]u8{mem[ptr]};
                try stdout.writeAll(&out);
            },
            .input => {
                var input = [1]u8{0};
                const bytes_read = try stdin.read(&input);
                mem[ptr] = if (bytes_read == 0) 0 else input[0];
            },
            .loop_start => {
                // If the current cell is zero, jump to the instruction after
                // the matching loop end.
                if (mem[ptr] == 0) {
                    var depth: usize = 1;
                    while (depth > 0) {
                        ip += 1;
                        if (ip >= self.program.len) return error.UnmatchedOpeningBracket;

                        switch (self.program[ip].kind) {
                            .loop_start => depth += 1,
                            .loop_end => depth -= 1,
                            else => {},
                        }
                    }
                }
            },
            .loop_end => {
                // If the current cell is non-zero, jump back to the instruction
                // after the matching loop start.
                if (mem[ptr] != 0) {
                    var depth: usize = 1;
                    while (depth > 0) {
                        if (ip == 0) return error.UnmatchedClosingBracket;
                        ip -= 1;

                        switch (self.program[ip].kind) {
                            .loop_start => depth -= 1,
                            .loop_end => depth += 1,
                            else => {},
                        }
                    }
                }
            },
        }

        ip += 1;
    }
}

fn from_source(allocator: std.mem.Allocator, source: []const u8) !BrainfuckInterpreter {
    const tokens = try tokenizer.tokenize(allocator, source);
    defer allocator.free(tokens);

    const program = try lexer.lex(allocator, tokens);

    return BrainfuckInterpreter{
        .allocator = allocator,
        .program = program,
    };
}

test "brainfuck loop execution" {
    const allocator = std.testing.allocator;
    var interpreter = try from_source(allocator, "++>+++<[->+<]");
    defer interpreter.deinit();

    var memory = [_]u8{ 0, 0 };
    try interpreter.interpret(memory[0..]);

    try std.testing.expectEqual(@as(u8, 0), memory[0]);
    try std.testing.expectEqual(@as(u8, 5), memory[1]);
}

test "unmatched opening bracket returns error at interpret time" {
    const allocator = std.testing.allocator;
    var interpreter = try from_source(allocator, "[++");
    defer interpreter.deinit();

    var memory = [_]u8{0};
    try std.testing.expectError(error.UnmatchedOpeningBracket, interpreter.interpret(memory[0..]));
}

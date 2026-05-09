//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

test {
    std.testing.refAllDecls(@import("./encoder/lib.zig"));
    std.testing.refAllDecls(@import("./brainfuck/lib.zig"));
    std.testing.refAllDecls(@import("./brainfuck/runner.zig"));
    std.testing.refAllDecls(@import("./brainfuck/tokenizer.zig"));
    std.testing.refAllDecls(@import("./asm/lib.zig"));
    std.testing.refAllDecls(@import("./elf/lib.zig"));
    std.testing.refAllDecls(@import("./tests/loader.zig"));
}

//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

test {
    std.testing.refAllDecls(@import("./backend/encoder/lib.zig"));
    std.testing.refAllDecls(@import("./frontend/brainfuck/lib.zig"));
    std.testing.refAllDecls(@import("./frontend/brainfuck/runner.zig"));
    std.testing.refAllDecls(@import("./frontend/brainfuck/tokenizer.zig"));
    std.testing.refAllDecls(@import("./backend/engine/lib.zig"));
    std.testing.refAllDecls(@import("./backend/elf/lib.zig"));
    std.testing.refAllDecls(@import("./tests/loader.zig"));
}

//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

test {
    std.testing.refAllDecls(@import("./encoder/lib.zig"));
    std.testing.refAllDecls(@import("./brainfuck/lib.zig"));
    std.testing.refAllDecls(@import("./brainfuck/runner.zig"));
    std.testing.refAllDecls(@import("./brainfuck/tokenizer.zig"));
    std.testing.refAllDecls(@import("./asm/op.zig"));
    std.testing.refAllDecls(@import("./asm/ir.zig"));
    std.testing.refAllDecls(@import("./asm/layout.zig"));
    std.testing.refAllDecls(@import("./asm/engine.zig"));
    std.testing.refAllDecls(@import("./asm/helper/add.zig"));
    std.testing.refAllDecls(@import("./asm/helper/bit.zig"));
    std.testing.refAllDecls(@import("./asm/helper/branch.zig"));
    std.testing.refAllDecls(@import("./asm/helper/cmp.zig"));
    std.testing.refAllDecls(@import("./asm/helper/lea.zig"));
    std.testing.refAllDecls(@import("./asm/helper/mov.zig"));
    std.testing.refAllDecls(@import("./asm/helper/ret.zig"));
    std.testing.refAllDecls(@import("./asm/helper/single.zig"));
    std.testing.refAllDecls(@import("./asm/helper/sub.zig"));
    std.testing.refAllDecls(@import("./asm/helper/syscall.zig"));
    std.testing.refAllDecls(@import("./asm/helper/xor.zig"));
    std.testing.refAllDecls(@import("./asm/tests.zig"));
    std.testing.refAllDecls(@import("./tests/loader.zig"));
}

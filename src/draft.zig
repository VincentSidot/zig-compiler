// Standard library
const std = @import("std");
const log = std.log;

// Loader
const loader = @import("loader.zig");

// Encoder
const encoder = @import("encoder/lib.zig");
const op = encoder.opcode;
const reg = encoder.register;
const extractBits = encoder.extractBits;
const RegisterMemory64 = encoder.RegisterMemory_64;

// Assembly engine
const Engine = @import("asm/engine.zig");

fn generate_code(allocator: std.mem.Allocator) ![]u8 {
    var writter_alloc = std.Io.Writer.Allocating.init(allocator);
    defer writter_alloc.deinit();

    const writer = &writter_alloc.writer;
    var written: usize = 0;

    // Let's define a simple asm program.
    //
    // // C implementation (not working for n=0 & n=1)
    // fib(n) {
    //    long a = 0;
    //    long b = 1;
    //
    //    for (long i = 2; i < n - 1; i++) {
    //       long temp = a + b;
    //       a = b;
    //       b = temp;
    //    }
    //
    //    return b;
    // }
    //
    // // Assembly implementation
    // push rpb                      ; save the base pointer
    // mov rbp, rsp                  ; set the base pointer to the current stack pointer
    // sub rsp, 16                   ; allocate space for long a and long b
    // mov [rbp - 8], 0              ; a = 0
    // mov [rbp - 16], 1             ; b = 1
    // xor rax, rax                  ; i = 0
    // dec rdi                       ; n-- (we will compare i with n-1 to avoid the edge case of n=0 and n=1)
    // loop_start:
    //  cmp rax, rdi                 ; compare i with n (n is in --rdi)
    //  jge loop_end                 ; if i >= n, jump to loop_end
    //  add rax, 1                   ; i++
    //  mov r8, [rbp - 8]            ; r8 = a
    //  add r8, [rbp - 16]           ; r8 = a + b
    //  mov r9, [rbp - 16]           ; r9 = b
    //  mov [rbp - 8], r9            ; a = b
    //  mov [rbp - 16], r8           ; b = a + b
    //  jmp loop_start               ; repeat the loop
    // loop_end:
    // mov rax, [rbp - 16]           ; move the result (b) into rax
    // add rsp, 16                   ; deallocate the space for a and b
    // pop rbp                       ; restore the base pointer
    // ret                           ; return from the function

    const rm_a: RegisterMemory64 = .{
        .mem = .{
            .baseIndex64 = .{
                .disp = -8,
                .base = .RBP,
            },
        },
    };

    const rm_b: RegisterMemory64 = .{
        .mem = .{
            .baseIndex64 = .{
                .disp = -16,
                .base = .RBP,
            },
        },
    };

    written += try op.push.r64(writer, .RBP);
    written += try op.mov.r64_r64(writer, .RBP, .RSP);
    written += try op.sub.r64_imm32(writer, .RSP, 16);
    written += try op.mov.rm64_imm32(writer, rm_a, 0);
    written += try op.mov.rm64_imm32(writer, rm_b, 1);
    written += try op.bitxor.r64_rm64(
        writer,
        .RAX,
        .{ .reg = .RAX },
    );
    written += try op.dec.rm64(writer, .{ .reg = .RDI });
    const loop_start_addr = written;
    written += try op.cmp.r64_rm64(
        writer,
        .RAX,
        .{ .reg = .RDI },
    );
    const jg_placeholder_offset = written;
    written += try op.jcc.rel32(writer, .ge, 0xDEAD); // Placeholder for loop end address
    written += try op.inc.rm64(writer, .{ .reg = .RAX });
    written += try op.mov.r64_rm64(writer, .R8, rm_a);
    written += try op.add.r64_rm64(writer, .R8, rm_b);
    written += try op.mov.r64_rm64(writer, .R9, rm_b);
    written += try op.mov.rm64_r64(writer, rm_a, .R9);
    written += try op.mov.rm64_r64(writer, rm_b, .R8);
    const jmp_back_offset = written;
    written += try op.jmp.rel32(writer, 0xDEAD); // Placeholder for loop start address
    const loop_end_addr = written;
    written += try op.mov.r64_rm64(writer, .RAX, rm_b);
    written += try op.add.r64_imm32(writer, .RSP, 16);
    written += try op.pop.r64(writer, .RBP);
    written += try op.ret(writer, .Default);

    // Backpatch the jump offsets.
    try op.jcc.patch_rel32(writer.buffer, jg_placeholder_offset, loop_end_addr);
    try op.jmp.patch_rel32(writer.buffer, jmp_back_offset, loop_start_addr);

    log.info("Generated {d} bytes of machine code", .{written});

    const bytecode = try writter_alloc.toOwnedSlice();
    return bytecode;
}

fn generate_code_2(allocator: std.mem.Allocator) ![]u8 {
    var engine = Engine.init(allocator);
    errdefer engine.deinit();

    const rm_a: Engine.Arg = .{
        .mem = .{
            .size = .qword,
            .reg = .rbp,
            .disp = -8,
        },
    };
    const rm_b: Engine.Arg = .{
        .mem = .{
            .size = .qword,
            .reg = .rbp,
            .disp = -16,
        },
    };

    const loop_start = try engine.label();
    const loop_end = try engine.label();

    try engine.push(.rbp);
    try engine.mov(.rbp, .rsp);
    try engine.sub(.rsp, Engine.Arg.immediate(16));
    try engine.mov(rm_a, Engine.Arg.immediate(0));
    try engine.mov(rm_b, Engine.Arg.immediate(1));
    try engine.xor(.rax, .rax);
    try engine.dec(.rdi);
    try engine.bind(loop_start);
    try engine.cmp(.rax, .rdi);
    try engine.jcc(.ge, .{ .label = loop_end });
    try engine.inc(.rax);
    try engine.mov(.r8, rm_a);
    try engine.add(.r8, rm_b);
    try engine.mov(.r9, rm_b);
    try engine.mov(rm_a, .r9);
    try engine.mov(rm_b, .r8);
    try engine.jmp(.{ .label = loop_start });
    try engine.bind(loop_end);
    try engine.mov(.rax, rm_b);
    try engine.add(.rsp, Engine.Arg.immediate(16));
    try engine.pop(.rbp);
    try engine.ret();

    const bytecode = try engine.finalize();

    log.info("Generated {d} bytes of machine code", .{bytecode.len});

    return bytecode;
}

fn fib(n: u64) u64 {
    if (n <= 1) {
        return n;
    }

    var a: u64 = 0;
    var b: u64 = 1;

    for (0..n - 1) |_| {
        const temp = a + b;
        a = b;
        b = temp;
    }

    return b;
}

pub fn run_draft() !void {
    const allocator = std.heap.smp_allocator;

    const bytecode = try generate_code_2(allocator);
    defer allocator.free(bytecode);

    // Now we have the machine code for our hello world program in the writer's buffer.
    const program = try loader.load_from_memory(
        fn (u64) callconv(.c) u64,
        bytecode,
    );

    log.info("Executing the generated machine code...", .{});

    // Execute the program.
    const n: u64 = 10;
    const result = program.f()(n);
    const expected = fib(n);

    if (result != expected) {
        log.err("Unexpected result: got {d}, expected {d}", .{ result, expected });
    } else {
        log.info("Execution successful: fib({d}) = {d}", .{ n, result });
    }

    log.info("Execution finished.", .{});
}

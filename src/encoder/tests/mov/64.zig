const common = @import("common.zig");

const mov = common.mov;
const validate = common.validate;
const RegisterIndex_64 = common.RegisterIndex_64;

test "MOV 64 bit registers" {
    // 48 89 c8                mov    rax,rcx
    // 48 89 d3                mov    rbx,rdx
    // 48 89 fe                mov    rsi,rdi
    // 48 89 c7                mov    rdi,rax

    try validate(RegisterIndex_64, RegisterIndex_64, "RAX, RCX", &.{ 0x48, 0x89, 0xC8 }, mov.rm64_r64, .RAX, .RCX);
    try validate(RegisterIndex_64, RegisterIndex_64, "RBX, RDX", &.{ 0x48, 0x89, 0xD3 }, mov.rm64_r64, .RBX, .RDX);
    try validate(RegisterIndex_64, RegisterIndex_64, "RSI, RDI", &.{ 0x48, 0x89, 0xFE }, mov.rm64_r64, .RSI, .RDI);
    try validate(RegisterIndex_64, RegisterIndex_64, "RDI, RAX", &.{ 0x48, 0x89, 0xC7 }, mov.rm64_r64, .RDI, .RAX);
}

test "MOV 64 bit registers extended" {
    // 49 89 c0                mov    r8,rax
    // 4c 89 c0                mov    rax,r8
    // 4d 89 c8                mov    r8,r9
    // 4d 89 da                mov    r10,r11
    // 4d 89 c7                mov    r15,r8
    // 49 89 f8                mov    r8,rdi
    // 4c 89 c7                mov    rdi,r8
    // 4d 89 ec                mov    r12,r13

    try validate(RegisterIndex_64, RegisterIndex_64, "R8, RAX", &.{ 0x49, 0x89, 0xC0 }, mov.rm64_r64, .R8, .RAX);
    try validate(RegisterIndex_64, RegisterIndex_64, "RAX, R8", &.{ 0x4C, 0x89, 0xC0 }, mov.rm64_r64, .RAX, .R8);
    try validate(RegisterIndex_64, RegisterIndex_64, "R8, R9", &.{ 0x4D, 0x89, 0xC8 }, mov.rm64_r64, .R8, .R9);
    try validate(RegisterIndex_64, RegisterIndex_64, "R10, R11", &.{ 0x4D, 0x89, 0xDA }, mov.rm64_r64, .R10, .R11);
    try validate(RegisterIndex_64, RegisterIndex_64, "R15, R8", &.{ 0x4D, 0x89, 0xC7 }, mov.rm64_r64, .R15, .R8);
    try validate(RegisterIndex_64, RegisterIndex_64, "R8, RDI", &.{ 0x49, 0x89, 0xF8 }, mov.rm64_r64, .R8, .RDI);
    try validate(RegisterIndex_64, RegisterIndex_64, "RDI, R8", &.{ 0x4C, 0x89, 0xC7 }, mov.rm64_r64, .RDI, .R8);
    try validate(RegisterIndex_64, RegisterIndex_64, "R12, R13", &.{ 0x4D, 0x89, 0xEC }, mov.rm64_r64, .R12, .R13);
}

test "MOV 64 bit immediate to register" {
    // 48 c7 c7 ff 00 00 00             mov    rdi,0xff
    // 48 c7 c0 0c 00 00 00             mov    rax,0xc
    // 48 c7 c2 f4 ff ff ff             mov    rdx,0xfffffffffffffff4
    // 48 be ff ff ff ff 00 00 00 00    movabs rsi,0xffffffff
    // 48 b8 bc 9a 78 56 34 12 ff ef    movabs rax,0xefff_1234_5678_9ABC

    try validate(RegisterIndex_64, u64, "RDI, 0xFF", &.{ 0x48, 0xC7, 0xC7, 0xFF, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RDI, 0x0000_0000_0000_00FF);
    try validate(RegisterIndex_64, u64, "RAX, 0x0C", &.{ 0x48, 0xC7, 0xC0, 0x0C, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RAX, 0x0000_0000_0000_000C);
    try validate(RegisterIndex_64, u64, "RDX, -12", &.{ 0x48, 0xC7, 0xC2, 0xF4, 0xFF, 0xFF, 0xFF }, mov.r64_imm64_auto, .RDX, 0xFFFF_FFFF_FFFF_FFF4);
    try validate(RegisterIndex_64, u64, "RSI, 0xFFFF_FFFF", &.{ 0x48, 0xBE, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RSI, 0x0000_0000_FFFF_FFFF);
    try validate(RegisterIndex_64, u64, "RAX, 0xEFFF_1234_1234_1234", &.{ 0x48, 0xB8, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12, 0xFF, 0xEF }, mov.r64_imm64_auto, .RAX, 0xEFFF_1234_5678_9ABC);
}

test "MOV 64 bit immediate to register extended" {
    // 49 b8 34 12 34 12 34 12 34 12    movabs r8,0x1234123412341234
    // 49 bf 34 12 34 12 34 12 ff ef    movabs r15,0xefff123412341234
    // 49 c7 c4 00 00 00 00             mov    r12,0x0
    // 49 bd f0 de bc 9a 78 56 34 12    movabs r13,0x1234_5678_9abc_def0

    try validate(RegisterIndex_64, u64, "R8, 0x1234_1234_1234_1234", &.{ 0x49, 0xB8, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12 }, mov.r64_imm64_auto, .R8, 0x1234_1234_1234_1234);
    try validate(RegisterIndex_64, u64, "R15, 0xEFFF_1234_1234_1234", &.{ 0x49, 0xBF, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0xFF, 0xEF }, mov.r64_imm64_auto, .R15, 0xEFFF_1234_1234_1234);
    try validate(RegisterIndex_64, u64, "R12, 0x0", &.{ 0x49, 0xC7, 0xC4, 0x00, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .R12, 0x0000_0000_0000_0000);
    try validate(RegisterIndex_64, u64, "R13, 0xF0F0_F0F0_F0F0_F000", &.{ 0x49, 0xBD, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12 }, mov.r64_imm64_auto, .R13, 0x1234_5678_9ABC_DEF0);
}

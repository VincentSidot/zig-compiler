const common = @import("common.zig");

const mov = common.mov;
const validate = common.validate;
const RegisterIndex_32 = common.RegisterIndex_32;

test "MOV 32 bit registers" {
    // 89 c8                   mov    eax,ecx
    // 89 d3                   mov    ebx,edx
    // 89 fe                   mov    esi,edi
    // 89 c7                   mov    edi,eax

    try validate(RegisterIndex_32, RegisterIndex_32, "EAX, ECX", &.{ 0x89, 0xC8 }, mov.rm32_r32, .EAX, .ECX);
    try validate(RegisterIndex_32, RegisterIndex_32, "EBX, EDX", &.{ 0x89, 0xD3 }, mov.rm32_r32, .EBX, .EDX);
    try validate(RegisterIndex_32, RegisterIndex_32, "ESI, EDI", &.{ 0x89, 0xFE }, mov.rm32_r32, .ESI, .EDI);
    try validate(RegisterIndex_32, RegisterIndex_32, "EDI, EAX", &.{ 0x89, 0xC7 }, mov.rm32_r32, .EDI, .EAX);
}

test "MOV 32 bit registers extended" {
    // 41 89 c0                mov    r8d,eax
    // 44 89 cb                mov    ebx,r9d
    // 45 89 da                mov    r10d,r11d
    // 45 89 c7                mov    r15d,r8d

    try validate(RegisterIndex_32, RegisterIndex_32, "R8D, EAX", &.{ 0x41, 0x89, 0xC0 }, mov.rm32_r32, .R8D, .EAX);
    try validate(RegisterIndex_32, RegisterIndex_32, "EBX, R9D", &.{ 0x44, 0x89, 0xCB }, mov.rm32_r32, .EBX, .R9D);
    try validate(RegisterIndex_32, RegisterIndex_32, "R10D, R11D", &.{ 0x45, 0x89, 0xDA }, mov.rm32_r32, .R10D, .R11D);
    try validate(RegisterIndex_32, RegisterIndex_32, "R15D, R8D", &.{ 0x45, 0x89, 0xC7 }, mov.rm32_r32, .R15D, .R8D);
}

test "MOV 32bit immediate to register" {
    // 41 b8 34 12 34 12       mov    r8d,0x12_34_12_34
    // 41 bf ef ef ef ef       mov    r15d,0xef_ef_ef_ef
    // 41 bc 00 00 00 00       mov    r12d,0x00_00_00_00
    // 41 bd 0f 0f 0f 0f       mov    r13d,0x0f_0f_0f_0f
    // 41 b9 ff 00 00 00       mov    r9d,0x00_00_00_ff

    try validate(RegisterIndex_32, u32, "R8D, 0x12_34_12_34", &.{ 0x41, 0xB8, 0x34, 0x12, 0x34, 0x12 }, mov.r32_imm32, .R8D, 0x12341234);
    try validate(RegisterIndex_32, u32, "R15D, 0xEF_EF_EF_EF", &.{ 0x41, 0xBF, 0xEF, 0xEF, 0xEF, 0xEF }, mov.r32_imm32, .R15D, 0xEFEFEFEF);
    try validate(RegisterIndex_32, u32, "R12D, 0x00_00_00_00", &.{ 0x41, 0xBC, 0x00, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R12D, 0x00000000);
    try validate(RegisterIndex_32, u32, "R13D, 0x0F_0F_0F_0F", &.{ 0x41, 0xBD, 0x0F, 0x0F, 0x0F, 0x0F }, mov.r32_imm32, .R13D, 0x0F0F0F0F);
    try validate(RegisterIndex_32, u32, "R9D, 0x00_00_00_FF", &.{ 0x41, 0xB9, 0xFF, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R9D, 0x000000FF);
}

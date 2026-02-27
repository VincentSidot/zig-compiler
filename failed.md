# Previously Failed Tester Validations (Resolved)

As of 2026-02-27, the prior compile-time blocker is no longer reproducing.

Validation checks:
- `zig run tester.zig` now succeeds and disassembles output correctly.
- `zig build test` passes, including MOV immediate coverage across 16/32/64-bit register-memory forms.

The following variants are no longer blocked:
- `mov.rm16_imm16` with `DI, 0xBEEF`
- `mov.rm32_imm32` with `EDI, 0x89AB_CDEF`
- `mov.rm64_imm32` with `RDI, 0x89AB_CDEF`

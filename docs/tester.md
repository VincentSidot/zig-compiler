# How to setup test for the instruction

## Step 1

Use the `tester.zig` helper zig function, modify `inst_to_encode` function to mark the instruction you want to test, for example:

```zig
// Here we define the instruction that we want to encode and test.
fn inst_to_encode(writer: *std.Io.Writer) EncodingError!void {
    const mov = encoder.mov;
    _ = try mov.rm32_imm32(writer, .{ .reg = .EDI }, 0x89AB_CDEF);
}
```

Then run the tester with the command:

```bash
> zig run tester.zig
  0:	c7 c7 ef cd ab 89    	mov    edi,0x89abcdef
```

This will generate a file with encoded instruction, then parse it with objdump to ensure that the instruction is correctly encoded.

## Step 2

Ensure that the instruction is correctly decoded by objdump, and if this is okay. Update the tests files from `src/encoder/tests` to 
include the new instruction, with the expected encoding, and run the tests to ensure that the instruction is correctly encoded and decoded.

If the instruction is not correctly encoded or decoded, you need to add the failed instruction into the `failed.md` file.

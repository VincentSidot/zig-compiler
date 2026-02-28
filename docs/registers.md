# Intel x64 registers

## Base registers

| 64bit | 32bit | 16bit | 8bit |
| ----- | ----- | ----- | ---- |
| RAX   | EAX   | AX    | AL   |
| RBX   | EBX   | BX    | BL   |
| RCX   | ECX   | CX    | CL   |
| RDX   | EDX   | DX    | DL   |
| RSP   | ESP   | SP    | SPL  |
| RBP   | EBP   | BP    | BPL  |
| RSI   | ESI   | SI    | SIL  |
| RDI   | EDI   | DI    | DIL  |
| R8    | R8D   | R8W   | R8B  |
| R9    | R9D   | R9W   | R9B  |
| R10   | R10D  | R10W  | R10B |
| R11   | R11D  | R11W  | R11B |
| R12   | R12D  | R12W  | R12B |
| R13   | R13D  | R13W  | R13B |
| R14   | R14D  | R14W  | R14B |
| R15   | R15D  | R15W  | R15B |

| Register | Description       |
| -------- | ----------------- |
| RAX      | Accumulator       |
| RBX      | Base Register     |
| RCX      | Counter Register  |
| RDX      | Data Register     |
| RSP      | Stack Pointer     |
| RBP      | Base Pointer      |
| RSI      | Source Index      |
| RDI      | Destination Index |
| R8-R15   | General Purpose   |

### Special 8-bit high byte registers

The x64 architecture also includes special 8-bit high byte registers that can be used for certain operations. These registers are the high byte of the corresponding 16-bit registers.

| Register | Description     |
| -------- | --------------- |
| AH       | High byte of AX |
| BH       | High byte of BX |
| CH       | High byte of CX |
| DH       | High byte of DX |

## Special registers

Special registers are used for specific purposes in the CPU, such as controlling the flow of execution and managing the state of the processor.

| Register | Description         |
| -------- | ------------------- |
| RIP      | Instruction Pointer |
| RFLAGS   | Flags Register      |

## Segment registers

Segment registers are used to hold the segment selectors for different segments in memory. In x64 architecture, segmentation is largely unused, but the segment registers still exist for compatibility reasons.

| Register | Description   |
| -------- | ------------- |
| CS       | Code Segment  |
| DS       | Data Segment  |
| ES       | Extra Segment |
| FS       | FS Segment    |
| GS       | GS Segment    |

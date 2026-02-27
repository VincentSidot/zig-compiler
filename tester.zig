const std = @import("std");

const helper = @import("src/helper.zig");
const printf = helper.printf;
const eprintf = helper.eprintf;

const encoder = @import("src/encoder/lib.zig");
const EncodingError = encoder.EncodingError;
const mov = encoder.mov;

const default_bin_path: []const u8 = "./temp/out.bin";

const Tester = struct {
    path: []const u8,

    const encoderFn = fn (writer: *std.io.Writer) EncodingError!void;

    // Generate a binary file with the provided encoding function.
    fn generate(self: *const Tester, enconding: *const encoderFn) !void {
        const cwd = std.fs.cwd();
        const path = self.path;

        // Extract the directory part from the path.
        const dirPath = std.fs.path.dirname(path) orelse {
            // No directory part, so we can skip this step.
            return;
        };
        try cwd.makePath(dirPath);

        const file = try cwd.createFile(path, .{ .truncate = true });
        defer file.close();

        var buffer: [1024]u8 = undefined;

        var writer_interface = file.writer(&buffer);

        var writer = &writer_interface.interface;
        defer {
            writer.flush() catch |err| {
                eprintf("Failed to flush writer: {}\n", .{err});
            };
        }

        try enconding(writer);
    }

    fn handle_termination(resp: std.process.Child.Term) !void {
        switch (resp) {
            .Exited => |code| {
                if (code != 0) {
                    eprintf("objdump exited with code: {}\n", .{code});
                    return error.InvalidExitCode;
                }
            },
            .Signal => |sig| {
                eprintf("Killed by signal: {}\n", .{sig});
                return error.KilledBySignal;
            },
            .Stopped => |sig| {
                eprintf("Stopped by signal: {}\n", .{sig});
                return error.StoppedBySignal;
            },
            .Unknown => {
                eprintf("Unknown termination\n", .{});
                return error.UnknownTermination;
            },
        }
    }

    // Run
    fn dump(self: *const Tester) !void {
        const allocator = std.heap.smp_allocator;

        const argv = [_][]const u8{
            "/usr/bin/objdump",
            "-D", // Disassemble all sections of the binary.
            "-b", "binary", // Indicate that the input is a raw binary file.
            "-mi386:x86-64", // Specify the architecture for correct disassembly.
            "-M",      "intel", // Use Intel syntax for better readability.
            self.path,
        };

        var child = std.process.Child.init(&argv, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Inherit; // Inherit stderr to see any errors from objdump.

        var child_has_been_waited = false;

        try child.spawn();
        errdefer {
            if (!child_has_been_waited) {
                if (child.wait()) |resp| {
                    _ = Tester.handle_termination(resp) catch |err| {
                        eprintf("Error handling child termination: {}\n", .{err});
                    };
                } else |err| {
                    eprintf("Failed to wait for child process: {}\n", .{err});
                }
            }
        }

        const child_stdout = child.stdout orelse {
            eprintf("Failed to capture stdout from objdump\n", .{});
            return error.CaptureStdoutFailed;
        };

        const stdout_data = try child_stdout.readToEndAlloc(allocator, 1024 * 1024); // 1MB buffer size
        defer allocator.free(stdout_data);

        // Find out addr of '<.data>:' in the objdump output.
        const data_section_str = "<.data>:";
        const data_section_index = std.mem.indexOf(u8, stdout_data, data_section_str) orelse {
            eprintf("Failed to find data section in objdump output\n", .{});
            return error.DataSectionNotFound;
        };

        // +1 for the newline after the section header.
        const data_section_skip = data_section_str.len + 1;

        // Print the captured stdout from objdump.
        const parent_stdout = std.fs.File.stdout();
        parent_stdout.writeAll(stdout_data[data_section_index + data_section_skip ..]) catch |err| {
            eprintf("Failed to write objdump output to stdout: {}\n", .{err});
        };

        child_has_been_waited = true;
        const response = try child.wait();
        try Tester.handle_termination(response);
    }
};

const Disassembler = struct {};

pub fn main() !void {
    const inst: Tester = .{
        .path = default_bin_path,
    };

    try inst.generate(inst_to_encode);
    try inst.dump();
}

// Here we define the instruction that we want to encode and test.
fn inst_to_encode(writer: *std.io.Writer) EncodingError!void {
    // BUG: rm64_imm32 with RIP-relative memory is missing REX.W and decodes as DWORD PTR.
    _ = try mov.rm64_imm32(writer, .{ .mem = .{ .ripRelative = 0x10 } }, 0x1122_3344);
    _ = try mov.rm32_imm32(writer, .{ .mem = .{ .ripRelative = 0x10 } }, 0x1122_3344);

    _ = try mov.rm64_imm32(writer, .{ .mem = .{ .ripRelative = 0x1234 } }, 0x89AB_CDEF);

    // Works: rm64_imm32 with register destination emits REX.W and is 64-bit.
    _ = try mov.rm64_imm32(writer, .{ .reg = .RAX }, 0x1122_3344);

    // Works: mov r64, imm64 form (B8+rd) explicitly emits a 64-bit immediate move.
    _ = try mov.r64_imm64(writer, .RAX, 0x0000_0000_1122_3344);

    // Works: auto form picks sign-extended imm32-to-r64 (still with REX.W for register destination).
    _ = try mov.r64_imm64_auto(writer, .RAX, 0x0000_0000_1122_3344);
}

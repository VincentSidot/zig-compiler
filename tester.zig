const std = @import("std");

const helper = @import("src/helper.zig");
const printf = helper.printf;
const eprintf = helper.eprintf;

const encoder = @import("src/encoder/lib.zig");
const EncodingError = encoder.EncodingError;

const default_bin_path: []const u8 = "../temp/out.bin";

const Tester = struct {
    path: []const u8,

    const encoderFn = fn (writer: *std.Io.Writer) EncodingError!void;

    // Generate a binary file with the provided encoding function.
    fn generate(self: *const Tester, io: std.Io, enconding: *const encoderFn) !void {
        const cwd = std.Io.Dir.cwd();
        const path = self.path;

        // Extract the directory part from the path.
        const dirPath = std.fs.path.dirname(path) orelse {
            // No directory part, so we can skip this step.
            return;
        };
        try std.Io.Dir.createDirPath(cwd, io, dirPath);

        const file = try std.Io.Dir.createFile(cwd, io, path, .{ .truncate = true });
        defer file.close(io);

        var buffer: [1024]u8 = undefined;

        var writer_interface = file.writer(io, &buffer);

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
            .exited => |code| {
                if (code != 0) {
                    eprintf("objdump exited with code: {}\n", .{code});
                    return error.InvalidExitCode;
                }
            },
            .signal => |sig| {
                eprintf("Killed by signal: {}\n", .{sig});
                return error.KilledBySignal;
            },
            .stopped => |sig| {
                eprintf("Stopped by signal: {}\n", .{sig});
                return error.StoppedBySignal;
            },
            .unknown => {
                eprintf("Unknown termination\n", .{});
                return error.UnknownTermination;
            },
        }
    }

    // Run
    fn dump(self: *const Tester, io: std.Io) !void {
        const allocator = std.heap.smp_allocator;

        const argv = [_][]const u8{
            "/usr/bin/objdump",
            "-D", // Disassemble all sections of the binary.
            "-b", "binary", // Indicate that the input is a raw binary file.
            "-mi386:x86-64", // Specify the architecture for correct disassembly.
            "-M",      "intel", // Use Intel syntax for better readability.
            self.path,
        };

        // var child = std.process.Child.init(&argv, allocator);
        var child = try std.process.spawn(io, .{
            .argv = &argv,
            .stdout = .pipe,
            .stderr = .inherit,
        });

        var child_has_been_waited = false;
        errdefer {
            if (!child_has_been_waited) {
                if (child.wait(io)) |resp| {
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

        var file_reader = child_stdout.reader(io, &.{});
        const stdout_data = try file_reader.interface.allocRemaining(allocator, .limited(1024 * 1024));
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
        const parent_stdout = std.Io.File.stdout();
        parent_stdout.writeStreamingAll(io, stdout_data[data_section_index + data_section_skip ..]) catch |err| {
            eprintf("Failed to write objdump output to stdout: {}\n", .{err});
        };

        child_has_been_waited = true;
        const response = try child.wait(io);
        try Tester.handle_termination(response);
    }
};

const Disassembler = struct {};

pub fn main(init: std.process.Init) !void {
    const inst: Tester = .{
        .path = default_bin_path,
    };

    try inst.generate(init.io, inst_to_encode);
    try inst.dump(init.io);
}

// Here we define the instruction that we want to encode and test.
fn inst_to_encode(writer: *std.Io.Writer) EncodingError!void {
    const pop = encoder.opcode.pop;

    _ = try pop.r16(writer, .R9W);
    _ = try pop.r32(writer, .R9D);
    _ = try pop.r64(writer, .R9);

    _ = try pop.rm16(writer, .{ .reg = .R9W });
    _ = try pop.rm32(writer, .{ .reg = .R9D });
    _ = try pop.rm64(writer, .{ .reg = .R9 });

    _ = try pop.rm16(
        writer,
        .{ .mem = .{ .baseIndex32 = .{
            .base = null,
            .index = null,
            .disp = 0x1234,
        } } },
    );
    _ = try pop.rm32(
        writer,
        .{ .mem = .{ .baseIndex32 = .{
            .base = null,
            .index = null,
            .disp = 0x1234,
        } } },
    );
    _ = try pop.rm64(
        writer,
        .{ .mem = .{ .baseIndex32 = .{
            .base = null,
            .index = null,
            .disp = 0x1234,
        } } },
    );
}

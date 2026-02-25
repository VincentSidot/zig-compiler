const std = @import("std");

const system = std.os.linux;
const log = std.log;

const RemoteFunction = fn ([*c]const u8) callconv(.c) void;

const FunctionLoader = struct {
    size: usize,
    ptr: *const RemoteFunction,

    pub fn call(self: *const FunctionLoader, input: [*c]const u8) void {
        self.ptr(input);

        // asm volatile ("call *%[func]"
        //     :
        //     : [func] "r" (self.ptr),
        //       [input] "{rdi}" (input),
        //     : .{
        //       .rax = true,
        //       .rcx = true,
        //       .rdi = true,
        //       .rsi = true,
        //     });
    }

    pub fn deinit(self: FunctionLoader) void {
        const ptr: [*]const u8 = @ptrCast(self.ptr);
        _ = system.munmap(ptr, self.size);
    }
};

pub fn load(path: []const u8) !FunctionLoader {
    const PROT = system.PROT;

    log.debug("Loading function from file: {s}", .{path});

    const file = try std.fs.cwd().openFile(
        path,
        .{ .mode = .read_only },
    );
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size == 0) {
        return error.EmptyFile;
    }

    const raw_buffer = system.mmap(
        null,
        file_size,
        PROT.READ | PROT.WRITE | PROT.EXEC,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    if (raw_buffer == -1) {
        return error.MmapFailed;
    }

    const buffer_ptr: [*]u8 = @ptrFromInt(raw_buffer);
    errdefer {
        _ = system.munmap(
            buffer_ptr,
            file_size,
        );
    }

    const buffer: []u8 = buffer_ptr[0..file_size];

    _ = try file.readAll(buffer);

    // Dump the loaded bytes for debugging purposes
    log.debug("Loaded {d} bytes from file", .{file_size});

    const mprotect_result = system.mprotect(
        buffer_ptr,
        file_size,
        PROT.EXEC | PROT.READ | PROT.WRITE,
    );

    if (mprotect_result != 0) {
        return error.MprotectFailed;
    }

    const loader = FunctionLoader{ .size = file_size, .ptr = @ptrCast(buffer_ptr) };

    log.debug("Successfully loaded function: size = {d} bytes", .{loader.size});

    return loader;
}

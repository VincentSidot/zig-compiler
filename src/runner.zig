const std = @import("std");

const system = std.os.linux;
const log = std.log;

const RemoteFunction = fn (*const u8, usize) callconv(.c) void;

const FunctionLoader = struct {
    size: usize,
    ptr: *const RemoteFunction,

    pub fn call(self: *const FunctionLoader, input: []const u8) void {
        const raw_ptr: *const u8 = @ptrCast(input.ptr);
        const raw_size: usize = input.len;

        self.ptr(raw_ptr, raw_size);

        // Fashion way to run the code :D
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

fn apply_protect(data: []const u8) !FunctionLoader {
    const PROT = system.PROT;

    // Change the memory protection to allow execution
    const mprotect_result = system.mprotect(
        data.ptr,
        data.len,
        PROT.EXEC | PROT.READ,
    );

    if (mprotect_result != 0) {
        return error.MprotectFailed;
    }

    const loader = FunctionLoader{
        .size = data.len,
        .ptr = @ptrCast(data.ptr),
    };

    log.debug(
        "Successfully loaded function: size = {d} bytes",
        .{loader.size},
    );

    return loader;
}

pub fn load_from_memory(data: []const u8) !FunctionLoader {
    const PROT = system.PROT;

    log.debug("Loading function from memory: {d} bytes", .{data.len});

    const file_size: usize = data.len;
    if (file_size == 0) {
        return error.EmptyData;
    }

    const raw_buffer = system.mmap(
        null,
        file_size,
        PROT.READ | PROT.WRITE,
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
    @memcpy(buffer, data);

    const loader = try apply_protect(buffer);

    return loader;
}

pub fn load_from_file(path: []const u8) !FunctionLoader {
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
        PROT.READ | PROT.WRITE,
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

    const loader = try apply_protect(buffer);

    return loader;
}

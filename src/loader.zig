const std = @import("std");
const builtin = @import("builtin");

const system = std.os.linux;
const log = std.log;

const RemoteFunction = fn ([*c]const u8) callconv(.c) void;

pub fn FunctionLoader(comptime F: type) type {
    enforce_calling_convention(F);
    return struct {
        const Self = @This();

        size: usize,
        ptr: *const F,

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

        pub fn f(self: *const Self) *const F {
            return self.ptr;
        }

        pub fn deinit(self: Self) void {
            const ptr: [*]const u8 = @ptrCast(self.ptr);
            _ = system.munmap(ptr, self.size);
        }
    };
}

fn apply_protect(comptime F: type, data: []const u8) !FunctionLoader(F) {
    // Change the memory protection to allow execution
    const mprotect_result = system.mprotect(
        data.ptr,
        data.len,
        .{
            .EXEC = true,
            .READ = true,
        },
    );

    if (mprotect_result != 0) {
        return error.MprotectFailed;
    }

    const loader = FunctionLoader(F){
        .size = data.len,
        .ptr = @ptrCast(data.ptr),
    };

    log.debug(
        "Successfully loaded function: size = {d} bytes",
        .{loader.size},
    );

    return loader;
}

pub fn load_from_memory(comptime F: type, data: []const u8) !FunctionLoader(F) {
    log.debug("Loading function from memory: {d} bytes", .{data.len});

    const file_size: usize = data.len;
    if (file_size == 0) {
        return error.EmptyData;
    }

    const raw_buffer = system.mmap(
        null,
        file_size,
        .{
            .READ = true,
            .WRITE = true,
        },
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

    const loader = try apply_protect(F, buffer);

    return loader;
}

pub fn load_from_file(comptime F: type, path: []const u8) !FunctionLoader(F) {
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

    const loader = try apply_protect(F, buffer);

    return loader;
}

/// Validate that the provided type is a function
fn enforce_calling_convention(comptime F: type) void {
    const c_callconv = builtin.target.cCallingConvention().?;

    comptime {
        const type_info = @typeInfo(F);
        switch (type_info) {
            .@"fn" => |fn_info| {
                if (!fn_info.calling_convention.eql(c_callconv)) {
                    @compileError("Provided function must use the C calling convention");
                }
            },
            else => {
                @compileError("Provided type must be a function");
            },
        }
    }
}

const std = @import("std");
const posix = std.posix;

const s_print = fn (comptime format: []const u8, args: anytype) void;

pub fn print_maker(
    comptime file: std.fs.File,
    comptime buffer_size: usize,
) s_print {
    const _inner = struct {
        var static_buffer: [buffer_size]u8 = undefined;

        fn @"fn"(
            comptime format: []const u8,
            args: anytype,
        ) void {
            const buffer: []u8 = &static_buffer;
            var file_writer = file.writer(buffer);
            const writer = &file_writer.interface;
            writer.print(format, args) catch {
                @panic("Formatting error");
            };
            writer.flush() catch {
                @panic("Flush error");
            };
        }
    };

    return _inner.@"fn";
}

pub const printf = print_maker(std.fs.File.stdout(), 1024);
pub const eprintf = print_maker(std.fs.File.stderr(), 1024);

const logFunctionType: type = fn (
    comptime level: std.log.Level,
    comptime _: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void;

pub fn logFunctionMake(comptime buffer_size: usize, comptime noop: bool) logFunctionType {
    const _inner = struct {
        fn logFunction(
            comptime level: std.log.Level,
            comptime _: @TypeOf(.EnumLiteral),
            comptime format: []const u8,
            args: anytype,
        ) void {
            const printFn = print_maker(
                std.fs.File.stderr(),
                buffer_size,
            );
            const levelStr = switch (level) {
                .debug => "[DEBUG]: ",
                .info => "[INFO]:  ",
                .warn => "[WARN]:  ",
                .err => "[ERROR]: ",
            };

            printFn(levelStr ++ format ++ "\n", args);
        }

        fn noLogFunction(
            comptime _: std.log.Level,
            comptime _: @TypeOf(.EnumLiteral),
            comptime _: []const u8,
            _: anytype,
        ) void {
            // No-op
        }
    };

    return if (noop) _inner.noLogFunction else _inner.logFunction;
}

var previousTermios: ?posix.termios = null;

pub fn setRawMode() !void {
    if (previousTermios != null) {
        return error.AlreadyInRawMode;
    }

    if (!posix.isatty(posix.STDIN_FILENO)) {
        return;
    }

    // Save the current terminal settings
    previousTermios = posix.tcgetattr(posix.STDIN_FILENO) catch {
        previousTermios = null;
        return error.GetTermiosFailed;
    };
    var raw: posix.termios = previousTermios.?;
    // Disable canonical mode and echo
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;

    // No timeouts, return immediately
    // raw.cc[@intFromEnum(posix.V.MIN)] = 0;
    // raw.cc[@intFromEnum(posix.V.TIME)] = 0;

    posix.tcsetattr(posix.STDIN_FILENO, .NOW, raw) catch {
        return error.SetRawModeFailed;
    };
}

pub fn restoreTerminal() !void {
    if (previousTermios == null) {
        return;
    }

    posix.tcsetattr(posix.STDIN_FILENO, .NOW, previousTermios.?) catch {
        return error.RestoreTerminalFailed;
    };
    previousTermios = null;
}

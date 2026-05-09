const std = @import("std");

const log = std.log;

const Format = struct {
    pub const EI_NIDENT = 16;
    pub const ELFCLASS64: u8 = 2;
    pub const ELFDATA2LSB: u8 = 1;
    pub const EV_CURRENT: u8 = 1;

    pub const ET_EXEC: u16 = 2;
    pub const EM_X86_64: u16 = 62;

    pub const PT_LOAD: u32 = 1;

    pub const PF_X: u32 = 1;
    pub const PF_W: u32 = 2;
    pub const PF_R: u32 = 4;

    pub const PAGE_SIZE: u64 = 0x1000;
    pub const IMAGE_BASE: u64 = 0x400000;

    pub const Elf64_Ehdr = extern struct {
        e_ident: [EI_NIDENT]u8,
        e_type: u16,
        e_machine: u16,
        e_version: u32,
        e_entry: u64,
        e_phoff: u64,
        e_shoff: u64,
        e_flags: u32,
        e_ehsize: u16,
        e_phentsize: u16,
        e_phnum: u16,
        e_shentsize: u16,
        e_shnum: u16,
        e_shstrndx: u16,
    };

    pub const Elf64_Phdr = extern struct {
        p_type: u32,
        p_flags: u32,
        p_offset: u64,
        p_vaddr: u64,
        p_paddr: u64,
        p_filesz: u64,
        p_memsz: u64,
        p_align: u64,
    };

    pub fn ident() [EI_NIDENT]u8 {
        var bytes = [_]u8{0} ** EI_NIDENT;
        bytes[0] = 0x7f;
        bytes[1] = 'E';
        bytes[2] = 'L';
        bytes[3] = 'F';
        bytes[4] = ELFCLASS64;
        bytes[5] = ELFDATA2LSB;
        bytes[6] = EV_CURRENT;
        bytes[7] = 0;
        return bytes;
    }

    pub fn header(entry_vaddr: u64, phnum: u16) Elf64_Ehdr {
        return .{
            .e_ident = ident(),
            .e_type = ET_EXEC,
            .e_machine = EM_X86_64,
            .e_version = 1,
            .e_entry = entry_vaddr,
            .e_phoff = @sizeOf(Elf64_Ehdr),
            .e_shoff = 0,
            .e_flags = 0,
            .e_ehsize = @sizeOf(Elf64_Ehdr),
            .e_phentsize = @sizeOf(Elf64_Phdr),
            .e_phnum = phnum,
            .e_shentsize = 0,
            .e_shnum = 0,
            .e_shstrndx = 0,
        };
    }
};

pub const SegmentId = struct {
    index: usize,
};

pub const SegmentKind = enum {
    text,
    data,
    custom,
};

pub const SegmentFlags = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,

    fn toElf(self: SegmentFlags) u32 {
        var flags: u32 = 0;
        if (self.read) flags |= Format.PF_R;
        if (self.write) flags |= Format.PF_W;
        if (self.execute) flags |= Format.PF_X;
        return flags;
    }
};

pub const SegmentConfig = struct {
    kind: SegmentKind = .custom,
    flags: SegmentFlags,
    alignment: u64 = Format.PAGE_SIZE,
};

pub const EntryPoint = struct {
    segment: SegmentId,
    offset: u64,
};

pub const PatchKind = enum {
    rel32,
};

const Patch = struct {
    kind: PatchKind,
    source_segment: SegmentId,
    patch_offset: u64,
    target_segment: SegmentId,
    target_offset: u64,
};

const SegmentState = struct {
    config: SegmentConfig,
    bytes: std.ArrayList(u8) = .empty,

    fn deinit(self: *SegmentState, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
    }
};

const ResolvedSegment = struct {
    payload_offset: u64,
    payload_vaddr: u64,
    load_offset: u64,
    load_vaddr: u64,
    file_size: u64,
    mem_size: u64,
    alignment: u64,
    flags: u32,
};

pub const Engine = struct {
    allocator: std.mem.Allocator,
    image_base: u64 = Format.IMAGE_BASE,
    segments: std.ArrayList(SegmentState) = .empty,
    patches: std.ArrayList(Patch) = .empty,
    entry_point: ?EntryPoint = null,

    /// Creates a new ELF engine.
    pub fn init(allocator: std.mem.Allocator) Engine {
        return .{ .allocator = allocator };
    }

    /// Releases all engine-owned allocations.
    pub fn deinit(self: *Engine) void {
        for (self.segments.items) |*state| {
            state.deinit(self.allocator);
        }
        self.segments.deinit(self.allocator);
        self.patches.deinit(self.allocator);
    }

    /// Registers a new loadable segment and returns its handle.
    pub fn segment(self: *Engine, config: SegmentConfig) !SegmentId {
        if (config.alignment == 0) return error.InvalidAlignment;

        const id = SegmentId{ .index = self.segments.items.len };
        try self.segments.append(self.allocator, .{ .config = config });
        return id;
    }

    /// Appends bytes to a segment and returns the starting offset within that segment.
    pub fn append(self: *Engine, id: SegmentId, bytes: []const u8) !u64 {
        const state = try self.segmentState(id);
        const offset = segmentOffset(state);
        try state.bytes.appendSlice(self.allocator, bytes);
        return offset;
    }

    /// Appends zero-filled bytes to a segment and returns the starting offset within that segment.
    pub fn reserveZeroes(self: *Engine, id: SegmentId, len: usize) !u64 {
        const state = try self.segmentState(id);
        const offset = segmentOffset(state);
        try state.bytes.appendNTimes(self.allocator, 0, len);
        return offset;
    }

    /// Records the executable entry point.
    pub fn setEntry(self: *Engine, segment_id: SegmentId, offset: u64) !void {
        const state = try self.segmentState(segment_id);
        if (offset > segmentOffset(state)) return error.InvalidEntryOffset;
        self.entry_point = .{ .segment = segment_id, .offset = offset };
    }

    /// Records a 32-bit RIP-relative patch from one segment to another.
    pub fn patchRel32(
        self: *Engine,
        source_segment: SegmentId,
        patch_offset: u64,
        target_segment: SegmentId,
        target_offset: u64,
    ) !void {
        try self.ensurePatchRange(source_segment, patch_offset, 4);
        _ = try self.segmentState(target_segment);

        try self.patches.append(self.allocator, .{
            .kind = .rel32,
            .source_segment = source_segment,
            .patch_offset = patch_offset,
            .target_segment = target_segment,
            .target_offset = target_offset,
        });
    }

    /// Resolves the final file offset of a byte within a segment payload.
    pub fn payloadSlice(self: *Engine, segment_id: SegmentId, offset: u64) ![]u8 {
        const state = try self.segmentState(segment_id);
        if (offset > segmentOffset(state)) return error.InvalidSegmentOffset;
        return state.bytes.items[offset..];
    }

    /// Resolves the final virtual address of a byte within a segment payload.
    pub fn payloadVirtualAddress(self: *Engine, segment_id: SegmentId, offset: u64) !u64 {
        const state = try self.segmentState(segment_id);
        if (offset > segmentOffset(state)) return error.InvalidSegmentOffset;

        const resolved = try self.resolveLayout();
        defer self.allocator.free(resolved);

        const layout = resolved[segment_id.index];
        return std.math.add(u64, layout.payload_vaddr, offset) catch return error.Overflow;
    }

    /// Finalizes the ELF image and returns the serialized bytes.
    pub fn finalize(self: *Engine) ![]u8 {
        if (self.segments.items.len == 0) return error.EmptyExecutable;

        const resolved = try self.resolveLayout();
        defer self.allocator.free(resolved);

        const entry = self.entry_point orelse return error.MissingEntryPoint;
        const entry_vaddr = try self.resolveEntry(resolved, entry);
        const total_size = totalFileSize(resolved);

        const file_bytes = try self.allocator.alloc(u8, total_size);
        @memset(file_bytes, 0);
        errdefer self.allocator.free(file_bytes);

        const ehdr = Format.header(entry_vaddr, std.math.cast(u16, resolved.len) orelse return error.TooManySegments);
        @memcpy(file_bytes[0..@sizeOf(Format.Elf64_Ehdr)], std.mem.asBytes(&ehdr));

        var phoff: usize = @sizeOf(Format.Elf64_Ehdr);
        for (resolved) |layout| {
            const phdr = Format.Elf64_Phdr{
                .p_type = Format.PT_LOAD,
                .p_flags = layout.flags,
                .p_offset = layout.load_offset,
                .p_vaddr = layout.load_vaddr,
                .p_paddr = layout.load_vaddr,
                .p_filesz = layout.file_size,
                .p_memsz = layout.mem_size,
                .p_align = layout.alignment,
            };
            const phdr_size = @sizeOf(Format.Elf64_Phdr);
            @memcpy(file_bytes[phoff .. phoff + phdr_size], std.mem.asBytes(&phdr));
            phoff += phdr_size;
        }

        for (self.segments.items, resolved) |state, layout| {
            const payload_offset: usize = std.math.cast(usize, layout.payload_offset) orelse return error.Overflow;
            const payload_end = payload_offset + state.bytes.items.len;
            @memcpy(file_bytes[payload_offset..payload_end], state.bytes.items);
        }

        try self.applyPatches(file_bytes, resolved);
        return file_bytes;
    }

    /// Finalizes the ELF image and writes it to a file.
    pub fn finalizeToFile(self: *Engine, io: std.Io, file: std.Io.File) !usize {
        const bytes = try self.finalize();
        defer self.allocator.free(bytes);
        try file.writeStreamingAll(io, bytes);
        return bytes.len;
    }

    fn segmentState(self: *Engine, id: SegmentId) !*SegmentState {
        if (id.index >= self.segments.items.len) return error.InvalidSegment;
        return &self.segments.items[id.index];
    }

    fn ensurePatchRange(self: *Engine, segment_id: SegmentId, offset: u64, size: u64) !void {
        const state = try self.segmentState(segment_id);
        const end = std.math.add(u64, offset, size) catch return error.Overflow;
        if (end > segmentOffset(state)) return error.InvalidPatchOffset;
    }

    fn resolveEntry(self: *Engine, resolved: []const ResolvedSegment, entry: EntryPoint) !u64 {
        const layout = resolved[entry.segment.index];
        const segment_size = segmentOffset(&self.segments.items[entry.segment.index]);
        if (entry.offset > segment_size) return error.InvalidEntryOffset;
        return std.math.add(u64, layout.payload_vaddr, entry.offset) catch return error.Overflow;
    }

    fn resolveLayout(self: *Engine) ![]ResolvedSegment {
        const count = self.segments.items.len;
        const resolved = try self.allocator.alloc(ResolvedSegment, count);
        errdefer self.allocator.free(resolved);

        const header_size: u64 = @sizeOf(Format.Elf64_Ehdr) + count * @sizeOf(Format.Elf64_Phdr);
        var cursor = header_size;
        var next_load_vaddr = self.image_base;

        for (self.segments.items, 0..) |state, i| {
            if (state.bytes.items.len == 0) return error.EmptySegment;

            const payload_len: u64 = segmentOffset(&state);
            const alignment = state.config.alignment;
            const flags = state.config.flags.toElf();

            if (i == 0) {
                resolved[i] = .{
                    .payload_offset = header_size,
                    .payload_vaddr = self.image_base + header_size,
                    .load_offset = 0,
                    .load_vaddr = self.image_base,
                    .file_size = header_size + payload_len,
                    .mem_size = header_size + payload_len,
                    .alignment = alignment,
                    .flags = flags,
                };
                cursor = header_size + payload_len;
                next_load_vaddr = self.image_base + header_size + payload_len;
                continue;
            }

            const offset_in_page = cursor % alignment;
            const load_vaddr = std.mem.alignForward(u64, next_load_vaddr, alignment) + offset_in_page;
            resolved[i] = .{
                .payload_offset = cursor,
                .payload_vaddr = load_vaddr,
                .load_offset = cursor,
                .load_vaddr = load_vaddr,
                .file_size = payload_len,
                .mem_size = payload_len,
                .alignment = alignment,
                .flags = flags,
            };
            cursor += payload_len;
            next_load_vaddr = load_vaddr + payload_len;
        }

        return resolved;
    }

    fn applyPatches(self: *Engine, file_bytes: []u8, resolved: []const ResolvedSegment) !void {
        for (self.patches.items) |patch| {
            const source = resolved[patch.source_segment.index];
            const target = resolved[patch.target_segment.index];

            const source_field_vaddr = source.payload_vaddr + patch.patch_offset;
            const target_vaddr = target.payload_vaddr + patch.target_offset;
            const source_file_offset: usize = std.math.cast(usize, source.payload_offset + patch.patch_offset) orelse return error.Overflow;

            switch (patch.kind) {
                .rel32 => {
                    const next_ip = source_field_vaddr + 4;
                    const disp = @as(i64, @intCast(target_vaddr)) - @as(i64, @intCast(next_ip));
                    const value = std.math.cast(i32, disp) orelse return error.Overflow;
                    const little = std.mem.nativeToLittle(i32, value);
                    const field = file_bytes[source_file_offset .. source_file_offset + 4];
                    @memcpy(field, std.mem.asBytes(&little));
                },
            }
        }
    }
};

fn segmentOffset(segment: *const SegmentState) u64 {
    return @intCast(segment.bytes.items.len);
}

fn totalFileSize(resolved: []const ResolvedSegment) usize {
    var size: u64 = 0;
    for (resolved) |segment| {
        size = @max(size, segment.load_offset + segment.file_size);
    }
    return @intCast(size);
}

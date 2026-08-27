const std = @import("std");

pub const DeclarationKind = enum {
    enum_decl,
    function,
    record,
    variable,
    typedef,
    interface,
    protocol,
    method,
    property,
};

pub const Status = enum {
    unclassified,
    generated,
    manual,
    rejected,
};

pub const Entry = struct {
    name: []const u8,
    kind: DeclarationKind,
    header: []const u8,
    status: Status = .unclassified,
    reason: []const u8 = "",
};

pub const ManualSource = struct {
    path: []const u8,
    content: []const u8,
};

pub const Manifest = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    framework: []const u8,
    entries: std.array_list.Managed(Entry),

    pub fn init(allocator: std.mem.Allocator, framework: []const u8) Self {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .framework = framework,
            .entries = std.array_list.Managed(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
        self.arena.deinit();
    }

    pub fn add(
        self: *Self,
        kind: DeclarationKind,
        name: []const u8,
        header: []const u8,
    ) !*Entry {
        for (self.entries.items) |*entry| {
            if (entry.kind == kind and
                std.mem.eql(u8, entry.name, name) and
                std.mem.eql(u8, entry.header, header))
            {
                return entry;
            }
        }

        const arena = self.arena.allocator();
        try self.entries.append(.{
            .name = try arena.dupe(u8, name),
            .kind = kind,
            .header = try arena.dupe(u8, header),
        });
        return &self.entries.items[self.entries.items.len - 1];
    }

    pub fn mark(
        self: *Self,
        kind: DeclarationKind,
        name: []const u8,
        status: Status,
        reason: []const u8,
    ) !void {
        var found = false;
        for (self.entries.items) |*entry| {
            if (entry.kind == kind and std.mem.eql(u8, entry.name, name)) {
                entry.status = status;
                entry.reason = try self.arena.allocator().dupe(u8, reason);
                found = true;
            }
        }
        if (!found) return error.ManifestDeclarationNotFound;
    }

    pub fn markIfPresent(
        self: *Self,
        kind: DeclarationKind,
        name: []const u8,
        status: Status,
        reason: []const u8,
    ) !void {
        self.mark(kind, name, status, reason) catch |err| switch (err) {
            error.ManifestDeclarationNotFound => {},
            else => return err,
        };
    }

    pub fn statusOf(
        self: *const Self,
        kind: DeclarationKind,
        name: []const u8,
    ) ?Status {
        for (self.entries.items) |entry| {
            if (entry.kind == kind and std.mem.eql(u8, entry.name, name)) {
                return entry.status;
            }
        }
        return null;
    }

    pub fn finalize(self: *Self, manual_sources: []const ManualSource) !void {
        for (self.entries.items) |*entry| {
            if (entry.status != .unclassified) continue;

            if (findManualSource(entry.*, manual_sources)) |source| {
                entry.status = .manual;
                entry.reason = try std.fmt.allocPrint(
                    self.arena.allocator(),
                    "manually maintained declaration in {s}",
                    .{source.path},
                );
                continue;
            }

            entry.status = .rejected;
            entry.reason = try self.arena.allocator().dupe(u8, rejectionReason(entry.kind));
        }

        for (self.entries.items) |entry| {
            if (entry.status == .unclassified or entry.reason.len == 0) {
                std.debug.print(
                    "unaudited declaration: {s} {s} ({s})\n",
                    .{ @tagName(entry.kind), entry.name, entry.header },
                );
                return error.UnauditedDeclaration;
            }
        }

        std.sort.insertion(Entry, self.entries.items, {}, entryLessThan);
    }

    pub fn write(self: *Self, io: std.Io, path: []const u8) !void {
        var generated: usize = 0;
        var manual: usize = 0;
        var rejected: usize = 0;
        for (self.entries.items) |entry| switch (entry.status) {
            .generated => generated += 1,
            .manual => manual += 1,
            .rejected => rejected += 1,
            .unclassified => return error.UnauditedDeclaration,
        };

        const Output = struct {
            framework: []const u8,
            counts: struct {
                total: usize,
                generated: usize,
                manual: usize,
                rejected: usize,
            },
            declarations: []const Entry,
        };
        const output: Output = .{
            .framework = self.framework,
            .counts = .{
                .total = self.entries.items.len,
                .generated = generated,
                .manual = manual,
                .rejected = rejected,
            },
            .declarations = self.entries.items,
        };

        var atomic_file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .replace = true });
        defer atomic_file.deinit(io);
        var buffer: [4096]u8 = undefined;
        var writer = atomic_file.file.writerStreaming(io, &buffer);
        try std.json.Stringify.value(output, .{ .whitespace = .indent_2 }, &writer.interface);
        try writer.interface.writeByte('\n');
        try writer.flush();
        try atomic_file.replace(io);
    }

    fn findManualSource(entry: Entry, sources: []const ManualSource) ?ManualSource {
        for (sources) |source| {
            var lines = std.mem.splitScalar(u8, source.content, '\n');
            while (lines.next()) |line| {
                const declared = declaredIdentifier(line) orelse continue;
                if (std.mem.eql(u8, declared, entry.name) or
                    std.mem.eql(u8, declared, trimApplePrefix(entry.name)))
                {
                    return source;
                }
            }
        }
        return null;
    }

    fn declaredIdentifier(line: []const u8) ?[]const u8 {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//")) return null;

        const prefixes = [_][]const u8{ "pub const ", "pub fn ", "extern const ", "extern fn " };
        for (prefixes) |prefix| {
            if (!std.mem.startsWith(u8, trimmed, prefix)) continue;
            const rest = trimmed[prefix.len..];
            var length: usize = 0;
            while (length < rest.len and isIdentifierChar(rest[length])) length += 1;
            if (length == 0) return null;
            return rest[0..length];
        }
        return null;
    }

    fn isIdentifierChar(ch: u8) bool {
        return std.ascii.isAlphanumeric(ch) or ch == '_';
    }

    fn trimApplePrefix(name: []const u8) []const u8 {
        const prefixes = [_][]const u8{ "MTL4FX", "MTLFX", "MTL4", "MTL", "NS", "CA", "CF", "CG" };
        for (prefixes) |prefix| {
            if (std.mem.startsWith(u8, name, prefix) and name.len > prefix.len) {
                return name[prefix.len..];
            }
        }
        return name;
    }

    fn rejectionReason(kind: DeclarationKind) []const u8 {
        return switch (kind) {
            .function => "top-level C function generation is not implemented; declaration explicitly rejected",
            .record => "record generation is not implemented; declaration explicitly rejected",
            .variable => "exported variable generation is not implemented; declaration explicitly rejected",
            .typedef => "typedef is not emitted or manually audited; declaration explicitly rejected",
            .enum_decl => "enum is outside the selected generated set; declaration explicitly rejected",
            .interface => "interface is outside the selected generated set; declaration explicitly rejected",
            .protocol => "protocol is outside the selected generated set; declaration explicitly rejected",
            .method => "method is outside the selected generated method set; declaration explicitly rejected",
            .property => "property is not represented by a selected generated accessor; declaration explicitly rejected",
        };
    }

    fn entryLessThan(_: void, lhs: Entry, rhs: Entry) bool {
        const header_order = std.mem.order(u8, lhs.header, rhs.header);
        if (header_order != .eq) return header_order == .lt;
        const kind_order = std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind));
        if (kind_order != .eq) return kind_order == .lt;
        return std.mem.order(u8, lhs.name, rhs.name) == .lt;
    }
};

test "manual classification requires an active declaration" {
    var manifest = Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();

    _ = try manifest.add(.function, "MTLCopyAllDevices", "MTLDevice.h");
    _ = try manifest.add(.record, "MTLOrigin", "MTLTypes.h");
    const sources = [_]ManualSource{.{
        .path = "src/metal.zig",
        .content =
        \\// extern fn MTLCopyAllDevices() void;
        \\pub const Origin = extern struct {};
        ,
    }};
    try manifest.finalize(&sources);

    try std.testing.expectEqual(.rejected, manifest.statusOf(.function, "MTLCopyAllDevices").?);
    try std.testing.expectEqual(.manual, manifest.statusOf(.record, "MTLOrigin").?);
}

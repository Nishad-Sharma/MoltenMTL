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
    excluded,
    rejected,
};

/// How a declaration came to be part of the selected surface.
pub const Provenance = enum {
    /// Named directly by the generator's selection list.
    explicit,
    /// Reachable from an explicitly selected declaration's public signature.
    transitive_dependency,
    /// Present in the SDK inventory but not reachable from the selection list.
    sdk_only,
};

pub const Entry = struct {
    name: []const u8,
    kind: DeclarationKind,
    header: []const u8,
    selected: bool = false,
    provenance: Provenance = .sdk_only,
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

    /// Mark a declaration as part of the selected surface.
    ///
    /// `explicit` outranks `transitive_dependency`: a declaration named in the
    /// selection list stays explicit even when something else also reaches it.
    pub fn select(
        self: *Self,
        kind: DeclarationKind,
        name: []const u8,
        provenance: Provenance,
    ) !void {
        var found = false;
        for (self.entries.items) |*entry| {
            if (entry.kind != kind or !std.mem.eql(u8, entry.name, name)) continue;
            if (!entry.selected or provenance == .explicit) entry.provenance = provenance;
            entry.selected = true;
            found = true;
        }
        if (!found) return error.ManifestDeclarationNotFound;
    }

    /// Select a declaration if the inventory knows it. Returns whether it did.
    ///
    /// The closure walk uses the return value as its framework boundary: a name
    /// this manifest does not own belongs to somebody else's surface.
    pub fn selectIfPresent(
        self: *Self,
        kind: DeclarationKind,
        name: []const u8,
        provenance: Provenance,
    ) !bool {
        self.select(kind, name, provenance) catch |err| switch (err) {
            error.ManifestDeclarationNotFound => return false,
        };
        return true;
    }

    /// Is any declaration with this name already represented?
    ///
    /// One identifier can name both an interface and a protocol — Metal declares
    /// `@class MTL4BinaryFunction` alongside `@protocol MTL4BinaryFunction`, and
    /// only the protocol is bound. Reachability is satisfied by the name, so the
    /// unused sibling must not be reported as a gap.
    fn nameIsRepresented(self: *const Self, name: []const u8) bool {
        for (self.entries.items) |entry| {
            if (!std.mem.eql(u8, entry.name, name)) continue;
            if (entry.status == .generated or entry.status == .manual) return true;
        }
        return false;
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
        // Manual declarations are part of the selected binding surface even when
        // they are not emitted by the generator, so classify them before deciding
        // whether the remaining SDK declarations are excluded or rejected.
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
        }

        // A hand-written binding is the most explicit form of selection there is,
        // however it came to be classified — records are marked manual during
        // generation, when their layout is verified against Clang, and so never
        // reach the pass above. Without this, `selected` reports the opposite of
        // the truth for every hand-written declaration.
        for (self.entries.items) |*entry| {
            if (entry.status != .manual or entry.selected) continue;
            entry.selected = true;
            entry.provenance = .explicit;
        }

        // Phase 3 inventories SDK declarations without assuming that every
        // declaration is selected. Any top-level declaration left unclassified
        // after generation and manual-source auditing is therefore excluded.
        // Phase 4's scope inventory will explicitly select additional entries;
        // selected entries that cannot be represented must be marked rejected.
        for (self.entries.items) |*entry| {
            if (entry.status != .unclassified) continue;
            switch (entry.kind) {
                .enum_decl, .function, .record, .variable, .typedef, .interface, .protocol => {
                    if (entry.selected and !self.nameIsRepresented(entry.name)) {
                        // Reachable from the selected surface but neither generated
                        // nor manually bound. That is a real gap in the bindings,
                        // not SDK API that happens to be out of scope.
                        entry.status = .rejected;
                        entry.reason = try self.arena.allocator().dupe(
                            u8,
                            "reachable from the selected surface but not generated or manually bound",
                        );
                    } else if (entry.selected) {
                        entry.status = .excluded;
                        entry.reason = try self.arena.allocator().dupe(
                            u8,
                            "represented by another declaration with the same name",
                        );
                    } else {
                        entry.status = .excluded;
                        entry.reason = try self.arena.allocator().dupe(
                            u8,
                            exclusionReason(entry.kind),
                        );
                    }
                },
                .method, .property => {},
            }
        }

        // Members follow their owning container. Members of an excluded SDK
        // container are outside the selected surface; an unclassified member of
        // a generated container was selected but not represented safely.
        for (self.entries.items) |*entry| {
            if (entry.status != .unclassified) continue;
            const owner_status = self.memberOwnerStatus(entry.name);
            if (owner_status == .generated or owner_status == .rejected) {
                entry.status = .rejected;
                entry.reason = try self.arena.allocator().dupe(
                    u8,
                    rejectionReason(entry.kind),
                );
            } else {
                entry.status = .excluded;
                entry.reason = try self.arena.allocator().dupe(
                    u8,
                    "owning Objective-C container is outside the selected binding surface",
                );
            }
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
        var excluded: usize = 0;
        var rejected: usize = 0;
        for (self.entries.items) |entry| switch (entry.status) {
            .generated => generated += 1,
            .manual => manual += 1,
            .excluded => excluded += 1,
            .rejected => rejected += 1,
            .unclassified => return error.UnauditedDeclaration,
        };

        var explicit: usize = 0;
        var transitive: usize = 0;
        for (self.entries.items) |entry| {
            if (!entry.selected) continue;
            switch (entry.provenance) {
                .explicit => explicit += 1,
                .transitive_dependency => transitive += 1,
                .sdk_only => {},
            }
        }

        std.log.info(
            "{s}: {d} declarations ({d} generated, {d} manual, {d} excluded, {d} rejected)",
            .{ self.framework, self.entries.items.len, generated, manual, excluded, rejected },
        );
        std.log.info(
            "{s}: selected surface is {d} explicit + {d} transitive = {d} declarations",
            .{ self.framework, explicit, transitive, explicit + transitive },
        );
        if (rejected != 0) {
            // Rejected means a selected declaration the generator cannot represent
            // safely. Parity requires this to reach zero, so name every one.
            std.log.warn(
                "{s}: {d} selected declarations are rejected",
                .{ self.framework, rejected },
            );
            for (self.entries.items) |entry| {
                if (entry.status != .rejected) continue;
                std.log.warn(
                    "  rejected {s} {s}: {s}",
                    .{ @tagName(entry.kind), entry.name, entry.reason },
                );
            }
        }

        const Output = struct {
            framework: []const u8,
            counts: struct {
                total: usize,
                generated: usize,
                manual: usize,
                excluded: usize,
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
                .excluded = excluded,
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
            .enum_decl => "selected enum is not represented safely; declaration explicitly rejected",
            .interface => "selected interface is not represented safely; declaration explicitly rejected",
            .protocol => "selected protocol is not represented safely; declaration explicitly rejected",
            .method => "selected method is not represented by a generated wrapper; declaration explicitly rejected",
            .property => "selected property is not represented by generated accessors; declaration explicitly rejected",
        };
    }

    fn exclusionReason(kind: DeclarationKind) []const u8 {
        return switch (kind) {
            .enum_decl => "valid SDK enum outside the selected binding surface",
            .function => "valid SDK function outside the selected binding surface",
            .record => "valid SDK record outside the selected binding surface",
            .variable => "valid SDK variable outside the selected binding surface",
            .typedef => "valid SDK typedef outside the selected binding surface",
            .interface => "valid SDK interface outside the selected binding surface",
            .protocol => "valid SDK protocol outside the selected binding surface",
            .method, .property => unreachable,
        };
    }

    fn memberOwnerStatus(self: *const Self, member_name: []const u8) Status {
        const separator = std.mem.indexOfScalar(u8, member_name, '.') orelse return .unclassified;
        const owner = member_name[0..separator];
        for (self.entries.items) |entry| {
            if ((entry.kind == .interface or entry.kind == .protocol) and
                std.mem.eql(u8, entry.name, owner))
            {
                return entry.status;
            }
        }
        return .unclassified;
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

    try std.testing.expectEqual(.excluded, manifest.statusOf(.function, "MTLCopyAllDevices").?);
    try std.testing.expectEqual(.manual, manifest.statusOf(.record, "MTLOrigin").?);
}

test "hand-written declarations are part of the selected surface" {
    var manifest = Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();

    _ = try manifest.add(.record, "MTLPackedFloat3", "MTLAccelerationStructureTypes.h");
    _ = try manifest.add(.interface, "NSArray", "NSArray.h");

    // Records are marked manual during generation, before finalize sees them.
    try manifest.mark(.record, "MTLPackedFloat3", .manual, "layout verified against Clang");
    // Something already reached as a dependency keeps the provenance it had.
    try manifest.select(.interface, "NSArray", .transitive_dependency);

    const sources = [_]ManualSource{.{
        .path = "src/foundation.zig",
        .content = "pub const Array = opaque {};",
    }};
    try manifest.finalize(&sources);

    for (manifest.entries.items) |entry| {
        try std.testing.expect(entry.selected);
        if (entry.kind == .record) {
            try std.testing.expectEqual(Provenance.explicit, entry.provenance);
        } else {
            try std.testing.expectEqual(Provenance.transitive_dependency, entry.provenance);
        }
    }
}

test "a reachable declaration that is not bound is rejected" {
    var manifest = Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();

    _ = try manifest.add(.record, "MTLReachableButUnbound", "MTLTypes.h");
    _ = try manifest.add(.record, "MTLNotReachable", "MTLTypes.h");
    try manifest.select(.record, "MTLReachableButUnbound", .transitive_dependency);

    try manifest.finalize(&.{});

    // Reachable from the selected surface but bound nowhere: a real gap.
    try std.testing.expectEqual(.rejected, manifest.statusOf(.record, "MTLReachableButUnbound").?);
    // Never reached: valid SDK API that is simply out of scope.
    try std.testing.expectEqual(.excluded, manifest.statusOf(.record, "MTLNotReachable").?);
}

test "a like-named sibling declaration satisfies reachability" {
    var manifest = Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();

    // Metal declares `@class MTL4BinaryFunction` alongside a protocol of the same
    // name, and only the protocol is bound. Reaching the name must not report the
    // unused class as a gap.
    _ = try manifest.add(.interface, "MTL4BinaryFunction", "MTL4BinaryFunction.h");
    _ = try manifest.add(.protocol, "MTL4BinaryFunction", "MTL4BinaryFunction.h");
    try manifest.mark(
        .protocol,
        "MTL4BinaryFunction",
        .generated,
        "generated Objective-C protocol wrapper",
    );
    try manifest.select(.interface, "MTL4BinaryFunction", .transitive_dependency);
    try manifest.select(.protocol, "MTL4BinaryFunction", .transitive_dependency);

    try manifest.finalize(&.{});

    try std.testing.expectEqual(.generated, manifest.statusOf(.protocol, "MTL4BinaryFunction").?);
    try std.testing.expectEqual(.excluded, manifest.statusOf(.interface, "MTL4BinaryFunction").?);
}

test "explicit provenance outranks transitive" {
    var manifest = Manifest.init(std.testing.allocator, "Metal");
    defer manifest.deinit();

    _ = try manifest.add(.interface, "MTLTextureDescriptor", "MTLTexture.h");
    try manifest.select(.interface, "MTLTextureDescriptor", .transitive_dependency);
    try manifest.select(.interface, "MTLTextureDescriptor", .explicit);
    try manifest.select(.interface, "MTLTextureDescriptor", .transitive_dependency);

    var checked = false;
    for (manifest.entries.items) |entry| {
        if (entry.kind != .interface or !std.mem.eql(u8, entry.name, "MTLTextureDescriptor")) continue;
        try std.testing.expect(entry.selected);
        try std.testing.expectEqual(Provenance.explicit, entry.provenance);
        checked = true;
    }
    try std.testing.expect(checked);
}

test "valid SDK declarations outside the selected surface are excluded" {
    var manifest = Manifest.init(std.testing.allocator, "QuartzCore");
    defer manifest.deinit();

    _ = try manifest.add(.interface, "CAAnimation", "CAAnimation.h");
    _ = try manifest.add(.method, "CAAnimation.animation", "CAAnimation.h");
    _ = try manifest.add(.property, "CAAnimation.delegate", "CAAnimation.h");
    _ = try manifest.add(.interface, "CALayer", "CALayer.h");
    _ = try manifest.add(.method, "CALayer.unrepresented", "CALayer.h");
    try manifest.mark(
        .interface,
        "CALayer",
        .generated,
        "generated Objective-C class wrapper",
    );

    try manifest.finalize(&.{});

    try std.testing.expectEqual(.excluded, manifest.statusOf(.interface, "CAAnimation").?);
    try std.testing.expectEqual(.excluded, manifest.statusOf(.method, "CAAnimation.animation").?);
    try std.testing.expectEqual(.excluded, manifest.statusOf(.property, "CAAnimation.delegate").?);
    try std.testing.expectEqual(.rejected, manifest.statusOf(.method, "CALayer.unrepresented").?);
}

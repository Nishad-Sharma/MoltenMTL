const builtin = @import("builtin");
const std = @import("std");
const mach = @import("metal-zig");
const objc = mach.objc;

const Struct8 = extern struct {
    x: u64,
};

const Struct16 = extern struct {
    x: u64,
    y: u64,
};

const Struct24 = extern struct {
    x: u64,
    y: u64,
    z: u64,
};

const Struct32 = extern struct {
    x: u64,
    y: u64,
    z: u64,
    w: u64,
};

const FixtureBase = opaque {
    pub const InternalInfo = objc.ExternClass(
        "MachObjCABIBase",
        @This(),
        objc.Id,
        &.{},
    );
};

const Fixture = opaque {
    pub const InternalInfo = objc.ExternClass(
        "MachObjCABIFixture",
        @This(),
        FixtureBase,
        &.{},
    );
};

const MissingClass = opaque {
    pub const InternalInfo = objc.ExternClass(
        "MachObjCClassThatMustNotExist_5AFE600D",
        @This(),
        objc.Id,
        &.{},
    );
};

extern fn MachObjCABIFixtureCreate() ?*Fixture;
extern fn MachObjCABIFixtureClass() *objc.Class;
extern fn MachObjCAutoreleaseProbeCreate() void;
extern fn MachObjCAutoreleaseProbeDeallocCount() u64;

test "Objective-C classes resolve through the runtime" {
    const runtime_class = Fixture.InternalInfo.classIfAvailable();
    try std.testing.expect(runtime_class != null);
    try std.testing.expectEqual(
        @intFromPtr(MachObjCABIFixtureClass()),
        @intFromPtr(runtime_class.?),
    );
    try std.testing.expectEqual(
        @intFromPtr(runtime_class.?),
        @intFromPtr(Fixture.InternalInfo.class()),
    );
    try std.testing.expect(mach.foundation.String.InternalInfo.classIfAvailable() != null);
    try std.testing.expectEqual(null, MissingClass.InternalInfo.classIfAvailable());
}

test "respondsTo handles objects, classes, and nil" {
    const object = MachObjCABIFixtureCreate() orelse return error.FixtureCreationFailed;
    defer Fixture.InternalInfo.release(object);

    try std.testing.expect(objc.respondsTo(object, "baseValue"));
    try std.testing.expect(!objc.respondsTo(object, "selectorThatMustNotExist_5AFE600D"));
    try std.testing.expect(objc.respondsTo(MachObjCABIFixtureClass(), "classValue"));
    try std.testing.expect(!objc.respondsTo(@as(?*Fixture, null), "baseValue"));
}

test "scoped autorelease pool drains autoreleased objects" {
    const count_before = MachObjCAutoreleaseProbeDeallocCount();

    {
        var pool = objc.AutoreleasePool.init();
        defer pool.deinit();

        MachObjCAutoreleaseProbeCreate();
        try std.testing.expectEqual(count_before, MachObjCAutoreleaseProbeDeallocCount());
    }

    try std.testing.expectEqual(count_before + 1, MachObjCAutoreleaseProbeDeallocCount());
}

test "ARM64 Objective-C ordinary message ABI" {
    try std.testing.expectEqual(.aarch64, builtin.target.cpu.arch);

    const object = MachObjCABIFixtureCreate() orelse return error.FixtureCreationFailed;
    defer Fixture.InternalInfo.release(object);

    try std.testing.expectEqual(
        @as(u64, 42),
        objc.msgSend(object, "addValue:toValue:", u64, .{ @as(u64, 19), @as(u64, 23) }),
    );

    try std.testing.expect(!objc.msgSend(object, "negateBool:", bool, .{true}));
    try std.testing.expect(objc.msgSend(object, "negateBool:", bool, .{false}));

    try std.testing.expectApproxEqAbs(
        @as(f32, 3.75),
        objc.msgSend(object, "addFloat:toFloat:", f32, .{ @as(f32, 1.25), @as(f32, 2.5) }),
        0.0001,
    );
    try std.testing.expectApproxEqAbs(
        @as(f64, 3.75),
        objc.msgSend(object, "addDouble:toDouble:", f64, .{ @as(f64, 1.25), @as(f64, 2.5) }),
        0.0000001,
    );

    const identity = objc.msgSend(
        object,
        "identity:",
        ?*objc.Id,
        .{@as(?*objc.Id, @ptrCast(object))},
    );
    try std.testing.expectEqual(@intFromPtr(object), @intFromPtr(identity.?));

    try expectStruct8(.{ .x = 10 }, objc.msgSend(
        object,
        "struct8WithSeed:",
        Struct8,
        .{@as(u64, 10)},
    ));
    try expectStruct16(.{ .x = 20, .y = 21 }, objc.msgSend(
        object,
        "struct16WithSeed:",
        Struct16,
        .{@as(u64, 20)},
    ));
    try expectStruct24(.{ .x = 30, .y = 31, .z = 32 }, objc.msgSend(
        object,
        "struct24WithSeed:",
        Struct24,
        .{@as(u64, 30)},
    ));
    try expectStruct32(.{ .x = 40, .y = 41, .z = 42, .w = 43 }, objc.msgSend(
        object,
        "struct32WithSeed:",
        Struct32,
        .{@as(u64, 40)},
    ));

    const fixture_class = MachObjCABIFixtureClass();
    try std.testing.expectEqual(
        @as(u64, 84),
        objc.msgSend(fixture_class, "classValue", u64, .{}),
    );
    try expectStruct32(.{ .x = 50, .y = 51, .z = 52, .w = 53 }, objc.msgSend(
        fixture_class,
        "classStructWithSeed:",
        Struct32,
        .{@as(u64, 50)},
    ));

    try std.testing.expectEqual(
        @as(u64, 99),
        objc.msgSend(object, "baseValue", u64, .{}),
    );
    try std.testing.expectEqual(
        @as(u64, 41),
        objc.superFn(FixtureBase, "baseValue", fn (*Fixture) u64)(object),
    );

    try expectStruct24(.{ .x = 160, .y = 161, .z = 162 }, objc.msgSend(
        object,
        "baseStructWithSeed:",
        Struct24,
        .{@as(u64, 60)},
    ));
    try expectStruct24(
        .{ .x = 60, .y = 61, .z = 62 },
        objc.superFn(
            FixtureBase,
            "baseStructWithSeed:",
            fn (*Fixture, u64) Struct24,
        )(object, 60),
    );
}

test "selector cache supports concurrent first use" {
    const thread_count = 8;
    const object = MachObjCABIFixtureCreate() orelse return error.FixtureCreationFailed;
    defer Fixture.InternalInfo.release(object);

    var start = std.atomic.Value(bool).init(false);
    var failed = std.atomic.Value(bool).init(false);
    var threads: [thread_count]std.Thread = undefined;

    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, selectorWorker, .{ object, &start, &failed });
    }
    start.store(true, .release);
    for (threads) |thread| thread.join();

    try std.testing.expect(!failed.load(.acquire));
}

fn selectorWorker(
    object: *Fixture,
    start: *std.atomic.Value(bool),
    failed: *std.atomic.Value(bool),
) void {
    while (!start.load(.acquire)) std.atomic.spinLoopHint();

    const expected = @as(u64, 0xc001cafe5afe600d);
    const expected_super = @as(u64, 0xa11ce5afe600d123);
    for (0..1_000) |_| {
        const actual = objc.msgSend(object, "threadedSelectorValue", u64, .{});
        const actual_super = objc.superFn(
            FixtureBase,
            "threadedSuperValue",
            fn (*Fixture) u64,
        )(object);
        if (actual != expected or actual_super != expected_super) {
            failed.store(true, .release);
            return;
        }
    }
}

fn expectStruct8(expected: Struct8, actual: Struct8) !void {
    try std.testing.expectEqual(expected.x, actual.x);
}

fn expectStruct16(expected: Struct16, actual: Struct16) !void {
    try std.testing.expectEqual(expected.x, actual.x);
    try std.testing.expectEqual(expected.y, actual.y);
}

fn expectStruct24(expected: Struct24, actual: Struct24) !void {
    try std.testing.expectEqual(expected.x, actual.x);
    try std.testing.expectEqual(expected.y, actual.y);
    try std.testing.expectEqual(expected.z, actual.z);
}

fn expectStruct32(expected: Struct32, actual: Struct32) !void {
    try std.testing.expectEqual(expected.x, actual.x);
    try std.testing.expectEqual(expected.y, actual.y);
    try std.testing.expectEqual(expected.z, actual.z);
    try std.testing.expectEqual(expected.w, actual.w);
}

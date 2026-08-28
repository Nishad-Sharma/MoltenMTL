//! Block ABI tests.
//!
//! The bindings hand-roll the Block ABI rather than depending on a runtime
//! library, and every asynchronous Metal entry point - pipeline and library
//! compilation, command buffer completion, shared event notification - passes a
//! block across that boundary. None of it was covered by a test.
//!
//! These exercise the one shape the selected surface uses: an escaping handler
//! that returns void, may be invoked on a thread that did not create it, and may
//! be handed a null argument on the failure path.

const std = @import("std");
const mach = @import("metal-zig");
const system = mach.system;

test "a global block invokes through the C ABI" {
    const Helper = struct {
        var observed: i32 = 0;
        fn invoke(_: *system.BlockLiteral(void), a: i32, b: i32) callconv(.c) void {
            observed = a + b;
        }
    };

    const block = system.globalBlock(Helper.invoke);
    block.invoke(.{ 2, 40 });
    try std.testing.expectEqual(@as(i32, 42), Helper.observed);
}

test "a stack block reaches its captured context" {
    const Context = extern struct { base: i32 };
    const Helper = struct {
        var observed: i32 = 0;
        fn invoke(literal: *system.BlockLiteral(Context), addend: i32) callconv(.c) void {
            observed = literal.context.base + addend;
        }
    };

    var literal = system.stackBlockLiteral(Helper.invoke, Context{ .base = 100 }, null, null);
    literal.asBlock().invoke(.{5});
    try std.testing.expectEqual(@as(i32, 105), Helper.observed);
}

test "copying a block to the heap runs copy, and releasing it runs dispose" {
    const Context = extern struct { tag: i32 };
    const Helper = struct {
        var copies: i32 = 0;
        var disposes: i32 = 0;
        fn invoke(_: *system.BlockLiteral(Context), _: i32) callconv(.c) void {}
        fn copy(
            _: *system.BlockLiteral(Context),
            _: *const system.BlockLiteral(Context),
        ) callconv(.c) void {
            copies += 1;
        }
        fn dispose(_: *const system.BlockLiteral(Context)) callconv(.c) void {
            disposes += 1;
        }
    };

    var literal = system.stackBlockLiteral(
        Helper.invoke,
        Context{ .tag = 1 },
        Helper.copy,
        Helper.dispose,
    );

    // A stack block only becomes heap-allocated when copied, and that is the
    // moment ownership of anything it captured has to be taken.
    const heap_block = literal.asBlock().copy();
    try std.testing.expectEqual(@as(i32, 1), Helper.copies);
    try std.testing.expectEqual(@as(i32, 0), Helper.disposes);

    heap_block.release();
    try std.testing.expectEqual(@as(i32, 1), Helper.disposes);
}

test "a copied block survives being invoked from another thread" {
    const Context = extern struct { base: i32 };
    const Helper = struct {
        var observed: i32 = 0;
        fn invoke(literal: *system.BlockLiteral(Context), addend: i32) callconv(.c) void {
            observed = literal.context.base + addend;
        }
        fn run(block: *system.Block(fn (i32) void)) void {
            block.invoke(.{7});
        }
    };

    var literal = system.stackBlockLiteral(Helper.invoke, Context{ .base = 1 }, null, null);
    const heap_block = literal.asBlock().copy();
    defer heap_block.release();

    // Metal calls completion handlers on its own threads, never the one that
    // created the block, so the copy has to outlive this stack frame.
    const thread = try std.Thread.spawn(.{}, Helper.run, .{heap_block});
    thread.join();
    try std.testing.expectEqual(@as(i32, 8), Helper.observed);
}

test "a handler accepts a null argument" {
    const Helper = struct {
        var saw_null = false;
        fn invoke(_: *system.BlockLiteral(void), value: ?*anyopaque) callconv(.c) void {
            saw_null = value == null;
        }
    };

    // The success path of a completion handler passes a nil error, which is the
    // argument shape every generated handler has.
    const block = system.globalBlock(Helper.invoke);
    block.invoke(.{null});
    try std.testing.expect(Helper.saw_null);
}

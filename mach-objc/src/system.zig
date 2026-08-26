const builtin = @import("builtin");
const std = @import("std");

pub extern "System" fn dispatch_async(queue: *anyopaque, work: *const Block(fn (*BlockLiteral(void)) void)) void;
pub extern "System" fn dispatch_async_f(queue: *anyopaque, context: ?*anyopaque, work: *const fn (context: ?*anyopaque) callconv(.c) void) void;
pub extern "System" fn @"dispatch_assert_queue$V2"(queue: *anyopaque) void;
pub extern "System" var _dispatch_main_q: anyopaque;

pub const dispatch_source_t = *opaque {};
pub const dispatch_source_type_t = *const opaque {};
pub extern "System" var _dispatch_source_type_data_add: anyopaque;

pub extern "System" fn dispatch_source_create(source_type: dispatch_source_type_t, handle: usize, mask: usize, queue: *anyopaque) dispatch_source_t;
pub extern "System" fn dispatch_source_set_event_handler_f(source: dispatch_source_t, handler: *const fn (?*anyopaque) callconv(.c) void) void;
pub extern "System" fn dispatch_set_context(obj: *anyopaque, context: ?*anyopaque) void;
pub extern "System" fn dispatch_resume(obj: *anyopaque) void;
pub extern "System" fn dispatch_source_cancel(source: dispatch_source_t) void;
pub extern "System" fn dispatch_source_merge_data(source: dispatch_source_t, value: usize) void;

pub const dispatch_semaphore_t = *opaque {};
pub const DISPATCH_TIME_NOW: u64 = 0;
pub const DISPATCH_TIME_FOREVER: u64 = ~@as(u64, 0);
pub extern "System" fn dispatch_semaphore_create(value: isize) ?dispatch_semaphore_t;
pub extern "System" fn dispatch_semaphore_wait(dsema: dispatch_semaphore_t, timeout: u64) isize;
pub extern "System" fn dispatch_semaphore_signal(dsema: dispatch_semaphore_t) isize;

extern fn _Block_copy(*const anyopaque) *anyopaque; // Provided by libSystem on iOS but not macOS.
extern fn _Block_release(*const anyopaque) void; // Provided by libSystem on iOS but not macOS.

pub fn Block(comptime Signature: type) type {
    const signature_fn_info = @typeInfo(Signature).@"fn";
    return opaque {
        pub fn invoke(self: *@This(), args: std.meta.ArgsTuple(Signature)) signature_fn_info.return_type.? {
            const SignatureForInvoke = comptime init: {
                var param_types: []const type = &.{*@This()};
                var param_attrs: []const std.builtin.Type.Fn.Param.Attributes = &.{std.builtin.Type.Fn.Param.Attributes{}};
                for (signature_fn_info.params) |p| {
                    param_types = param_types ++ .{p.type.?};
                    param_attrs = param_attrs ++ .{std.builtin.Type.Fn.Param.Attributes{}};
                }
                break :init @Fn(
                    param_types,
                    @ptrCast(param_attrs.ptr),
                    signature_fn_info.return_type.?,
                    .{ .@"callconv" = .c },
                );
            };

            const offset = @offsetOf(BlockLiteral(void), "invoke");
            const base: [*]const u8 = @ptrCast(self);
            const invoke_ptr: *const *const SignatureForInvoke = @ptrCast(@alignCast(base + offset));
            return @call(.auto, invoke_ptr.*, .{self} ++ args);
        }

        pub fn copy(self: *const @This()) *@This() {
            return @ptrCast(_Block_copy(self));
        }

        pub fn release(self: *const @This()) void {
            _Block_release(self);
        }
    };
}

pub fn BlockLiteral(comptime Context: type) type {
    return extern struct {
        isa: *anyopaque,
        flags: i32,
        reserved: i32 = 0,
        invoke: *const anyopaque,
        descriptor: *const anyopaque,
        context: Context,

        fn trivialStaticDescriptor() *const anyopaque {
            return TrivialBlockDescriptor.static(@sizeOf(@This()));
        }

        fn copyDisposeStaticDescriptor(comptime copy: anytype, comptime dispose: anytype) *const anyopaque {
            return CopyDisposeBlockDescriptor(Context).static(@sizeOf(@This()), copy, dispose);
        }

        pub fn asBlockWithSignature(self: *@This(), comptime Signature: type) *Block(Signature) {
            return @ptrCast(self);
        }

        pub fn release(self: *const @This()) void {
            _Block_release(self);
        }
    };
}

pub fn BlockLiteralWithSignature(comptime Context: type, comptime Signature: type) type {
    // We could also obtain `Context` from `@typeInfo(Signature).@"fn".params[0].type`.
    return extern struct {
        literal: BlockLiteral(Context),

        pub fn asBlock(self: *@This()) *Block(Signature) {
            return self.literal.asBlockWithSignature(Signature);
        }
    };
}

const TrivialBlockDescriptor = extern struct {
    reserved: c_ulong = 0,
    size: c_ulong,

    fn static(comptime size: c_ulong) *const TrivialBlockDescriptor {
        const Static = struct {
            const descriptor: TrivialBlockDescriptor = .{ .size = size };
        };
        return &Static.descriptor;
    }
};

fn CopyDisposeBlockDescriptor(comptime Context: type) type {
    return extern struct {
        reserved: c_ulong = 0,
        size: c_ulong,
        copy: *const CopyFn,
        dispose: *const DisposeFn,

        pub const CopyFn = fn (dst: *BlockLiteral(Context), src: *const BlockLiteral(Context)) callconv(.c) void;
        pub const DisposeFn = fn (block: *const BlockLiteral(Context)) callconv(.c) void;

        fn static(comptime size: c_ulong, comptime copy: CopyFn, comptime dispose: DisposeFn) *const CopyDisposeBlockDescriptor {
            const Static = struct {
                const descriptor: CopyDisposeBlockDescriptor = .{
                    .size = size,
                    .copy = copy,
                    .dispose = dispose,
                };
            };
            return &Static.descriptor;
        }
    };
}

fn SignatureWithoutBlockLiteral(comptime Signature: type) type {
    const fn_info = @typeInfo(Signature).@"fn";
    var param_types: []const type = &.{};
    var param_attrs: []const std.builtin.Type.Fn.Param.Attributes = &.{};
    for (fn_info.params[1..]) |p| {
        param_types = param_types ++ .{p.type.?};
        param_attrs = param_attrs ++ .{std.builtin.Type.Fn.Param.Attributes{}};
    }
    return @Fn(
        param_types,
        @ptrCast(param_attrs.ptr),
        fn_info.return_type.?,
        .{},
    );
}

fn validateBlockSignature(comptime Invoke: type, comptime ExpectedLiteralType: type) void {
    switch (@typeInfo(Invoke)) {
        .@"fn" => |fn_info| {
            // TODO: unsure how to write this with latest Zig version
            // if (fn_info.calling_convention != .c) {
            //     @compileError("A block's `invoke` must use the C calling convention");
            // }

            // TODO: should we allow zero params? At the ABI-level it would be fine but I think the compiler might consider it UB.
            if (fn_info.params.len == 0 or fn_info.params[0].type != *ExpectedLiteralType) {
                @compileError("The first parameter for a block's `invoke` must be a block literal pointer");
            }
        },
        else => @compileError("A block's `invoke` must be a function"),
    }
}

pub fn stackBlockLiteral(
    invoke: anytype,
    context: anytype,
    comptime copy: ?fn (dst: *BlockLiteral(@TypeOf(context)), src: *const BlockLiteral(@TypeOf(context))) callconv(.c) void,
    comptime dispose: ?fn (block: *const BlockLiteral(@TypeOf(context))) callconv(.c) void,
) BlockLiteralWithSignature(@TypeOf(context), SignatureWithoutBlockLiteral(@TypeOf(invoke))) {
    const Context = @TypeOf(context);
    const Literal = BlockLiteral(Context);
    comptime {
        validateBlockSignature(@TypeOf(invoke), Literal);
        if ((copy == null) != (dispose == null)) {
            @compileError("Both `copy` and `dispose` must either be null or nonnull");
        }
    }
    // const has_copy_dispose = if (comptime copy != null and dispose != null) 1 << 25 else 0;
    const has_copy_dispose = comptime copy != null and dispose != null;
    return .{
        .literal = .{
            .isa = _NSConcreteStackBlock,
            .flags = if (has_copy_dispose) 1 << 25 else 0,
            .invoke = invoke,
            .descriptor = if (has_copy_dispose) Literal.copyDisposeStaticDescriptor(copy, dispose) else Literal.trivialStaticDescriptor(),
            .context = context,
        },
    };
}
const _NSConcreteStackBlock = @extern(*anyopaque, .{
    .name = "_NSConcreteStackBlock",
    .library_name = if (builtin.target.os.tag == .macos) null else "System",
});

pub fn globalBlockLiteral(invoke: anytype, context: anytype) BlockLiteralWithSignature(@TypeOf(context), SignatureWithoutBlockLiteral(@TypeOf(invoke))) {
    const Context = @TypeOf(context);
    const Literal = BlockLiteral(Context);
    comptime {
        validateBlockSignature(@TypeOf(invoke), Literal);
    }
    const block_is_no_escape = 1 << 23;
    const block_is_global = 1 << 28;
    return .{
        .literal = .{
            .isa = _NSConcreteGlobalBlock,
            .flags = block_is_no_escape | block_is_global,
            .invoke = invoke,
            .descriptor = Literal.trivialStaticDescriptor(),
            .context = context,
        },
    };
}
const _NSConcreteGlobalBlock = @extern(*anyopaque, .{
    .name = "_NSConcreteGlobalBlock",
    .library_name = if (builtin.target.os.tag == .macos) null else "System",
});

pub fn globalBlock(comptime invoke: anytype) *Block(SignatureWithoutBlockLiteral(@TypeOf(invoke))) {
    const Static = struct {
        const literal = globalBlockLiteral(invoke, {});
    };
    return Static.literal.asBlock();
}

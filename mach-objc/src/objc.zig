const builtin = @import("builtin");
const std = @import("std");

comptime {
    if (builtin.target.cpu.arch != .aarch64 or builtin.target.os.tag != .macos) {
        @compileError("mach-objc requires the aarch64-macos target");
    }
}

// LLVM's documented ARC APIs that technically aren't part of libobjc's public API.
pub const AutoreleasePoolToken = opaque {};
extern "objc" fn objc_autoreleasePoolPop(pool: *AutoreleasePoolToken) void;
extern "objc" fn objc_autoreleasePoolPush() *AutoreleasePoolToken;

pub const autoreleasePoolPop = objc_autoreleasePoolPop;
pub const autoreleasePoolPush = objc_autoreleasePoolPush;

/// A scoped Objective-C autorelease pool.
///
/// Keep this value in one variable and call `deinit()` exactly once; copying it would duplicate
/// ownership of the underlying runtime token.
pub const AutoreleasePool = struct {
    token: ?*AutoreleasePoolToken,

    pub fn init() AutoreleasePool {
        return .{ .token = objc_autoreleasePoolPush() };
    }

    pub fn deinit(self: *AutoreleasePool) void {
        const token = self.token orelse @panic("Objective-C autorelease pool deinitialized twice");
        self.token = null;
        objc_autoreleasePoolPop(token);
    }
};

extern "objc" fn objc_autorelease(*Id) *Id; // Same as `[object autorelease]`.
extern "objc" fn objc_release(*Id) void; // Same as `[object release]`.
extern "objc" fn objc_retain(*Id) *Id; // Same as `[object retain]`.

pub const autorelease = objc_autorelease;
pub const release = objc_release;
pub const retain = objc_retain;

// APIs that are part of libobjc's public ABI, but not its public API.
extern "objc" fn objc_alloc(class: *Class) ?*Id; // Same as `[Class alloc]`.
extern "objc" fn objc_alloc_init(class: *Class) ?*Id; // Same as `[[Class alloc] init]`.
extern "objc" fn objc_opt_new(class: *Class) ?*Id; // Same as `[Class new]`.
extern "objc" fn objc_opt_class(object: ?*Id) ?*Class; // Same as `[object class]`.
extern "objc" fn objc_opt_isKindOfClass(object: ?*Id, class: ?*Class) bool; // Same as `[object isKindOfClass:class]`.

pub const alloc = objc_alloc_init;
pub const alloc_init = objc_alloc_init;
pub const opt_new = objc_opt_new;
pub const opt_class = objc_opt_class;
pub const opt_isKindOfClass = objc_opt_isKindOfClass;

/// Equal to `[obj isKindOfClass:[Class class]]` in ObjC.
///
/// Accepts any pointer to a Zig wrapper class (e.g. `foundation.AttributedString`) as `T`, and
/// any object pointer as `obj`.
pub fn isKindOf(obj: anytype, comptime T: type) bool {
    return objc_opt_isKindOfClass(@ptrCast(obj), T.InternalInfo.class());
}

// APIs that are part of libobjc's public API.
pub const Class = opaque {};
pub const Id = opaque {
    pub const InternalInfo = struct {
        pub fn canCastTo(comptime Base: type) bool {
            return Base == Id;
        }

        pub fn as(self: *Id, comptime Base: type) *Base {
            if (comptime Base == Id) return self;
            @compileError("Cannot cast `Id` to `" ++ @typeName(Base) ++ "`");
        }
    };
    pub const as = InternalInfo.as;
    pub const retain = objc_retain;
    pub const release = objc_release;
    pub const autorelease = objc_autorelease;
};

extern "objc" fn sel_registerName(name: [*:0]const u8) ?*Selector;
extern "objc" fn class_getMethodImplementation(cls: ?*Class, name: ?*Selector) ?*const fn () callconv(.c) void;

fn registerSelector(comptime name: []const u8) *Selector {
    return sel_registerName(name ++ "\x00") orelse unreachable;
}

/// Returns a typed Zig function pointer that calls the superclass's IMP for `selector`.
///
/// `SuperClass` is the Zig wrapper for the immediate parent class (e.g. `app_kit.View`)
///
/// `Fn` is the same signature as your override (`fn(*Self, args...) Ret`)
///
/// Example:
/// ```zig
/// // objc:
/// // new_self = [super initWithFrame:frame];
///
/// // zig:
/// const new_self = objc.superFn(
///     app_kit.View, "initWithFrame:",
///     fn (*Self, app_kit.Rect) ?*Self,
/// )(self, frame) orelse return null;
/// ```
pub fn superFn(
    comptime SuperClass: type,
    comptime selector: []const u8,
    comptime Fn: type,
) *const Fn {
    const fn_info = @typeInfo(Fn).@"fn";
    const Ret = fn_info.return_type.?;

    // Build the IMP type: fn(self, _cmd: ?*Selector, args...) callconv(.c) Ret.
    const ImpFn = comptime init: {
        const Attrs = std.builtin.Type.Fn.Param.Attributes;
        var param_types: []const type = &.{ fn_info.params[0].type.?, ?*anyopaque };
        var param_attrs: []const Attrs = &.{ Attrs{}, Attrs{} };
        for (fn_info.params[1..]) |p| {
            param_types = param_types ++ .{p.type.?};
            param_attrs = param_attrs ++ .{Attrs{}};
        }
        break :init @Fn(param_types, @ptrCast(param_attrs.ptr), Ret, .{ .@"callconv" = .c });
    };

    // Per-(SuperClass, selector, Fn) cache. Selector registration is idempotent, and atomic
    // selector/IMP publication makes concurrent first use race-free.
    const Cache = struct {
        var selector_cache = std.atomic.Value(?*Selector).init(null);
        var imp = std.atomic.Value(?*const ImpFn).init(null);

        fn getSelector() *Selector {
            if (selector_cache.load(.acquire)) |cached| return cached;

            const registered = registerSelector(selector);
            if (selector_cache.cmpxchgStrong(null, registered, .acq_rel, .acquire)) |existing| {
                return existing.?;
            }
            return registered;
        }

        fn get(sel: *Selector) *const ImpFn {
            if (imp.load(.acquire)) |cached| return cached;

            const resolved: *const ImpFn = @ptrCast(
                class_getMethodImplementation(SuperClass.InternalInfo.class(), sel) orelse unreachable,
            );
            if (imp.cmpxchgStrong(null, resolved, .acq_rel, .acquire)) |existing| {
                return existing.?;
            }
            return resolved;
        }
    };

    // Build a typed Zig stub of `Fn` that injects `_cmd` and calls the cached IMP.
    return switch (fn_info.params.len) {
        1 => &(struct {
            pub fn impl(a0: fn_info.params[0].type.?) Ret {
                const sel = Cache.getSelector();
                return Cache.get(sel)(a0, sel);
            }
        }.impl),
        2 => &(struct {
            pub fn impl(a0: fn_info.params[0].type.?, a1: fn_info.params[1].type.?) Ret {
                const sel = Cache.getSelector();
                return Cache.get(sel)(a0, sel, a1);
            }
        }.impl),
        3 => &(struct {
            pub fn impl(a0: fn_info.params[0].type.?, a1: fn_info.params[1].type.?, a2: fn_info.params[2].type.?) Ret {
                const sel = Cache.getSelector();
                return Cache.get(sel)(a0, sel, a1, a2);
            }
        }.impl),
        4 => &(struct {
            pub fn impl(a0: fn_info.params[0].type.?, a1: fn_info.params[1].type.?, a2: fn_info.params[2].type.?, a3: fn_info.params[3].type.?) Ret {
                const sel = Cache.getSelector();
                return Cache.get(sel)(a0, sel, a1, a2, a3);
            }
        }.impl),
        5 => &(struct {
            pub fn impl(a0: fn_info.params[0].type.?, a1: fn_info.params[1].type.?, a2: fn_info.params[2].type.?, a3: fn_info.params[3].type.?, a4: fn_info.params[4].type.?) Ret {
                const sel = Cache.getSelector();
                return Cache.get(sel)(a0, sel, a1, a2, a3, a4);
            }
        }.impl),
        else => @compileError("superFn: unsupported arity (max 5; bump table if needed)"),
    };
}

/// Calls `objc_msgSend(receiver, selector, args...)` on Apple ARM64.
///
/// Be careful. The return type and argument types *must* match the Objective-C method's signature.
/// No compile-time verification is performed.
///
/// We resolve the selector at runtime via `sel_registerName` and call plain `objc_msgSend`, caching
/// the canonical SEL per call site so initialized calls only require an atomic load.
pub fn msgSend(receiver: anytype, comptime selector: []const u8, return_type: type, args: anytype) return_type {
    const n_colons = comptime std.mem.count(u8, selector, ":");
    if (comptime n_colons != args.len) {
        @compileError(std.fmt.comptimePrint(
            "Selector `{s}` has {} argument{s}, but {} were given",
            .{ selector, n_colons, (if (n_colons == 1) "" else "s"), args.len },
        ));
    }

    // TODO: Consider run-time signature verification if `builtin.mode == .Debug` (or use some other
    // toggle). Register the selector, then call `class_getInstanceMethod()` or
    // `class_getClassMethod()`, then call `method_getTypeEncoding()`, and then parse the string and
    // validate it against `receiver` and `args`.

    const Fn = comptime init: {
        var param_types: []const type = &.{ @TypeOf(receiver), ?*Selector };
        var param_attrs: []const std.builtin.Type.Fn.Param.Attributes = &.{
            std.builtin.Type.Fn.Param.Attributes{},
            std.builtin.Type.Fn.Param.Attributes{},
        };
        for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            param_types = param_types ++ .{field.type};
            param_attrs = param_attrs ++ .{std.builtin.Type.Fn.Param.Attributes{}};
        }
        break :init @Fn(
            param_types,
            @ptrCast(param_attrs.ptr),
            return_type,
            .{ .@"callconv" = .c },
        );
    };

    // Resolve the selector via the runtime once per call site; cache the result so subsequent
    // calls are a single atomic load. Registration is idempotent, so concurrent first use may
    // register more than once before one thread publishes the canonical selector.
    const SelCache = struct {
        var sel = std.atomic.Value(?*Selector).init(null);

        fn get() *Selector {
            if (sel.load(.acquire)) |cached| return cached;

            const registered = registerSelector(selector);
            if (sel.cmpxchgStrong(null, registered, .acq_rel, .acquire)) |existing| {
                return existing.?;
            }
            return registered;
        }
    };
    const msg_send_fn = @extern(*const Fn, .{ .name = "objc_msgSend" });
    return @call(.auto, msg_send_fn, .{ receiver, SelCache.get() } ++ args);
}

/// Returns whether an Objective-C object or class implements `selector`.
///
/// A null optional receiver returns `false`, matching Objective-C nil messaging semantics.
pub fn respondsTo(receiver: anytype, comptime selector: []const u8) bool {
    switch (@typeInfo(@TypeOf(receiver))) {
        .pointer => {},
        .optional => |optional| {
            if (@typeInfo(optional.child) != .pointer) {
                @compileError("respondsTo receiver must be an Objective-C object or class pointer");
            }
            if (receiver == null) return false;
        },
        else => @compileError("respondsTo receiver must be an Objective-C object or class pointer"),
    }

    return msgSend(
        receiver,
        "respondsToSelector:",
        bool,
        .{Selector.named(selector)},
    );
}

pub fn ExternClass(comptime name: []const u8, T: type, Super: type, comptime protocols: []const type) type {
    return struct {
        pub const class_name = name;
        var cached_class = std.atomic.Value(?*Class).init(null);

        /// Returns a typed Zig function pointer for an Obj-C `direct_method` on this class.
        /// `Fn` must match the IMP's C ABI signature.
        pub fn directMethod(comptime sel: []const u8, comptime Fn: type) *const Fn {
            return @extern(*const Fn, .{ .name = "\x01-[" ++ name ++ " " ++ sel ++ "]" });
        }

        /// Resolves the Objective-C class through the runtime, returning null when it is not
        /// available in the running process. Missing classes are not cached so a later framework
        /// or bundle load can make the class available.
        pub fn classIfAvailable() ?*Class {
            if (cached_class.load(.acquire)) |cached| return cached;

            const resolved = objc_getClass(name ++ "\x00") orelse return null;
            if (cached_class.cmpxchgStrong(null, resolved, .acq_rel, .acquire)) |existing| {
                return existing.?;
            }
            return resolved;
        }

        /// Resolves the Objective-C class or fails clearly when the running OS does not provide it.
        pub fn class() *Class {
            return classIfAvailable() orelse
                @panic("Objective-C class `" ++ name ++ "` is unavailable");
        }

        pub fn canCastTo(comptime Base: type) bool {
            if (Base == T) return true;
            inline for (protocols) |P| {
                if (P.InternalInfo.canCastTo(Base)) return true;
            }
            return Super.InternalInfo.canCastTo(Base);
        }

        pub fn as(self: *T, comptime Base: type) *Base {
            if (comptime canCastTo(Base)) return @ptrCast(self);
            @compileError("Cannot cast `" ++ @typeName(T) ++ "` to `" ++ @typeName(Base) ++ "`");
        }

        // The runtime returns a nullable id from all three: +new and +alloc can
        // fail, and a class may override +alloc or -init to return nil. Casting
        // that to a non-optional pointer discards the one signal the runtime
        // gives, so the optional is carried through to the caller.
        pub fn new() ?*T {
            return @ptrCast(opt_new(class()));
        }

        pub fn alloc() ?*T {
            return @ptrCast(objc_alloc(class()));
        }

        pub fn allocInit() ?*T {
            return @ptrCast(alloc_init(class()));
        }

        pub fn retain(self: *T) *T {
            return @ptrCast(objc_retain(@ptrCast(self)));
        }

        pub fn release(self: *T) void {
            return objc_release(@ptrCast(self));
        }

        pub fn autorelease(self: *T) *T {
            return @ptrCast(objc_autorelease(@ptrCast(self)));
        }
    };
}

/// Opaque handle for an Obj-C `Protocol` runtime object.
///
/// We can't get this via `@extern` to `_OBJC_PROTOCOL_$_<name>` like we do for classes: Apple's
/// iOS / macOS framework tbd stubs don't expose those symbols at link time (they only export
/// `_OBJC_CLASS_$_<name>` and method functions). The protocol object exists only inside the running
/// process. To get at it, callers go through `objc_getProtocol` at startup.
pub const Protocol = opaque {};

extern "objc" fn objc_getProtocol(name: [*:0]const u8) ?*Protocol;
extern "objc" fn class_addProtocol(cls: ?*Class, protocol: ?*Protocol) bool;
extern "objc" fn objc_getClass(name: [*:0]const u8) ?*Class;

/// Declare a Zig wrapper for an existing Obj-C `@protocol(...)`.
///
/// `runtime_name` is the protocol's true Obj-C name (e.g. `"UIApplicationDelegate"`,
/// `"NSWindowDelegate"`). It's used by `DefineClass` to register class-side conformance
/// at startup via `class_addProtocol`, the runtime counterpart of clang's class_ro
/// `base_protocols` slot. We resolve the protocol object at runtime rather than at link
/// time because iOS framework tbd stubs don't export the `_OBJC_PROTOCOL_$_<name>`
/// symbol.
pub fn ExternProtocol(comptime runtime_name: []const u8, T: type, comptime super_protocols: []const type) type {
    return struct {
        /// The protocol's runtime name, e.g. `"UIApplicationDelegate"`. Used by `DefineClass`'s
        /// startup constructor to look up the runtime `Protocol *`.
        pub const protocol_name = runtime_name;

        /// Look up the runtime `Protocol *` for this protocol. The framework that owns the protocol
        /// (`UIKit`, `AppKit`, etc.) must be loaded by dyld before this is called; in practice,
        /// that's anywhere after `__attribute__((constructor))` time on a process that links the
        /// framework.
        pub fn protocol() ?*Protocol {
            return objc_getProtocol(runtime_name ++ "\x00");
        }

        pub fn canCastTo(comptime Base: type) bool {
            if (Base == T) return true;
            inline for (super_protocols) |P| {
                if (P.InternalInfo.canCastTo(Base)) return true;
            }
            return false;
        }

        pub fn as(self: *T, comptime Base: type) *Base {
            if (comptime canCastTo(Base)) return @ptrCast(self);
            @compileError("Cannot cast `" ++ @typeName(T) ++ "` to `" ++ @typeName(Base) ++ "`");
        }

        pub fn retain(self: *T) *T {
            return @ptrCast(objc_retain(@ptrCast(self)));
        }

        pub fn release(self: *T) void {
            return objc_release(@ptrCast(self));
        }

        pub fn autorelease(self: *T) *T {
            return @ptrCast(objc_autorelease(@ptrCast(self)));
        }
    };
}

// The aarch64-macos target gate above establishes the modern LP64 Objective-C runtime.
comptime {
    std.debug.assert(@sizeOf(usize) == 8);
}

// Mach-O section names
const SEC_METHNAME = "__TEXT,__objc_methname,cstring_literals";
const SEC_METHTYPE = "__TEXT,__objc_methtype,cstring_literals";
const SEC_CLASSNAME = "__TEXT,__objc_classname,cstring_literals";
const SEC_OBJC_CONST = "__DATA,__objc_const";
const SEC_OBJC_DATA = "__DATA,__objc_data";
const SEC_OBJC_IVAR = "__DATA,__objc_ivar";
const SEC_OBJC_CLASSLIST = "__DATA,__objc_classlist,regular,no_dead_strip";
const SEC_OBJC_IMAGEINFO = "__DATA,__objc_imageinfo,regular,no_dead_strip";
const SEC_MOD_INIT_FUNC = "__DATA,__mod_init_func,mod_init_funcs";

/// Obj-C selector. Opaque struct exposed by pointer (`?*Selector` for nullable, `*Selector` for
/// non-null)
pub const Selector = opaque {
    /// Return the runtime `SEL` for `name`. The Obj-C runtime interns selectors, so repeated
    /// calls with the same name yield the same pointer, stable for the process lifetime.
    pub fn named(comptime name: []const u8) *Selector {
        return registerSelector(name);
    }
};

const IMP = *const fn () callconv(.c) void;

/// ObjC class method extern representation
const MethodT = extern struct {
    /// Initialised to a pointer to the methname C-string. The runtime rewrites this slot in place
    /// with the canonical selector during class realisation.
    name: ?*const anyopaque,
    types: [*:0]const u8,
    imp: IMP,
};
fn MethodList(comptime N: u32) type {
    return extern struct {
        entsize: u32 = @sizeOf(MethodT),
        count: u32 = N,
        methods: [N]MethodT,
    };
}

/// ObjC class @implementation var extern representation
const IVarT = extern struct {
    offset: *i32,
    name: [*:0]const u8,
    types: [*:0]const u8,
    alignment: u32,
    size: u32,
};
fn IVarList(comptime N: u32) type {
    return extern struct {
        entsize: u32 = @sizeOf(IVarT),
        count: u32 = N,
        ivars: [N]IVarT,
    };
}

/// ObjC class extern representation
const ClassRoT = extern struct {
    flags: u32,
    instance_start: u32,
    instance_size: u32,
    _reserved: u32 = 0,
    ivar_layout: ?[*]const u8,
    name: [*:0]const u8,
    base_method_list: ?*const anyopaque,
    base_protocols: ?*const anyopaque,
    ivars: ?*const anyopaque,
    weak_ivar_layout: ?[*]const u8,
    base_properties: ?*const anyopaque,
};
const ClassT = extern struct {
    isa: *const ClassT,
    superclass: *const ClassT,
    cache: *anyopaque,
    vtable: ?*const anyopaque,
    data: *const ClassRoT,
};

/// `RO_*` flag bits. Clang emits these into the `class_ro_t.flags` field; see `NonFragileClassFlags`:
/// https://github.com/llvm/llvm-project/blob/f9b5aedf6537dee0aa26c70fed32d67755e18a80/clang/lib/CodeGen/CGObjCMac.cpp#L4064
const RO_META: u32 = 1 << 0;
const RO_HAS_CXX_STRUCTORS: u32 = 1 << 2;
const RO_IS_ARR: u32 = 1 << 7; // ARC-compiled
const RO_HAS_CXX_DTOR_ONLY: u32 = 1 << 8;

/// Byte offset of the `invoke` function pointer inside an Obj-C block (`Block_layout`):
/// `{ isa, flags, reserved, invoke, descriptor }` → invoke sits at `2*sizeof(void*) + 2*sizeof(int)`
/// = 16 on LP64.
const BLOCK_INVOKE_OFFSET = 16;

/// Image-info `flags` bit emitted by clang for any TU that contains Obj-C class properties.
/// https://github.com/llvm/llvm-project/blob/f9b5aedf6537dee0aa26c70fed32d67755e18a80/clang/lib/CodeGen/CGObjCMac.cpp#L5996
const OBJC_IMAGE_HAS_CATEGORY_CLASS_PROPERTIES: u32 = 1 << 6;

const empty_cache = @extern(*anyopaque, .{ .name = "_objc_empty_cache" });
extern fn objc_retainBlock(block: ?*anyopaque) callconv(.c) ?*anyopaque;
extern fn objc_storeStrong(location: *?*anyopaque, obj: ?*anyopaque) callconv(.c) void;

/// A nominal, opaque "self" type for a given Obj-C class.
pub fn Self(comptime class_name: []const u8) type {
    return opaque {
        pub const __objc_self_class_name: []const u8 = class_name;
    };
}

/// Look up the runtime-patched ivar offset variable for a given class + ivar by name. The Obj-C
/// runtime updates this `i32` during class realisation, so reading it gives the byte offset of the
/// ivar inside the object (accounting for superclass size growth).
fn ivarOffsetExtern(comptime class: []const u8, comptime field: []const u8) *const i32 {
    return @extern(*const i32, .{ .name = "OBJC_IVAR_$_" ++ class ++ "." ++ field });
}

/// Read an ivar slot for a given offset variable. The runtime patches each `_OBJC_IVAR_$_…` offset
/// during class realisation, so always read it dynamically.
fn ivarSlot(self: ?*anyopaque, offset: *const i32) ?*?*anyopaque {
    const obj = self orelse return null;
    return @ptrFromInt(@intFromPtr(obj) + @as(usize, @intCast(offset.*)));
}

/// Standard "store" semantics for a block-typed ivar: retain the new block, release the old one.
/// Same pattern clang's `setBlock_*` direct methods produce.
fn setBlockIvar(self: ?*anyopaque, offset: *const i32, block: ?*anyopaque) void {
    const slot = ivarSlot(self, offset) orelse return;
    const new = objc_retainBlock(block);
    const old = slot.*;
    slot.* = new;
    if (old) |o| objc_release(@ptrCast(o));
}

/// Typed ivar accessors. Each `@implementation.<field>` is one of these, chosen by inspecting the
/// layout-struct field's type.
///
///  - `objc.Block(Fn)`         -> `Accessor.Block(Fn)`
///  - `objc.StrongObject(name)`    -> `Accessor.StrongObject`
///  - anything else                -> `Accessor.Raw`
///
/// All accessors expose `.slot(self) -> ?*?*anyopaque` for direct slot access. Block/strong-object
/// accessors layer typed `invoke`, `get`, and `set` on top.
const Accessor = struct {
    /// Accessor for a `Block`-typed ivar. Carries the runtime-patched `_OBJC_IVAR_$_<class>.<field>`
    /// offset and exposes `invoke`, `get`, `set`, and `slot` operations.
    fn Block(comptime Fn: type) type {
        return struct {
            offset: *const i32,

            const fn_info = @typeInfo(Fn).@"fn";

            /// Address of the slot holding the block pointer inside `obj`.
            pub fn slot(b: @This(), obj: ?*anyopaque) ?*?*anyopaque {
                return ivarSlot(obj, b.offset);
            }

            /// Raw block pointer currently stored, or `null`.
            pub fn get(b: @This(), obj: ?*anyopaque) ?*anyopaque {
                const slot_ptr = ivarSlot(obj, b.offset) orelse return null;
                return slot_ptr.*;
            }

            /// Install `block` with retain-new / release-old semantics.
            pub fn set(b: @This(), obj: ?*anyopaque, block: ?*anyopaque) void {
                setBlockIvar(obj, b.offset, block);
            }

            /// Invoke the stored block with `args`. Returns `null` (and does nothing) if the
            /// slot is empty; otherwise wraps and returns the block's return value.
            pub fn invoke(b: @This(), obj: ?*anyopaque, args: anytype) ?fn_info.return_type.? {
                const Return = fn_info.return_type.?;
                const slot_ptr = ivarSlot(obj, b.offset) orelse return null;
                const block = slot_ptr.* orelse return null;

                const InvokeFn = comptime init: {
                    const Attrs = std.builtin.Type.Fn.Param.Attributes;
                    var param_types: []const type = &.{?*anyopaque};
                    var param_attrs: []const Attrs = &.{Attrs{}};
                    for (fn_info.params) |p| {
                        param_types = param_types ++ .{p.type.?};
                        param_attrs = param_attrs ++ .{Attrs{}};
                    }
                    break :init @Fn(
                        param_types,
                        @ptrCast(param_attrs.ptr),
                        Return,
                        .{ .@"callconv" = .c },
                    );
                };

                const invoke_ptr: *const *const InvokeFn = @ptrFromInt(@intFromPtr(block) + BLOCK_INVOKE_OFFSET);
                return @call(.auto, invoke_ptr.*, .{block} ++ args);
            }
        };
    }

    /// Accessor for a `StrongObject`-typed ivar.
    const StrongObject = struct {
        offset: *const i32,

        pub fn slot(s: @This(), obj: ?*anyopaque) ?*?*anyopaque {
            return ivarSlot(obj, s.offset);
        }

        pub fn get(s: @This(), obj: ?*anyopaque) ?*anyopaque {
            const slot_ptr = ivarSlot(obj, s.offset) orelse return null;
            return slot_ptr.*;
        }

        /// Sets the strong object using ARC `objc_storeStrong` semantics
        pub fn set(s: @This(), obj: ?*anyopaque, value: ?*anyopaque) void {
            const slot_ptr = ivarSlot(obj, s.offset) orelse return;
            objc_storeStrong(slot_ptr, value);
        }
    };

    /// Fallback accessor for ivars providing raw slot access.
    const Raw = struct {
        offset: *const i32,

        pub fn slot(r: @This(), obj: ?*anyopaque) ?*?*anyopaque {
            return ivarSlot(obj, r.offset);
        }

        pub fn get(r: @This(), obj: ?*anyopaque) ?*anyopaque {
            const slot_ptr = ivarSlot(obj, r.offset) orelse return null;
            return slot_ptr.*;
        }

        /// Direct store; no ARC bookkeeping.
        pub fn set(r: @This(), obj: ?*anyopaque, value: ?*anyopaque) void {
            const slot_ptr = ivarSlot(obj, r.offset) orelse return;
            slot_ptr.* = value;
        }
    };

    fn Type(comptime T: type) type {
        if (comptime isBlockType(T)) return @This().Block(T.__objc_block_fn);
        if (comptime isStrongObjectType(T)) return @This().StrongObject;
        return Raw;
    }
};

fn Implementation(comptime Layout: type) type {
    const fields = @typeInfo(Layout).@"struct".fields;
    var names: [fields.len + 1][]const u8 = undefined;
    var types: [fields.len + 1]type = undefined;
    var attrs: [fields.len + 1]std.builtin.Type.StructField.Attributes = undefined;

    // Slot 0: comptime `Layout: type = Layout`.
    names[0] = "Layout";
    types[0] = type;
    const layout_default: type = Layout;
    attrs[0] = .{ .@"comptime" = true, .default_value_ptr = @ptrCast(&layout_default) };

    // Slots 1..fields.len: one typed accessor per layout field.
    inline for (fields, 1..) |f, i| {
        names[i] = f.name;
        types[i] = Accessor.Type(f.type);
        attrs[i] = .{};
    }
    return @Struct(.auto, null, &names, &types, &attrs);
}

/// Provides an Implementation describing the layout and typed accessors.
///
/// ```zig
/// pub const implementation = objc.implementation(class_name, struct {
///     _keyDown_block: objc.Block(fn (?*Event) void),
///     _displayLink: objc.StrongObject("CAMetalDisplayLink"),
/// });
/// // _ = implementation._keyDown_block.invoke(self, .{event});
/// // implementation._displayLink.set(self, link);
/// // _ = implementation.Layout; // Layout type
/// ```
pub fn implementation(comptime class_name: []const u8, comptime Layout: type) Implementation(Layout) {
    var v: Implementation(Layout) = undefined;
    inline for (@typeInfo(Layout).@"struct".fields) |f| {
        @field(v, f.name) = .{ .offset = ivarOffsetExtern(class_name, f.name) };
    }
    return v;
}

/// Place a NUL-terminated C string in a specific Mach-O section and return a pointer to it. Each
/// unique (section, string) pair gets its own anonymous storage backed by a generic struct (so the
/// symbol is uniquely named per call site).
fn cstr(comptime section: []const u8, comptime s: []const u8) *const [s.len:0]u8 {
    const Holder = struct {
        const data: [s.len:0]u8 linksection(section) = blk: {
            var arr: [s.len:0]u8 = undefined;
            for (s, 0..) |c, i| arr[i] = c;
            arr[s.len] = 0;
            break :blk arr;
        };
    };
    return &Holder.data;
}

/// Reserve a unique top-level `i32` for the `_OBJC_IVAR_$_<class>.<field>` offset slot, initialized
/// with the static (clang-style) byte offset. The Obj-C runtime patches this value during class
/// realisation. The returned pointer is stable across calls with the same `(class, field)`.
fn ivarOffsetStorage(
    comptime class: []const u8,
    comptime field: []const u8,
    comptime initial: i32,
) *i32 {
    // The inner `Holder` carries a comptime-unique tag array, so Zig generates a distinct struct
    // (and therefore distinct top-level `var value: i32`) per `(class, field)` combination — but
    // the same type, and thus the same storage, when called twice with identical args. That lets
    // the ivar list and the export loop both reference the exact same backing storage.
    const tag = class ++ "/" ++ field;
    const Holder = struct {
        // Force struct identity to depend on (class, field).
        const _tag: [tag.len]u8 = tag[0..tag.len].*;
        var value: i32 linksection(SEC_OBJC_IVAR) = initial;
    };
    return &Holder.value;
}

fn superclassClassExtern(comptime Superclass: type) *const ClassT {
    return @extern(*const ClassT, .{ .name = "OBJC_CLASS_$_" ++ Superclass.InternalInfo.class_name });
}

fn superclassMetaclassExtern(comptime Superclass: type) *const ClassT {
    return @extern(*const ClassT, .{ .name = "OBJC_METACLASS_$_" ++ Superclass.InternalInfo.class_name });
}

/// All static class metadata uses `instance_start = sizeof(NSObject) = 8` regardless of actual
/// superclass. The Obj-C runtime computes `diff = real_super_instance_size - instance_start` at
/// class realisation, adds it to every `IVarT.offset`, and patches `instance_start` /
/// `instance_size` to their final values. This means the same numeric offsets work whether you
/// subclass NSObject or NSView; the runtime makes the layout right at load time.
const INSTANCE_START: u32 = 8;

const Method = struct {
    sel: []const u8,
    types: []const u8,
    imp: IMP,
};

const DirectMethod = struct {
    sel: []const u8,
    imp: IMP,
};

const Ivar = struct {
    name: []const u8,
    type: []const u8 = "@?", // default: dispatch_block_t
    size: u32 = 8,
    alignment_log2: u32 = 3,
    /// Marks a strong-object reference for ARC bookkeeping.
    strong: bool = false,
};

/// Marker type for an Obj-C block-typed ivar (`void (^)(...)`).
pub fn Block(comptime Fn: type) type {
    return extern struct {
        ptr: ?*anyopaque = null,
        pub const __objc_block_fn = Fn;
        comptime {
            std.debug.assert(@sizeOf(@This()) == 8);
            std.debug.assert(@alignOf(@This()) == 8);
        }
    };
}

/// Marker type for a strong Obj-C object-pointer ivar.
pub fn StrongObject(comptime class_name_str: []const u8) type {
    return extern struct {
        ptr: ?*anyopaque = null,
        pub const __objc_strong_class: []const u8 = class_name_str;
        comptime {
            std.debug.assert(@sizeOf(@This()) == 8);
            std.debug.assert(@alignOf(@This()) == 8);
        }
    };
}

fn isBlockType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "__objc_block_fn"),
        else => false,
    };
}

fn isStrongObjectType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "__objc_strong_class"),
        else => false,
    };
}

/// Reflects on a struct describing an ivar layout and produce the `Ivar` slice
fn ivarsFromStruct(comptime S: type) []const Ivar {
    const fields = @typeInfo(S).@"struct".fields;
    var out: [fields.len]Ivar = undefined;
    inline for (fields, 0..) |f, i| {
        const T = f.type;
        var enc: []const u8 = "@";
        var strong = false;
        if (comptime isBlockType(T)) {
            enc = "@?";
            strong = true;
        } else if (comptime isStrongObjectType(T)) {
            enc = "@\"" ++ T.__objc_strong_class ++ "\"";
            strong = true;
        } else switch (@typeInfo(T)) {
            .pointer, .optional => {},
            else => @compileError("ivarsFromStruct: unsupported field type " ++ @typeName(T)),
        }
        out[i] = .{
            .name = f.name,
            .type = enc,
            .size = @sizeOf(T),
            .alignment_log2 = @ctz(@as(u32, @alignOf(T))),
            .strong = strong,
        };
    }
    const final = out;
    return &final;
}

/// Wrap a user-written method (signature `fn(self, args...) Ret`) into a trampoline whose signature
/// matches the Obj-C IMP ABI `fn(self, _cmd: ?*Selector, args...) callconv(.c) Ret`, so they don't need to
/// write the _cmd slot into their signature.
fn Trampoline(comptime user_fn: anytype) type {
    const UserFn = @typeInfo(@TypeOf(user_fn)).pointer.child;
    const info = @typeInfo(UserFn).@"fn";
    const Ret = info.return_type.?;
    if (info.params.len == 0) @compileError("method must have at least a `self` parameter");
    return switch (info.params.len) {
        1 => struct {
            const A0 = info.params[0].type.?;
            pub fn impl(a0: A0, _: ?*Selector) callconv(.c) Ret {
                return user_fn(a0);
            }
        },
        2 => struct {
            const A0 = info.params[0].type.?;
            const A1 = info.params[1].type.?;
            pub fn impl(a0: A0, _: ?*Selector, a1: A1) callconv(.c) Ret {
                return user_fn(a0, a1);
            }
        },
        3 => struct {
            const A0 = info.params[0].type.?;
            const A1 = info.params[1].type.?;
            const A2 = info.params[2].type.?;
            pub fn impl(a0: A0, _: ?*Selector, a1: A1, a2: A2) callconv(.c) Ret {
                return user_fn(a0, a1, a2);
            }
        },
        4 => struct {
            const A0 = info.params[0].type.?;
            const A1 = info.params[1].type.?;
            const A2 = info.params[2].type.?;
            const A3 = info.params[3].type.?;
            pub fn impl(a0: A0, _: ?*Selector, a1: A1, a2: A2, a3: A3) callconv(.c) Ret {
                return user_fn(a0, a1, a2, a3);
            }
        },
        5 => struct {
            const A0 = info.params[0].type.?;
            const A1 = info.params[1].type.?;
            const A2 = info.params[2].type.?;
            const A3 = info.params[3].type.?;
            const A4 = info.params[4].type.?;
            pub fn impl(a0: A0, _: ?*Selector, a1: A1, a2: A2, a3: A3, a4: A4) callconv(.c) Ret {
                return user_fn(a0, a1, a2, a3, a4);
            }
        },
        else => @compileError("Trampoline: unsupported arity (max 5 user params; bump table if needed)"),
    };
}

/// Build a `Method` entry from a user-written `fn(self, args...) Ret` type.
fn method(comptime sel: []const u8, user_fn: anytype) Method {
    const T = Trampoline(user_fn);
    const ImplFn = @typeInfo(@TypeOf(&T.impl)).pointer.child;
    return .{
        .sel = sel,
        .types = comptime typeEncoding(ImplFn),
        .imp = @ptrCast(&T.impl),
    };
}

fn encodeOne(comptime T: type) []const u8 {
    return switch (T) {
        void => "v",
        bool => "B",
        u8 => "C",
        i8 => "c",
        u16 => "S",
        i16 => "s",
        u32 => "I",
        i32 => "i",
        u64, usize => "Q",
        i64, isize => "q",
        f32 => "f",
        f64 => "d",
        ?*Selector => ":",
        else => switch (@typeInfo(T)) {
            // All pointers/optionals are encoded as `id` for simplicity. The runtime doesn't
            // validate this, and it's how clang emits type encodings for plain `id` arguments
            // anyway.
            .pointer, .optional => "@",

            // Function pointers / blocks.
            .@"fn" => "?",

            // Structs are encoded as `{Name=field-encodings…}`. Use the last segment of the Zig
            // type name as the tag.
            .@"struct" => |s| blk: {
                const full = @typeName(T);
                const tag = if (std.mem.lastIndexOfScalar(u8, full, '.')) |i| full[i + 1 ..] else full;
                var fields_enc: []const u8 = "";
                for (s.fields) |f| fields_enc = fields_enc ++ encodeOne(f.type);
                break :blk "{" ++ tag ++ "=" ++ fields_enc ++ "}";
            },
            else => @compileError("typeEncoding: unsupported type " ++ @typeName(T)),
        },
    };
}

/// Type-encoding
///
/// The Objective-C "encoded type" string for a method has the form:
///
/// ```
/// <return><total_arg_size><arg1><off1><arg2><off2>...
/// ```
///
/// Each `<argN>` is one of the single-letter codes from `<objc/runtime.h>` described in `encodeOne`
/// Offsets are the cumulative byte size of preceding arguments — i.e. the slot offsets in the C
/// calling convention's logical argument area.
///
/// On LP64 (which we require) every pointer (id, selector, *anyopaque) is 8 bytes, so the arithmetic is
/// straightforward.
fn typeEncoding(comptime Fn: type) [:0]const u8 {
    @setEvalBranchQuota(100_000);
    const info = @typeInfo(Fn).@"fn";
    const ret = encodeOne(info.return_type orelse void);

    comptime var size: usize = 0;
    comptime var args: []const u8 = "";
    inline for (info.params) |p| {
        const T = p.type orelse @compileError("typeEncoding: parameter has no type");
        args = args ++ encodeOne(T) ++ std.fmt.comptimePrint("{d}", .{size});
        size += @sizeOf(T);
    }
    return std.fmt.comptimePrint("{s}{d}{s}", .{ ret, size, args });
}

fn computeIvarOffsets(comptime ivars: []const Ivar) [ivars.len]i32 {
    var offsets: [ivars.len]i32 = undefined;
    var off: u32 = INSTANCE_START;
    for (ivars, 0..) |iv, i| {
        const align_to: u32 = @as(u32, 1) << @intCast(iv.alignment_log2);
        off = (off + align_to - 1) & ~(align_to - 1);
        offsets[i] = @intCast(off);
        off += iv.size;
    }
    return offsets;
}

fn computeInstanceSize(comptime ivars: []const Ivar) u32 {
    var off: u32 = INSTANCE_START;
    for (ivars) |iv| {
        const align_to: u32 = @as(u32, 1) << @intCast(iv.alignment_log2);
        off = (off + align_to - 1) & ~(align_to - 1);
        off += iv.size;
    }
    return off;
}

/// ARC ivar layout: a sequence of nibbles `(skip, scan)` describing strong-object runs. e.g. one
/// strong ivar at slot 0 → `\x01`. No strong ivars → empty (caller passes null instead).
fn computeIvarLayout(comptime ivars: []const Ivar) []const u8 {
    var bytes: []const u8 = "";
    var skip: u32 = 0;
    var scan: u32 = 0;
    for (ivars) |iv| {
        if (iv.strong) {
            scan += 1;
            if (scan == 15) {
                bytes = bytes ++ &[_]u8{(skip << 4) | scan};
                skip = 0;
                scan = 0;
            }
        } else {
            if (scan > 0) {
                bytes = bytes ++ &[_]u8{(skip << 4) | scan};
                skip = 0;
                scan = 0;
            }
            skip += 1;
            if (skip == 15) {
                bytes = bytes ++ &[_]u8{(skip << 4)};
                skip = 0;
            }
        }
    }
    if (scan > 0) bytes = bytes ++ &[_]u8{(skip << 4) | scan};
    return bytes;
}

fn hasMethod(comptime methods: []const Method, comptime sel: []const u8) bool {
    for (methods) |m| {
        if (std.mem.eql(u8, m.sel, sel)) return true;
    }
    return false;
}

/// Defines an Objective-C class in pure Zig. Returns a ClassWrapper which helps enables usage and
/// instantiation of the class from Zig.
///
/// ```zig
/// pub const MyWindowDelegate = objc.DefineClass(struct {
///     pub const class_name = "MyWindowDelegate";
///     pub const superclass = foundation.ObjectInterface;
///
///     // Optional. Enables comptime-checked `as(Base)` upcasts to a protocol.
///     pub const protocols = &.{app_kit.WindowDelegate};
///
///     pub const Self = objc.Self(class_name);
///
///     // @implementation
///     pub const implementation = objc.implementation(class_name, struct {
///         _windowDidResize_block: objc.Block(fn () void),        // -> Accessor.Block
///         _displayLink: objc.StrongObject("CAMetalDisplayLink"), // -> Accessor.StrongObject
///         _observer: *anyopaque,                                 // -> Accessor.Raw
///     });
///
///     // Each fn here becomes an Obj-C class method.
///     pub const methods = struct {
///         pub fn @"windowDidResize:"(self: *Self, _: ?*app_kit.Notification) void {
///             // Access our @implementation variables.
///             _ = implementation._windowDidResize_block.invoke(self, .{});
///         }
///     };
///
///     // Optional: fns here become `-[Class sel:]` direct methods.
///     pub const direct_methods = struct {
///         pub fn @"setRunBlock:"(self: *Self, block: ?*anyopaque) callconv(.c) void {
///             // ...
///         }
///     };
/// });
///
/// // The returned ClassWrapper can be used to instantiate the class, set implementation variables,
/// // and call methods/direct_methods:
/// const d = MyWindowDelegate.allocInit();
/// d.set(.observer, ctx);
/// d.call(.@"windowDidResize:", .{null});
/// ```
pub fn DefineClass(comptime Spec: type) type {
    @setEvalBranchQuota(100_000);

    const name = Spec.class_name;
    const superclass = Spec.superclass;
    const arc: bool = if (@hasDecl(Spec, "arc")) Spec.arc else true;
    const protocols: []const type = if (@hasDecl(Spec, "protocols")) Spec.protocols else &.{};

    const ivars: []const Ivar = if (@hasDecl(Spec, "implementation"))
        comptime ivarsFromStruct(Spec.implementation.Layout)
    else if (@hasDecl(Spec, "ivars"))
        &Spec.ivars
    else
        &[_]Ivar{};

    // Build user-supplied methods, then auto-synthesize `.cxx_destruct` if there are strong ivars
    // and the user didn't write one.
    const methods: []const Method = mk: {
        var list: []const Method = &.{};
        if (@hasDecl(Spec, "methods")) {
            inline for (@typeInfo(Spec.methods).@"struct".decls) |d| {
                const fn_ptr = &@field(Spec.methods, d.name);
                list = list ++ &[_]Method{method(d.name, fn_ptr)};
            }
        }
        const need_destruct = blk: {
            if (hasMethod(list, ".cxx_destruct")) break :blk false;
            for (ivars) |iv| if (iv.strong) break :blk true;
            break :blk false;
        };
        if (need_destruct) {
            const Destruct = struct {
                pub fn impl(self: ?*anyopaque) void {
                    inline for (ivars) |iv| {
                        if (!iv.strong) continue;
                        const off = ivarOffsetExtern(name, iv.name);
                        const slot = ivarSlot(self, off) orelse return;
                        objc_storeStrong(slot, null);
                    }
                }
            };
            list = list ++ &[_]Method{method(".cxx_destruct", &Destruct.impl)};
        }
        break :mk list;
    };

    // Build user-supplied direct methods, then auto-synthesize a `setBlock_<x>:` for every strong
    // block ivar named `_<x>_block` unless the user already provided one.
    const direct_methods: []const DirectMethod = mk: {
        var list: []const DirectMethod = &.{};
        if (@hasDecl(Spec, "direct_methods")) {
            inline for (@typeInfo(Spec.direct_methods).@"struct".decls) |d| {
                const fn_ptr = &@field(Spec.direct_methods, d.name);
                list = list ++ &[_]DirectMethod{.{ .sel = d.name, .imp = @ptrCast(fn_ptr) }};
            }
        }
        inline for (ivars) |iv| skip: {
            if (!iv.strong) break :skip;
            if (!std.mem.eql(u8, iv.type, "@?")) break :skip;
            const suffix = "_block";
            if (iv.name.len <= 1 + suffix.len) break :skip;
            if (iv.name[0] != '_') break :skip;
            if (!std.mem.endsWith(u8, iv.name, suffix)) break :skip;
            const middle = iv.name[1 .. iv.name.len - suffix.len];
            const setter_sel = "setBlock_" ++ middle ++ ":";
            for (list) |dm| {
                if (std.mem.eql(u8, dm.sel, setter_sel)) break :skip;
            }
            const Setter = struct {
                pub fn impl(self: ?*anyopaque, block: ?*anyopaque) callconv(.c) void {
                    const off = ivarOffsetExtern(name, iv.name);
                    setBlockIvar(self, off, block);
                }
            };
            list = list ++ &[_]DirectMethod{.{ .sel = setter_sel, .imp = @ptrCast(&Setter.impl) }};
        }
        break :mk list;
    };

    // Pre-compute everything that depends only on the spec.
    const ivar_offsets = comptime computeIvarOffsets(ivars);
    const instance_size = comptime computeInstanceSize(ivars);
    const layout_bytes = comptime computeIvarLayout(ivars);
    const has_strong_ivars = layout_bytes.len > 0;
    const has_cxx_destruct = comptime hasMethod(methods, ".cxx_destruct");

    const class_flags: u32 = blk: {
        var f: u32 = 0;
        if (arc) f |= RO_IS_ARR;
        if (has_cxx_destruct) f |= RO_HAS_CXX_STRUCTORS | RO_HAS_CXX_DTOR_ONLY;
        break :blk f;
    };
    const meta_flags = class_flags | RO_META;

    // Anonymous container holding all per-class declarations. Each call to `DefineClass` yields a
    // unique struct type; everything inside gets a Zig-mangled symbol name unique to that type, so
    // multiple classes in the same translation unit don't collide.
    const Mod = struct {
        const class_name_str = cstr(SEC_CLASSNAME, name);
        // When there are strong ivars, the bytes live in a sectioned cstring and the class_ro
        // points at them. Otherwise `ivar_layout` is null.
        const ivar_layout_ptr: ?[*]const u8 = if (has_strong_ivars)
            @ptrCast(cstr(SEC_CLASSNAME, layout_bytes))
        else
            null;

        // One distinct top-level `i32` per ivar, exported as `_OBJC_IVAR_$_Class.field`. Storage
        // is provided by `ivarOffsetStorage`, which gives each `(class, field)` pair its own
        // unique global. The runtime patches these on class realisation.
        const ivar_list = blk: {
            var list: IVarList(ivars.len) = .{ .ivars = undefined };
            for (ivars, 0..) |iv, i| {
                list.ivars[i] = .{
                    .offset = ivarOffsetStorage(name, iv.name, ivar_offsets[i]),
                    // ivar names live in __objc_methname
                    .name = cstr(SEC_METHNAME, iv.name),
                    .types = cstr(SEC_METHTYPE, iv.type),
                    .alignment = iv.alignment_log2,
                    .size = iv.size,
                };
            }
            break :blk list;
        };
        const ivar_list_const: IVarList(ivars.len) linksection(SEC_OBJC_CONST) = ivar_list;

        const method_list = blk: {
            var list: MethodList(methods.len) = .{ .methods = undefined };
            for (methods, 0..) |m, i| {
                list.methods[i] = .{
                    .name = @ptrCast(cstr(SEC_METHNAME, m.sel)),
                    .types = cstr(SEC_METHTYPE, m.types),
                    .imp = m.imp,
                };
            }
            break :blk list;
        };
        const method_list_const: MethodList(methods.len) linksection(SEC_OBJC_CONST) = method_list;

        const meta_ro: ClassRoT linksection(SEC_OBJC_CONST) = .{
            .flags = meta_flags,
            .instance_start = @sizeOf(ClassT),
            .instance_size = @sizeOf(ClassT),
            .ivar_layout = null,
            .name = class_name_str,
            .base_method_list = null,
            .base_protocols = null,
            .ivars = null,
            .weak_ivar_layout = null,
            .base_properties = null,
        };

        const class_ro: ClassRoT linksection(SEC_OBJC_CONST) = .{
            .flags = class_flags,
            .instance_start = INSTANCE_START,
            .instance_size = instance_size,
            .ivar_layout = ivar_layout_ptr,
            .name = class_name_str,
            .base_method_list = if (methods.len > 0) &method_list_const else null,
            // Protocol conformance is registered at startup by the `mod_init` constructor below
            // rather than via this static field, because iOS framework tbd stubs don't export
            // `_OBJC_PROTOCOL_$_<name>` so we can't get the protocol pointers at link time.
            .base_protocols = null,
            .ivars = if (ivars.len > 0) &ivar_list_const else null,
            .weak_ivar_layout = null,
            .base_properties = null,
        };

        const metaclass: ClassT linksection(SEC_OBJC_DATA) = .{
            .isa = superclassMetaclassExtern(superclass),
            .superclass = superclassMetaclassExtern(superclass),
            .cache = empty_cache,
            .vtable = null,
            .data = &meta_ro,
        };

        const class: ClassT linksection(SEC_OBJC_DATA) = .{
            .isa = &metaclass,
            .superclass = superclassClassExtern(superclass),
            .cache = empty_cache,
            .vtable = null,
            .data = &class_ro,
        };

        const classlist_entry: *const ClassT linksection(SEC_OBJC_CLASSLIST) = &class;

        const ImageInfo = extern struct { version: u32, flags: u32 };
        const image_info: ImageInfo linksection(SEC_OBJC_IMAGEINFO) = .{
            .version = 0,
            .flags = OBJC_IMAGE_HAS_CATEGORY_CLASS_PROPERTIES,
        };

        /// Module initializer that wires up `Spec.protocols` at process startup. Dyld runs every
        /// pointer in `__DATA,__mod_init_func` once the image (and everything it links against) is
        /// loaded; that's before `main()` and well before `UIApplicationMain` queries
        /// `class_conformsToProtocol`. We have to do it here rather than via the static
        /// `class_ro.base_protocols` slot because Apple's iOS / macOS framework tbd stubs don't
        /// expose `_OBJC_PROTOCOL_$_<name>` at link time — `objc_getProtocol` is the only way to
        /// obtain the protocol object.
        fn modInit() callconv(.c) void {
            if (protocols.len == 0) return;
            // Resolve the class through the runtime rather than dereferencing the static
            // `_OBJC_CLASS_$_<name>` symbol directly: `class_addProtocol` reaches into the realized
            // `class_rw_t`, which is only set up the first time the runtime looks the class up.
            const cls = objc_getClass(name ++ "\x00");
            inline for (protocols) |P| {
                if (P.InternalInfo.protocol()) |p| {
                    _ = class_addProtocol(cls, p);
                }
            }
        }
        const mod_init_ptr: *const fn () callconv(.c) void linksection(SEC_MOD_INIT_FUNC) = &modInit;
    };

    // Linker-visible Mach-O exports. We match clang naming here.
    //
    // Note: Zig auto-prepends Darwin's `_` prefix to `.name`. To suppress it (for symbols like
    // `-[Class sel:]` whose Mach-O name has no leading underscore), prefix with `\x01`.
    @export(&Mod.class, .{
        .name = "OBJC_CLASS_$_" ++ name,
        .linkage = .strong,
        .section = SEC_OBJC_DATA,
    });
    @export(&Mod.metaclass, .{
        .name = "OBJC_METACLASS_$_" ++ name,
        .linkage = .strong,
        .section = SEC_OBJC_DATA,
    });

    inline for (ivars, 0..) |iv, i| {
        // clang emits `_OBJC_IVAR_$_<Class>.<ivar>` (with a literal `.` separating the class name
        // from the ivar name). Reuse the exact same backing storage that the ivar list points at.
        @export(ivarOffsetStorage(name, iv.name, ivar_offsets[i]), .{
            .name = "OBJC_IVAR_$_" ++ name ++ "." ++ iv.name,
            .linkage = .strong,
            .visibility = .hidden,
            .section = SEC_OBJC_IVAR,
        });
    }

    inline for (methods) |m| {
        @export(m.imp, .{
            .name = "\x01-[" ++ name ++ " " ++ m.sel ++ "]",
            .linkage = .strong,
        });
    }

    inline for (direct_methods) |dm| {
        @export(dm.imp, .{
            .name = "\x01-[" ++ name ++ " " ++ dm.sel ++ "]",
            .linkage = .strong,
            .visibility = .hidden,
        });
    }

    // Force the classlist + image_info entries to be linked into the final binary by @exporting
    // them, so that `NSClassFromString("Foo")` can find our class.
    // The exported names are arbitrary but must be unique per class to avoid linker collisions; we
    // hide their visibility because nothing outside the image needs them.
    @export(&Mod.classlist_entry, .{
        .name = "\x01l_OBJC_LABEL_CLASS_$_" ++ name,
        .linkage = .strong,
        .visibility = .hidden,
        .section = SEC_OBJC_CLASSLIST,
    });
    @export(&Mod.image_info, .{
        .name = "\x01l_OBJC_IMAGE_INFO_" ++ name,
        .linkage = .strong,
        .visibility = .hidden,
        .section = SEC_OBJC_IMAGEINFO,
    });
    if (protocols.len > 0) {
        // The per-class mod_init pointer needs an @export for the same reason classlist_entry does:
        // without it, Zig drops the unused storage before the linker ever sees the `__mod_init_func`
        // section, so dyld has nothing to run at image load.
        @export(&Mod.mod_init_ptr, .{
            .name = "\x01l_OBJC_MOD_INIT_PROTOCOLS_$_" ++ name,
            .linkage = .strong,
            .visibility = .hidden,
            .section = SEC_MOD_INIT_FUNC,
        });
    }

    return ClassWrapper(Spec);
}

/// The consumer-facing wrapper type returned by `DefineClass`.
fn ClassWrapper(comptime Spec: type) type {
    const protocols: []const type = if (@hasDecl(Spec, "protocols")) Spec.protocols else &.{};

    const CallTag = comptime CallTagEnum(Spec);
    const method_count = if (@hasDecl(Spec, "methods")) @typeInfo(Spec.methods).@"struct".decls.len else 0;
    const SpecSelf = if (@hasDecl(Spec, "Self")) Spec.Self else opaque {};

    return opaque {
        /// InternalInfo to allow a Zig-defined class to act as the superclass for another class
        pub const InternalInfo = @This();
        pub const class_name = Spec.class_name;

        /// Re-export of the spec's `implementation` namespace. Use this to read/write ivars
        /// from outside the class definition:
        ///
        ///     MACHView.implementation._ctx.set(view, ctx);
        ///     MACHView.implementation._displayLink.get(view);
        ///
        /// Inside the spec's own method IMPs you can refer to it as bare `implementation`.
        pub const implementation = if (@hasDecl(Spec, "implementation")) Spec.implementation else {};

        const Extern = ExternClass(Spec.class_name, @This(), Spec.superclass, protocols);
        pub const class = Extern.class;
        pub const canCastTo = Extern.canCastTo;
        pub const as = Extern.as;
        pub const new = Extern.new;
        pub const alloc = Extern.alloc;
        pub const allocInit = Extern.allocInit;
        pub const retain = Extern.retain;
        pub const release = Extern.release;
        pub const autorelease = Extern.autorelease;

        /// Calls an Obj-C method or direct method on the class.
        ///
        /// The tag is the selector with any trailing `:` stripped and internal `:` replaced by `_`,
        /// e.g. `initWithFrame:` -> `.initWithFrame` or `metalDisplayLink:needsUpdate:` -> `.metalDisplayLink_needsUpdate`
        /// The tag namespace is the union of `Spec.methods` and `Spec.direct_methods`.
        ///
        /// Return type is inferred from the IMP signature, with `Self` rewritten to `@This()`
        pub fn call(o: *@This(), comptime tag: CallTag, args: anytype) CallReturn(tag) {
            if (comptime @typeInfo(CallTag).@"enum".fields.len == 0) {
                @compileError(Spec.class_name ++ " declares no methods");
            }
            switch (tag) {
                inline else => |t| {
                    const idx = comptime @intFromEnum(t);
                    if (comptime idx < method_count) {
                        const decls = comptime @typeInfo(Spec.methods).@"struct".decls;
                        const sel = comptime decls[idx].name;
                        return msgSend(o, sel, CallReturn(t), args);
                    } else {
                        const decls = comptime @typeInfo(Spec.direct_methods).@"struct".decls;
                        const sel = comptime decls[idx - method_count].name;
                        const RawFn = @TypeOf(@field(Spec.direct_methods, sel));
                        const Fn = comptime SubstituteSelfInFn(RawFn, SpecSelf, @This());
                        const imp = Extern.directMethod(sel, Fn);
                        return @call(.auto, imp, .{o} ++ args);
                    }
                },
            }
        }

        fn CallReturn(comptime tag: CallTag) type {
            const idx = comptime @intFromEnum(tag);
            const container, const decl_idx = if (idx < method_count)
                .{ Spec.methods, idx }
            else
                .{ Spec.direct_methods, idx - method_count };
            const decls = @typeInfo(container).@"struct".decls;
            const fn_info = @typeInfo(@TypeOf(@field(container, decls[decl_idx].name))).@"fn";
            return SubstituteSelf(fn_info.return_type.?, SpecSelf, @This());
        }
    };
}

/// Builds an enum over the union of `Spec.methods` and `Spec.direct_methods` decl names.
fn CallTagEnum(comptime Spec: type) type {
    const m_decls: []const std.builtin.Type.Declaration = if (@hasDecl(Spec, "methods"))
        @typeInfo(Spec.methods).@"struct".decls
    else
        &.{};
    const d_decls: []const std.builtin.Type.Declaration = if (@hasDecl(Spec, "direct_methods"))
        @typeInfo(Spec.direct_methods).@"struct".decls
    else
        &.{};
    const total = m_decls.len + d_decls.len;
    const Tag = if (total == 0) u0 else std.math.IntFittingRange(0, total - 1);

    var names: [total][]const u8 = undefined;
    var values: [total]Tag = undefined;
    for (m_decls, 0..) |d, i| {
        names[i] = comptime selectorToTagName(d.name);
        values[i] = @intCast(i);
    }
    for (d_decls, 0..) |d, j| {
        const i = m_decls.len + j;
        names[i] = comptime selectorToTagName(d.name);
        values[i] = @intCast(i);
    }
    const final_names = names;
    const final_values = values;
    return @Enum(Tag, .exhaustive, &final_names, &final_values);
}

fn selectorToTagName(comptime selector: []const u8) []const u8 {
    var out: [selector.len]u8 = undefined;
    var n: usize = 0;
    for (selector, 0..) |c, i| {
        if (c == ':') {
            if (i == selector.len - 1) continue; // strip trailing
            out[n] = '_';
            n += 1;
        } else {
            out[n] = c;
            n += 1;
        }
    }
    const final = out[0..n].*;
    return &final;
}

fn SubstituteSelf(comptime T: type, comptime SpecSelf: type, comptime Wrapper: type) type {
    if (T == SpecSelf) return Wrapper;
    if (T == *SpecSelf) return *Wrapper;
    if (T == ?*SpecSelf) return ?*Wrapper;
    return T;
}

/// Substitutes `SpecSelf` for `Wrapper` in every param + return of a function type with
/// SubstituteSelf semantics.
fn SubstituteSelfInFn(comptime Fn: type, comptime SpecSelf: type, comptime Wrapper: type) type {
    const info = @typeInfo(Fn).@"fn";
    var param_types: [info.params.len]type = undefined;
    var param_attrs: [info.params.len]std.builtin.Type.Fn.Param.Attributes = undefined;
    for (info.params, 0..) |p, i| {
        param_types[i] = SubstituteSelf(p.type.?, SpecSelf, Wrapper);
        param_attrs[i] = .{};
    }
    const new_ret = SubstituteSelf(info.return_type.?, SpecSelf, Wrapper);
    const final_params = param_types;
    const final_attrs = param_attrs;
    return @Fn(&final_params, &final_attrs, new_ret, .{ .@"callconv" = info.calling_convention });
}

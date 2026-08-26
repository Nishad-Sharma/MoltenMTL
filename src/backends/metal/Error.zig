const std = @import("std");
const c = @import("Raw.zig").c;
const object = @import("Object.zig");

pub const Error = error{
    InvalidArgument,
    Unsupported,
    Internal,
    OutOfHostMemory,
    OutOfDeviceMemory,
};

pub const Domain = enum {
    device,
    library,
};

pub const BackendError = extern struct {
    ptr: *c.MTLError,

    fn init(ptr: *c.MTLError) BackendError {
        return .{ .ptr = ptr };
    }

    pub fn code(self: BackendError) i64 {
        return c.MTLErrorGetCode(self.ptr);
    }
    pub fn description(self: BackendError) [:0]const u8 {
        const value: [*:0]const u8 = @ptrCast(c.MTLErrorGetLocalizedDescription(self.ptr));
        return std.mem.span(value);
    }
    pub fn toError(self: BackendError, domain: Domain) Error {
        return switch (domain) {
            .device => switch (self.code()) {
                // MTLDeviceErrorNotSupported
                1 => error.Unsupported,
                else => error.Internal,
            },
            .library => switch (self.code()) {
                // MTLLibraryErrorUnsupported
                1 => error.Unsupported,
                // MTLLibraryErrorCompileFailure,
                // MTLLibraryErrorFunctionNotFound, MTLLibraryErrorFileNotFound
                3, 5, 6 => error.InvalidArgument,
                // MTLLibraryErrorInternal and unexpected codes.
                else => error.Internal,
            },
        };
    }
    pub fn deinit(self: *BackendError) void {
        object.deinit(self.ptr);
        self.* = undefined;
    }
};

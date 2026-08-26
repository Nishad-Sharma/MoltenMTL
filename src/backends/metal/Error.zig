const c = @import("c.zig").c;
const object = @import("Object.zig");

pub const Error = error{
    InvalidArgument,
    Unsupported,
    Internal,
    OutOfHostMemory,
    OutOfDeviceMemory,
};

pub fn fromMetalError(ptr: *c.NSError) Error {
    defer object.release(ptr);
    switch (c.NSErrorGetCode(ptr)) {
        1 => return error.Unsupported,
        else => return error.Internal,
    }
}

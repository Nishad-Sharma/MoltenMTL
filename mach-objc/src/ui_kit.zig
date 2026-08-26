const std = @import("std");
const ca = @import("quartz_core.zig");
const cf = @import("../core_foundation.zig");
const ns = @import("../foundation.zig");
const cg = @import("../core_graphics.zig");
const objc = @import("../objc.zig");

pub const applicationMain = UIApplicationMain;
extern fn UIApplicationMain(
    argc: c_int,
    argv: [*]*c_char,
    principalClassName: ?*ns.String,
    delegateClassName: ?*ns.String,
) c_int;

// ------------------------------------------------------------------------------------------------
// Shared

pub const ErrorDomain = ns.ErrorDomain;
pub const ErrorUserInfoKey = ns.ErrorUserInfoKey;
pub const Integer = ns.Integer;
pub const NotificationName = ns.NotificationName;
pub const TimeInterval = ns.TimeInterval;
pub const UInteger = ns.UInteger;
pub const unichar = ns.unichar;
pub const Range = ns.Range;
pub const StringEncoding = ns.StringEncoding;
pub const Array = ns.Array;
pub const String = ns.String;

// ------------------------------------------------------------------------------------------------
// Types

pub const Rect = cg.Rect;
pub const Point = cg.Point;
pub const Size = cg.Size;
pub const EdgeInsets = extern struct {
    top: cg.Float,
    left: cg.Float,
    bottom: cg.Float,
    right: cg.Float,
};

pub const RunLoopMode = *String;
pub extern const NSDefaultRunLoopMode: RunLoopMode;
pub extern const NSRunLoopCommonModes: RunLoopMode;

pub const SceneSessionRole = *String;
pub extern const UIWindowSceneSessionRoleApplication: SceneSessionRole;
pub extern const UIWindowSceneSessionRoleExternalDisplay: SceneSessionRole;

/// NSString-typed role identifier used by UISceneConfiguration / UISceneSession.
pub const UISceneSessionRole = *String;

/// NSString-typed key used in the launchOptions dictionary passed to
/// `application:didFinishLaunchingWithOptions:`.
pub const UIApplicationLaunchOptionsKey = *String;

/// Opaque forward declaration; full bindings can be added later as needed.
pub const UISceneConnectionOptions = opaque {
    pub const InternalInfo = objc.ExternClass("UISceneConnectionOptions", @This(), ns.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
};

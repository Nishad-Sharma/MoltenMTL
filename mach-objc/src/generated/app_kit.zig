const std = @import("std");
const ca = @import("quartz_core.zig");
const cf = @import("../core_foundation.zig");
const ns = @import("../foundation.zig");
const cg = @import("../core_graphics.zig");
const objc = @import("../objc.zig");

pub const applicationMain = NSApplicationMain;
extern fn NSApplicationMain(argc: c_int, argv: [*]*c_char) c_int;

pub const Integer = ns.Integer;
pub const ErrorDomain = ns.ErrorDomain;
pub const ErrorUserInfoKey = ns.ErrorUserInfoKey;
pub const NotificationName = ns.NotificationName;
pub const TimeInterval = ns.TimeInterval;
pub const UInteger = ns.UInteger;
pub const unichar = ns.unichar;
pub const Range = ns.Range;
pub const StringEncoding = ns.StringEncoding;
pub const StringTransform = ns.StringTransform;
pub const StringEncodingDetectionOptionsKey = ns.StringEncodingDetectionOptionsKey;
pub const Array = ns.Array;
pub const String = ns.String;

pub const ModalResponse = *String;
pub const PasteboardType = *String;
pub const AboutPanelOptionKey = *String;
pub const AppearanceName = *String;
pub const ModalSession = *opaque {};
pub const PrintInfoAttributeKey = *String;
pub const Rect = cg.Rect;
pub const Point = cg.Point;
pub const Size = cg.Size;
pub const RunLoopMode = *String;
pub extern const NSDefaultRunLoopMode: RunLoopMode;
pub extern const NSRunLoopCommonModes: RunLoopMode;
pub const ApplicationActivationPolicy = Integer;
pub const ApplicationActivationPolicyRegular: ApplicationActivationPolicy = 0;
pub const ApplicationActivationPolicyAccessory: ApplicationActivationPolicy = 1;
pub const ApplicationActivationPolicyProhibited: ApplicationActivationPolicy = 2;
pub const PrinterPaperName = *String;
pub const PrintJobDispositionValue = *String;
pub const InterfaceStyle = UInteger;
pub const TouchBarItemIdentifier = *String;
pub const TouchBarCustomizationIdentifier = *String;
pub const TouchBarItemPriority = f32;
pub const DeviceDescriptionKey = *String;
pub const PrinterTypeName = *String;
pub const PrintInfoSettingKey = *String;
pub const AccessibilityActionName = *String;
pub const AccessibilityAttributeName = *String;
pub const ExceptionName = *String;
pub const ImageName = *String;
pub const NibName = *String;
pub const WindowFrameAutosaveName = *String;
pub const AccessibilityParameterizedAttributeName = *String;
pub const UserInterfaceItemIdentifier = *String;

pub const TrackingAreaOptions = UInteger;
pub const TrackingMouseEnteredAndExited: TrackingAreaOptions = 1;
pub const TrackingMouseMoved: TrackingAreaOptions = 2;
pub const TrackingCursorUpdate: TrackingAreaOptions = 4;
pub const TrackingActiveWhenFirstResponder: TrackingAreaOptions = 16;
pub const TrackingActiveInKeyWindow: TrackingAreaOptions = 32;
pub const TrackingActiveInActiveApp: TrackingAreaOptions = 64;
pub const TrackingActiveAlways: TrackingAreaOptions = 128;
pub const TrackingAssumeInside: TrackingAreaOptions = 256;
pub const TrackingInVisibleRect: TrackingAreaOptions = 512;
pub const TrackingEnabledDuringMouseDrag: TrackingAreaOptions = 1024;

pub const EventMask = c_ulonglong;
pub const EventMaskLeftMouseDown: EventMask = 2;
pub const EventMaskLeftMouseUp: EventMask = 4;
pub const EventMaskRightMouseDown: EventMask = 8;
pub const EventMaskRightMouseUp: EventMask = 16;
pub const EventMaskMouseMoved: EventMask = 32;
pub const EventMaskLeftMouseDragged: EventMask = 64;
pub const EventMaskRightMouseDragged: EventMask = 128;
pub const EventMaskMouseEntered: EventMask = 256;
pub const EventMaskMouseExited: EventMask = 512;
pub const EventMaskKeyDown: EventMask = 1024;
pub const EventMaskKeyUp: EventMask = 2048;
pub const EventMaskFlagsChanged: EventMask = 4096;
pub const EventMaskAppKitDefined: EventMask = 8192;
pub const EventMaskSystemDefined: EventMask = 16384;
pub const EventMaskApplicationDefined: EventMask = 32768;
pub const EventMaskPeriodic: EventMask = 65536;
pub const EventMaskCursorUpdate: EventMask = 131072;
pub const EventMaskScrollWheel: EventMask = 4194304;
pub const EventMaskTabletPoint: EventMask = 8388608;
pub const EventMaskTabletProximity: EventMask = 16777216;
pub const EventMaskOtherMouseDown: EventMask = 33554432;
pub const EventMaskOtherMouseUp: EventMask = 67108864;
pub const EventMaskOtherMouseDragged: EventMask = 134217728;
pub const EventMaskGesture: EventMask = 536870912;
pub const EventMaskMagnify: EventMask = 1073741824;
pub const EventMaskSwipe: EventMask = 2147483648;
pub const EventMaskRotate: EventMask = 262144;
pub const EventMaskBeginGesture: EventMask = 524288;
pub const EventMaskEndGesture: EventMask = 1048576;
pub const EventMaskSmartMagnify: EventMask = 4294967296;
pub const EventMaskPressure: EventMask = 17179869184;
pub const EventMaskDirectTouch: EventMask = 137438953472;
pub const EventMaskChangeMode: EventMask = 274877906944;
pub const EventMaskMouseCancelled: EventMask = 1099511627776;
pub const EventMaskAny: EventMask = std.math.maxInt(c_ulonglong);

pub const BackingStoreType = UInteger;
pub const BackingStoreRetained: BackingStoreType = 0;
pub const BackingStoreNonretained: BackingStoreType = 1;
pub const BackingStoreBuffered: BackingStoreType = 2;

pub const EventModifierFlags = UInteger;
pub const EventModifierFlagCapsLock: EventModifierFlags = 65536;
pub const EventModifierFlagShift: EventModifierFlags = 131072;
pub const EventModifierFlagControl: EventModifierFlags = 262144;
pub const EventModifierFlagOption: EventModifierFlags = 524288;
pub const EventModifierFlagCommand: EventModifierFlags = 1048576;
pub const EventModifierFlagNumericPad: EventModifierFlags = 2097152;
pub const EventModifierFlagHelp: EventModifierFlags = 4194304;
pub const EventModifierFlagFunction: EventModifierFlags = 8388608;
pub const EventModifierFlagDeviceIndependentFlagsMask: EventModifierFlags = 4294901760;

pub const EventPhase = UInteger;
pub const EventPhaseNone: EventPhase = 0;
pub const EventPhaseBegan: EventPhase = 1;
pub const EventPhaseStationary: EventPhase = 2;
pub const EventPhaseChanged: EventPhase = 4;
pub const EventPhaseEnded: EventPhase = 8;
pub const EventPhaseCancelled: EventPhase = 16;
pub const EventPhaseMayBegin: EventPhase = 32;

pub const EventType = UInteger;
pub const EventTypeLeftMouseDown: EventType = 1;
pub const EventTypeLeftMouseUp: EventType = 2;
pub const EventTypeRightMouseDown: EventType = 3;
pub const EventTypeRightMouseUp: EventType = 4;
pub const EventTypeMouseMoved: EventType = 5;
pub const EventTypeLeftMouseDragged: EventType = 6;
pub const EventTypeRightMouseDragged: EventType = 7;
pub const EventTypeMouseEntered: EventType = 8;
pub const EventTypeMouseExited: EventType = 9;
pub const EventTypeKeyDown: EventType = 10;
pub const EventTypeKeyUp: EventType = 11;
pub const EventTypeFlagsChanged: EventType = 12;
pub const EventTypeAppKitDefined: EventType = 13;
pub const EventTypeSystemDefined: EventType = 14;
pub const EventTypeApplicationDefined: EventType = 15;
pub const EventTypePeriodic: EventType = 16;
pub const EventTypeCursorUpdate: EventType = 17;
pub const EventTypeScrollWheel: EventType = 22;
pub const EventTypeTabletPoint: EventType = 23;
pub const EventTypeTabletProximity: EventType = 24;
pub const EventTypeOtherMouseDown: EventType = 25;
pub const EventTypeOtherMouseUp: EventType = 26;
pub const EventTypeOtherMouseDragged: EventType = 27;
pub const EventTypeGesture: EventType = 29;
pub const EventTypeMagnify: EventType = 30;
pub const EventTypeSwipe: EventType = 31;
pub const EventTypeRotate: EventType = 18;
pub const EventTypeBeginGesture: EventType = 19;
pub const EventTypeEndGesture: EventType = 20;
pub const EventTypeSmartMagnify: EventType = 32;
pub const EventTypeQuickLook: EventType = 33;
pub const EventTypePressure: EventType = 34;
pub const EventTypeDirectTouch: EventType = 37;
pub const EventTypeChangeMode: EventType = 38;
pub const EventTypeMouseCancelled: EventType = 40;

pub const WindowStyleMask = UInteger;
pub const WindowStyleMaskBorderless: WindowStyleMask = 0;
pub const WindowStyleMaskTitled: WindowStyleMask = 1;
pub const WindowStyleMaskClosable: WindowStyleMask = 2;
pub const WindowStyleMaskMiniaturizable: WindowStyleMask = 4;
pub const WindowStyleMaskResizable: WindowStyleMask = 8;
pub const WindowStyleMaskTexturedBackground: WindowStyleMask = 256;
pub const WindowStyleMaskUnifiedTitleAndToolbar: WindowStyleMask = 4096;
pub const WindowStyleMaskFullScreen: WindowStyleMask = 16384;
pub const WindowStyleMaskFullSizeContentView: WindowStyleMask = 32768;
pub const WindowStyleMaskUtilityWindow: WindowStyleMask = 16;
pub const WindowStyleMaskDocModalWindow: WindowStyleMask = 64;
pub const WindowStyleMaskNonactivatingPanel: WindowStyleMask = 128;
pub const WindowStyleMaskHUDWindow: WindowStyleMask = 8192;

pub const Application = opaque {
    pub const InternalInfo = objc.ExternClass("NSApplication", @This(), Responder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn activateIgnoringOtherApps(self_: *@This(), ignoreOtherApps_: bool) void {
        return objc.msgSend(self_, "activateIgnoringOtherApps:", void, .{ignoreOtherApps_});
    }
    pub fn finishLaunching(self_: *@This()) void {
        return objc.msgSend(self_, "finishLaunching", void, .{});
    }
    pub fn run(self_: *@This()) void {
        return objc.msgSend(self_, "run", void, .{});
    }
    pub fn setActivationPolicy(self_: *@This(), activationPolicy_: ApplicationActivationPolicy) bool {
        return objc.msgSend(self_, "setActivationPolicy:", bool, .{activationPolicy_});
    }
    pub fn sharedApplication() *Application {
        return objc.msgSend(@This().InternalInfo.class(), "sharedApplication", *Application, .{});
    }
    pub fn delegate(self_: *@This()) ?*ApplicationDelegate {
        return objc.msgSend(self_, "delegate", ?*ApplicationDelegate, .{});
    }
    pub fn setDelegate(self_: *@This(), delegate_: ?*ApplicationDelegate) void {
        return objc.msgSend(self_, "setDelegate:", void, .{delegate_});
    }
    pub fn setMainMenu(self_: *@This(), mainMenu_: ?*Menu) void {
        return objc.msgSend(self_, "setMainMenu:", void, .{mainMenu_});
    }
    pub fn sendEvent(self_: *@This(), event_: *Event) void {
        return objc.msgSend(self_, "sendEvent:", void, .{event_});
    }
    pub fn nextEventMatchingMask_untilDate_inMode_dequeue(self_: *@This(), mask_: EventMask, expiration_: ?*Date, mode_: RunLoopMode, deqFlag_: bool) ?*Event {
        return objc.msgSend(self_, "nextEventMatchingMask:untilDate:inMode:dequeue:", ?*Event, .{ mask_, expiration_, mode_, deqFlag_ });
    }
    pub fn currentEvent(self_: *@This()) ?*Event {
        return objc.msgSend(self_, "currentEvent", ?*Event, .{});
    }
};

pub const Responder = opaque {
    pub const InternalInfo = objc.ExternClass("NSResponder", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn interpretKeyEvents(self_: *@This(), eventArray_: *ns.Array(*Event)) void {
        return objc.msgSend(self_, "interpretKeyEvents:", void, .{eventArray_});
    }
};

pub const Window = opaque {
    pub const InternalInfo = objc.ExternClass("NSWindow", @This(), Responder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn frameRectForContentRect(self_: *@This(), contentRect_: Rect) Rect {
        return objc.msgSend(self_, "frameRectForContentRect:", Rect, .{contentRect_});
    }
    pub fn contentRectForFrameRect(self_: *@This(), frameRect_: Rect) Rect {
        return objc.msgSend(self_, "contentRectForFrameRect:", Rect, .{frameRect_});
    }
    pub fn initWithContentRect_styleMask_backing_defer_screen(self_: *@This(), contentRect_: Rect, style_: WindowStyleMask, backingStoreType_: BackingStoreType, flag_: bool, screen_: ?*Screen) *@This() {
        return objc.msgSend(self_, "initWithContentRect:styleMask:backing:defer:screen:", *@This(), .{ contentRect_, style_, backingStoreType_, flag_, screen_ });
    }
    pub fn setFrame_display_animate(self_: *@This(), frameRect_: Rect, displayFlag_: bool, animateFlag_: bool) void {
        return objc.msgSend(self_, "setFrame:display:animate:", void, .{ frameRect_, displayFlag_, animateFlag_ });
    }
    pub fn update(self_: *@This()) void {
        return objc.msgSend(self_, "update", void, .{});
    }
    pub fn center(self_: *@This()) void {
        return objc.msgSend(self_, "center", void, .{});
    }
    pub fn makeKeyAndOrderFront(self_: *@This(), sender_: ?*objc.Id) void {
        return objc.msgSend(self_, "makeKeyAndOrderFront:", void, .{sender_});
    }
    pub fn title(self_: *@This()) *String {
        return objc.msgSend(self_, "title", *String, .{});
    }
    pub fn setTitle(self_: *@This(), title_: *String) void {
        return objc.msgSend(self_, "setTitle:", void, .{title_});
    }
    pub fn titlebarAppearsTransparent(self_: *@This()) bool {
        return objc.msgSend(self_, "titlebarAppearsTransparent", bool, .{});
    }
    pub fn setTitlebarAppearsTransparent(self_: *@This(), titlebarAppearsTransparent_: bool) void {
        return objc.msgSend(self_, "setTitlebarAppearsTransparent:", void, .{titlebarAppearsTransparent_});
    }
    pub fn contentView(self_: *@This()) ?*View {
        return objc.msgSend(self_, "contentView", ?*View, .{});
    }
    pub fn setContentView(self_: *@This(), contentView_: ?*View) void {
        return objc.msgSend(self_, "setContentView:", void, .{contentView_});
    }
    pub fn setDelegate(self_: *@This(), delegate_: ?*WindowDelegate) void {
        return objc.msgSend(self_, "setDelegate:", void, .{delegate_});
    }
    pub fn frame(self_: *@This()) Rect {
        return objc.msgSend(self_, "frame", Rect, .{});
    }
    pub fn isReleasedWhenClosed(self_: *@This()) bool {
        return objc.msgSend(self_, "isReleasedWhenClosed", bool, .{});
    }
    pub fn setReleasedWhenClosed(self_: *@This(), releasedWhenClosed_: bool) void {
        return objc.msgSend(self_, "setReleasedWhenClosed:", void, .{releasedWhenClosed_});
    }
    pub fn backgroundColor(self_: *@This()) *Color {
        return objc.msgSend(self_, "backgroundColor", *Color, .{});
    }
    pub fn setBackgroundColor(self_: *@This(), backgroundColor_: ?*Color) void {
        return objc.msgSend(self_, "setBackgroundColor:", void, .{backgroundColor_});
    }
    pub fn isVisible(self_: *@This()) bool {
        return objc.msgSend(self_, "isVisible", bool, .{});
    }
    pub fn isKeyWindow(self_: *@This()) bool {
        return objc.msgSend(self_, "isKeyWindow", bool, .{});
    }
    pub fn backingScaleFactor(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "backingScaleFactor", cg.Float, .{});
    }
    pub fn screen(self_: *@This()) ?*Screen {
        return objc.msgSend(self_, "screen", ?*Screen, .{});
    }
    pub fn setMinSize(self_: *@This(), minSize_: Size) void {
        return objc.msgSend(self_, "setMinSize:", void, .{minSize_});
    }
    pub fn sendEvent(self_: *@This(), event_: *Event) void {
        return objc.msgSend(self_, "sendEvent:", void, .{event_});
    }
    pub fn setIsVisible(self_: *@This(), flag_: bool) void {
        return objc.msgSend(self_, "setIsVisible:", void, .{flag_});
    }
};

pub const Notification = opaque {
    pub const InternalInfo = objc.ExternClass("NSNotification", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn name(self_: *@This()) NotificationName {
        return objc.msgSend(self_, "name", NotificationName, .{});
    }
    pub fn object(self_: *@This()) ?*objc.Id {
        return objc.msgSend(self_, "object", ?*objc.Id, .{});
    }
};

pub const Dictionary = opaque {
    pub const InternalInfo = objc.ExternClass("NSDictionary", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;
};

pub const Menu = opaque {
    pub const InternalInfo = objc.ExternClass("NSMenu", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn addItem(self_: *@This(), newItem_: *MenuItemProtocol) void {
        return objc.msgSend(self_, "addItem:", void, .{newItem_});
    }
    pub fn addItemWithTitle_action_keyEquivalent(self_: *@This(), string_: *String, selector_: ?*objc.Selector, charCode_: *String) *MenuItemProtocol {
        return objc.msgSend(self_, "addItemWithTitle:action:keyEquivalent:", *MenuItemProtocol, .{ string_, selector_, charCode_ });
    }
};

pub const MenuItemInterface = opaque {
    pub const InternalInfo = objc.ExternClass("NSMenuItem", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn separatorItem() *MenuItemProtocol {
        return objc.msgSend(@This().InternalInfo.class(), "separatorItem", *MenuItemProtocol, .{});
    }
    pub fn setSubmenu(self_: *@This(), submenu_: ?*Menu) void {
        return objc.msgSend(self_, "setSubmenu:", void, .{submenu_});
    }
};

pub const ObjectInterface = opaque {
    pub const InternalInfo = objc.ExternClass("NSObject", @This(), objc.Id, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn copy(self_: *@This()) *objc.Id {
        return objc.msgSend(self_, "copy", *objc.Id, .{});
    }
};

pub const Appearance = opaque {
    pub const InternalInfo = objc.ExternClass("NSAppearance", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn appearanceNamed(name_: AppearanceName) ?*Appearance {
        return objc.msgSend(@This().InternalInfo.class(), "appearanceNamed:", ?*Appearance, .{name_});
    }
};

pub const Event = opaque {
    pub const InternalInfo = objc.ExternClass("NSEvent", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn addLocalMonitorForEventsMatchingMask_handler(mask_: EventMask, block_: *ns.Block(fn (*Event) ?*Event)) ?*objc.Id {
        return objc.msgSend(@This().InternalInfo.class(), "addLocalMonitorForEventsMatchingMask:handler:", ?*objc.Id, .{ mask_, block_ });
    }
    pub fn removeMonitor(eventMonitor_: *objc.Id) void {
        return objc.msgSend(@This().InternalInfo.class(), "removeMonitor:", void, .{eventMonitor_});
    }
    pub fn @"type"(self_: *@This()) EventType {
        return objc.msgSend(self_, "type", EventType, .{});
    }
    pub fn modifierFlags(self_: *@This()) EventModifierFlags {
        return objc.msgSend(self_, "modifierFlags", EventModifierFlags, .{});
    }
    pub fn buttonNumber(self_: *@This()) Integer {
        return objc.msgSend(self_, "buttonNumber", Integer, .{});
    }
    pub fn locationInWindow(self_: *@This()) Point {
        return objc.msgSend(self_, "locationInWindow", Point, .{});
    }
    pub fn deltaX(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "deltaX", cg.Float, .{});
    }
    pub fn deltaY(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "deltaY", cg.Float, .{});
    }
    pub fn hasPreciseScrollingDeltas(self_: *@This()) bool {
        return objc.msgSend(self_, "hasPreciseScrollingDeltas", bool, .{});
    }
    pub fn scrollingDeltaX(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "scrollingDeltaX", cg.Float, .{});
    }
    pub fn scrollingDeltaY(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "scrollingDeltaY", cg.Float, .{});
    }
    pub fn isARepeat(self_: *@This()) bool {
        return objc.msgSend(self_, "isARepeat", bool, .{});
    }
    pub fn keyCode(self_: *@This()) c_ushort {
        return objc.msgSend(self_, "keyCode", c_ushort, .{});
    }
    pub fn magnification(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "magnification", cg.Float, .{});
    }
    pub fn phase(self_: *@This()) EventPhase {
        return objc.msgSend(self_, "phase", EventPhase, .{});
    }
    pub fn mouseLocation() Point {
        return objc.msgSend(@This().InternalInfo.class(), "mouseLocation", Point, .{});
    }
    pub fn T_modifierFlags() EventModifierFlags {
        return objc.msgSend(@This().InternalInfo.class(), "modifierFlags", EventModifierFlags, .{});
    }
    pub fn pressedMouseButtons() UInteger {
        return objc.msgSend(@This().InternalInfo.class(), "pressedMouseButtons", UInteger, .{});
    }
};

pub const Date = opaque {
    pub const InternalInfo = objc.ExternClass("NSDate", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn dateWithTimeIntervalSinceNow(secs_: TimeInterval) *@This() {
        return objc.msgSend(@This().InternalInfo.class(), "dateWithTimeIntervalSinceNow:", *@This(), .{secs_});
    }
    pub fn distantPast() *Date {
        return objc.msgSend(@This().InternalInfo.class(), "distantPast", *Date, .{});
    }
};

pub const View = opaque {
    pub const InternalInfo = objc.ExternClass("NSView", @This(), Responder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithFrame(self_: *@This(), frameRect_: Rect) *@This() {
        return objc.msgSend(self_, "initWithFrame:", *@This(), .{frameRect_});
    }
    pub fn addSubview(self_: *@This(), view_: *View) void {
        return objc.msgSend(self_, "addSubview:", void, .{view_});
    }
    pub fn setFrameOrigin(self_: *@This(), newOrigin_: Point) void {
        return objc.msgSend(self_, "setFrameOrigin:", void, .{newOrigin_});
    }
    pub fn setFrameSize(self_: *@This(), newSize_: Size) void {
        return objc.msgSend(self_, "setFrameSize:", void, .{newSize_});
    }
    pub fn setBoundsOrigin(self_: *@This(), newOrigin_: Point) void {
        return objc.msgSend(self_, "setBoundsOrigin:", void, .{newOrigin_});
    }
    pub fn setBoundsSize(self_: *@This(), newSize_: Size) void {
        return objc.msgSend(self_, "setBoundsSize:", void, .{newSize_});
    }
    pub fn window(self_: *@This()) ?*Window {
        return objc.msgSend(self_, "window", ?*Window, .{});
    }
    pub fn bounds(self_: *@This()) Rect {
        return objc.msgSend(self_, "bounds", Rect, .{});
    }
    pub fn visibleRect(self_: *@This()) Rect {
        return objc.msgSend(self_, "visibleRect", Rect, .{});
    }
    pub fn setWantsLayer(self_: *@This(), wantsLayer_: bool) void {
        return objc.msgSend(self_, "setWantsLayer:", void, .{wantsLayer_});
    }
    pub fn layer(self_: *@This()) *ca.Layer {
        return objc.msgSend(self_, "layer", *ca.Layer, .{});
    }
    pub fn setLayer(self_: *@This(), layer_: *ca.Layer) void {
        return objc.msgSend(self_, "setLayer:", void, .{layer_});
    }
    pub fn addTrackingArea(self_: *@This(), trackingArea_: *TrackingArea) void {
        return objc.msgSend(self_, "addTrackingArea:", void, .{trackingArea_});
    }
};

pub const Color = opaque {
    pub const InternalInfo = objc.ExternClass("NSColor", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn colorWithRed_green_blue_alpha(red_: cg.Float, green_: cg.Float, blue_: cg.Float, alpha_: cg.Float) *Color {
        return objc.msgSend(@This().InternalInfo.class(), "colorWithRed:green:blue:alpha:", *Color, .{ red_, green_, blue_, alpha_ });
    }
};

pub const Cursor = opaque {
    pub const InternalInfo = objc.ExternClass("NSCursor", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn hide() void {
        return objc.msgSend(@This().InternalInfo.class(), "hide", void, .{});
    }
    pub fn unhide() void {
        return objc.msgSend(@This().InternalInfo.class(), "unhide", void, .{});
    }
    pub fn T_pop() void {
        return objc.msgSend(@This().InternalInfo.class(), "pop", void, .{});
    }
    pub fn pop(self_: *@This()) void {
        return objc.msgSend(self_, "pop", void, .{});
    }
    pub fn push(self_: *@This()) void {
        return objc.msgSend(self_, "push", void, .{});
    }
    pub fn arrowCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "arrowCursor", *Cursor, .{});
    }
    pub fn crosshairCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "crosshairCursor", *Cursor, .{});
    }
    pub fn operationNotAllowedCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "operationNotAllowedCursor", *Cursor, .{});
    }
    pub fn pointingHandCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "pointingHandCursor", *Cursor, .{});
    }
    pub fn closedHandCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "closedHandCursor", *Cursor, .{});
    }
    pub fn openHandCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "openHandCursor", *Cursor, .{});
    }
    pub fn IBeamCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "IBeamCursor", *Cursor, .{});
    }
    pub fn resizeLeftCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeLeftCursor", *Cursor, .{});
    }
    pub fn resizeRightCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeRightCursor", *Cursor, .{});
    }
    pub fn resizeLeftRightCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeLeftRightCursor", *Cursor, .{});
    }
    pub fn resizeUpCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeUpCursor", *Cursor, .{});
    }
    pub fn resizeDownCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeDownCursor", *Cursor, .{});
    }
    pub fn resizeUpDownCursor() *Cursor {
        return objc.msgSend(@This().InternalInfo.class(), "resizeUpDownCursor", *Cursor, .{});
    }
};

pub const Screen = opaque {
    pub const InternalInfo = objc.ExternClass("NSScreen", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn screens() *ns.Array(*Screen) {
        return objc.msgSend(@This().InternalInfo.class(), "screens", *ns.Array(*Screen), .{});
    }
    pub fn mainScreen() ?*Screen {
        return objc.msgSend(@This().InternalInfo.class(), "mainScreen", ?*Screen, .{});
    }
    pub fn frame(self_: *@This()) Rect {
        return objc.msgSend(self_, "frame", Rect, .{});
    }
    pub fn maximumFramesPerSecond(self_: *@This()) Integer {
        return objc.msgSend(self_, "maximumFramesPerSecond", Integer, .{});
    }
};

pub const TrackingArea = opaque {
    pub const InternalInfo = objc.ExternClass("NSTrackingArea", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithRect_options_owner_userInfo(self_: *@This(), rect_: Rect, options_: TrackingAreaOptions, owner_: ?*objc.Id, userInfo_: ?*ns.Dictionary(*objc.Id, *objc.Id)) *@This() {
        return objc.msgSend(self_, "initWithRect:options:owner:userInfo:", *@This(), .{ rect_, options_, owner_, userInfo_ });
    }
    pub fn rect(self_: *@This()) Rect {
        return objc.msgSend(self_, "rect", Rect, .{});
    }
    pub fn options(self_: *@This()) TrackingAreaOptions {
        return objc.msgSend(self_, "options", TrackingAreaOptions, .{});
    }
    pub fn owner(self_: *@This()) ?*objc.Id {
        return objc.msgSend(self_, "owner", ?*objc.Id, .{});
    }
    pub fn userInfo(self_: *@This()) ?*ns.Dictionary(*objc.Id, *objc.Id) {
        return objc.msgSend(self_, "userInfo", ?*ns.Dictionary(*objc.Id, *objc.Id), .{});
    }
};

pub const ApplicationDelegate = opaque {
    pub const InternalInfo = objc.ExternProtocol("NSApplicationDelegate", @This(), &.{ ObjectProtocol, ObjectProtocol });
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn applicationDidFinishLaunching(self_: *@This(), notification_: *Notification) void {
        return objc.msgSend(self_, "applicationDidFinishLaunching:", void, .{notification_});
    }
};

pub const WindowDelegate = opaque {
    pub const InternalInfo = objc.ExternProtocol("NSWindowDelegate", @This(), &.{ ObjectProtocol, ObjectProtocol });
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn windowWillResize_toSize(self_: *@This(), sender_: *Window, frameSize_: Size) Size {
        return objc.msgSend(self_, "windowWillResize:toSize:", Size, .{ sender_, frameSize_ });
    }
};

pub const ObjectProtocol = opaque {
    pub const InternalInfo = objc.ExternProtocol("NSObject", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn retainCount(self_: *@This()) UInteger {
        return objc.msgSend(self_, "retainCount", UInteger, .{});
    }
};

pub const MenuItemProtocol = opaque {
    pub const InternalInfo = objc.ExternProtocol("NSMenuItem", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
};

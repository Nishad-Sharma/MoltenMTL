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

pub const UITouchPhase = ns.Integer;
pub const UITouchPhaseBegan: UITouchPhase = 0;
pub const UITouchPhaseMoved: UITouchPhase = 0;
pub const UITouchPhaseStationary: UITouchPhase = 0;
pub const UITouchPhaseEnded: UITouchPhase = 0;
pub const UITouchPhaseCancelled: UITouchPhase = 0;
pub const UITouchPhaseRegionEntered: UITouchPhase = 0;
pub const UITouchPhaseRegionMoved: UITouchPhase = 0;
pub const UITouchPhaseRegionExited: UITouchPhase = 0;

pub const UITouchType = ns.Integer;
pub const UITouchTypeDirect: UITouchType = 0;
pub const UITouchTypeIndirect: UITouchType = 0;
pub const UITouchTypePencil: UITouchType = 0;
pub const UITouchTypeStylus: UITouchType = 2;
pub const UITouchTypeIndirectPointer: UITouchType = 0;

pub const UIPressPhase = ns.Integer;
pub const UIPressPhaseBegan: UIPressPhase = 0;
pub const UIPressPhaseChanged: UIPressPhase = 0;
pub const UIPressPhaseStationary: UIPressPhase = 0;
pub const UIPressPhaseEnded: UIPressPhase = 0;
pub const UIPressPhaseCancelled: UIPressPhase = 0;

pub const UIPressType = ns.Integer;
pub const UIPressTypeUpArrow: UIPressType = 0;
pub const UIPressTypeDownArrow: UIPressType = 0;
pub const UIPressTypeLeftArrow: UIPressType = 0;
pub const UIPressTypeRightArrow: UIPressType = 0;
pub const UIPressTypeSelect: UIPressType = 0;
pub const UIPressTypeMenu: UIPressType = 0;
pub const UIPressTypePlayPause: UIPressType = 0;
pub const UIPressTypePageUp: UIPressType = 30;
pub const UIPressTypePageDown: UIPressType = 31;

pub const UIEventType = ns.Integer;
pub const UIEventTypeTouches: UIEventType = 0;
pub const UIEventTypeMotion: UIEventType = 0;
pub const UIEventTypeRemoteControl: UIEventType = 0;
pub const UIEventTypePresses: UIEventType = 0;
pub const UIEventTypeScroll: UIEventType = 10;
pub const UIEventTypeHover: UIEventType = 11;
pub const UIEventTypeTransform: UIEventType = 14;

pub const UIEventSubtype = ns.Integer;
pub const UIEventSubtypeNone: UIEventSubtype = 0;
pub const UIEventSubtypeMotionShake: UIEventSubtype = 1;
pub const UIEventSubtypeRemoteControlPlay: UIEventSubtype = 100;
pub const UIEventSubtypeRemoteControlPause: UIEventSubtype = 101;
pub const UIEventSubtypeRemoteControlStop: UIEventSubtype = 102;
pub const UIEventSubtypeRemoteControlTogglePlayPause: UIEventSubtype = 103;
pub const UIEventSubtypeRemoteControlNextTrack: UIEventSubtype = 104;
pub const UIEventSubtypeRemoteControlPreviousTrack: UIEventSubtype = 105;
pub const UIEventSubtypeRemoteControlBeginSeekingBackward: UIEventSubtype = 106;
pub const UIEventSubtypeRemoteControlEndSeekingBackward: UIEventSubtype = 107;
pub const UIEventSubtypeRemoteControlBeginSeekingForward: UIEventSubtype = 108;
pub const UIEventSubtypeRemoteControlEndSeekingForward: UIEventSubtype = 109;

pub const UISceneActivationState = ns.Integer;
pub const UISceneActivationStateUnattached: UISceneActivationState = -1;
pub const UISceneActivationStateForegroundActive: UISceneActivationState = 0;
pub const UISceneActivationStateForegroundInactive: UISceneActivationState = 0;
pub const UISceneActivationStateBackground: UISceneActivationState = 0;

pub const UIInterfaceOrientation = ns.Integer;
pub const UIInterfaceOrientationUnknown: UIInterfaceOrientation = 0;
pub const UIInterfaceOrientationPortrait: UIInterfaceOrientation = 1;
pub const UIInterfaceOrientationPortraitUpsideDown: UIInterfaceOrientation = 2;
pub const UIInterfaceOrientationLandscapeLeft: UIInterfaceOrientation = 4;
pub const UIInterfaceOrientationLandscapeRight: UIInterfaceOrientation = 3;

pub const UIInterfaceOrientationMask = ns.UInteger;
pub const UIInterfaceOrientationMaskPortrait: UIInterfaceOrientationMask = 2;
pub const UIInterfaceOrientationMaskLandscapeLeft: UIInterfaceOrientationMask = 16;
pub const UIInterfaceOrientationMaskLandscapeRight: UIInterfaceOrientationMask = 8;
pub const UIInterfaceOrientationMaskPortraitUpsideDown: UIInterfaceOrientationMask = 4;
pub const UIInterfaceOrientationMaskLandscape: UIInterfaceOrientationMask = 24;
pub const UIInterfaceOrientationMaskAll: UIInterfaceOrientationMask = 30;
pub const UIInterfaceOrientationMaskAllButUpsideDown: UIInterfaceOrientationMask = 26;

pub const UIKeyboardHIDUsage = cf.Index;
pub const UIKeyboardHIDUsageKeyboardErrorRollOver: UIKeyboardHIDUsage = 1;
pub const UIKeyboardHIDUsageKeyboardPOSTFail: UIKeyboardHIDUsage = 2;
pub const UIKeyboardHIDUsageKeyboardErrorUndefined: UIKeyboardHIDUsage = 3;
pub const UIKeyboardHIDUsageKeyboardA: UIKeyboardHIDUsage = 4;
pub const UIKeyboardHIDUsageKeyboardB: UIKeyboardHIDUsage = 5;
pub const UIKeyboardHIDUsageKeyboardC: UIKeyboardHIDUsage = 6;
pub const UIKeyboardHIDUsageKeyboardD: UIKeyboardHIDUsage = 7;
pub const UIKeyboardHIDUsageKeyboardE: UIKeyboardHIDUsage = 8;
pub const UIKeyboardHIDUsageKeyboardF: UIKeyboardHIDUsage = 9;
pub const UIKeyboardHIDUsageKeyboardG: UIKeyboardHIDUsage = 10;
pub const UIKeyboardHIDUsageKeyboardH: UIKeyboardHIDUsage = 11;
pub const UIKeyboardHIDUsageKeyboardI: UIKeyboardHIDUsage = 12;
pub const UIKeyboardHIDUsageKeyboardJ: UIKeyboardHIDUsage = 13;
pub const UIKeyboardHIDUsageKeyboardK: UIKeyboardHIDUsage = 14;
pub const UIKeyboardHIDUsageKeyboardL: UIKeyboardHIDUsage = 15;
pub const UIKeyboardHIDUsageKeyboardM: UIKeyboardHIDUsage = 16;
pub const UIKeyboardHIDUsageKeyboardN: UIKeyboardHIDUsage = 17;
pub const UIKeyboardHIDUsageKeyboardO: UIKeyboardHIDUsage = 18;
pub const UIKeyboardHIDUsageKeyboardP: UIKeyboardHIDUsage = 19;
pub const UIKeyboardHIDUsageKeyboardQ: UIKeyboardHIDUsage = 20;
pub const UIKeyboardHIDUsageKeyboardR: UIKeyboardHIDUsage = 21;
pub const UIKeyboardHIDUsageKeyboardS: UIKeyboardHIDUsage = 22;
pub const UIKeyboardHIDUsageKeyboardT: UIKeyboardHIDUsage = 23;
pub const UIKeyboardHIDUsageKeyboardU: UIKeyboardHIDUsage = 24;
pub const UIKeyboardHIDUsageKeyboardV: UIKeyboardHIDUsage = 25;
pub const UIKeyboardHIDUsageKeyboardW: UIKeyboardHIDUsage = 26;
pub const UIKeyboardHIDUsageKeyboardX: UIKeyboardHIDUsage = 27;
pub const UIKeyboardHIDUsageKeyboardY: UIKeyboardHIDUsage = 28;
pub const UIKeyboardHIDUsageKeyboardZ: UIKeyboardHIDUsage = 29;
pub const UIKeyboardHIDUsageKeyboard1: UIKeyboardHIDUsage = 30;
pub const UIKeyboardHIDUsageKeyboard2: UIKeyboardHIDUsage = 31;
pub const UIKeyboardHIDUsageKeyboard3: UIKeyboardHIDUsage = 32;
pub const UIKeyboardHIDUsageKeyboard4: UIKeyboardHIDUsage = 33;
pub const UIKeyboardHIDUsageKeyboard5: UIKeyboardHIDUsage = 34;
pub const UIKeyboardHIDUsageKeyboard6: UIKeyboardHIDUsage = 35;
pub const UIKeyboardHIDUsageKeyboard7: UIKeyboardHIDUsage = 36;
pub const UIKeyboardHIDUsageKeyboard8: UIKeyboardHIDUsage = 37;
pub const UIKeyboardHIDUsageKeyboard9: UIKeyboardHIDUsage = 38;
pub const UIKeyboardHIDUsageKeyboard0: UIKeyboardHIDUsage = 39;
pub const UIKeyboardHIDUsageKeyboardReturnOrEnter: UIKeyboardHIDUsage = 40;
pub const UIKeyboardHIDUsageKeyboardEscape: UIKeyboardHIDUsage = 41;
pub const UIKeyboardHIDUsageKeyboardDeleteOrBackspace: UIKeyboardHIDUsage = 42;
pub const UIKeyboardHIDUsageKeyboardTab: UIKeyboardHIDUsage = 43;
pub const UIKeyboardHIDUsageKeyboardSpacebar: UIKeyboardHIDUsage = 44;
pub const UIKeyboardHIDUsageKeyboardHyphen: UIKeyboardHIDUsage = 45;
pub const UIKeyboardHIDUsageKeyboardEqualSign: UIKeyboardHIDUsage = 46;
pub const UIKeyboardHIDUsageKeyboardOpenBracket: UIKeyboardHIDUsage = 47;
pub const UIKeyboardHIDUsageKeyboardCloseBracket: UIKeyboardHIDUsage = 48;
pub const UIKeyboardHIDUsageKeyboardBackslash: UIKeyboardHIDUsage = 49;
pub const UIKeyboardHIDUsageKeyboardNonUSPound: UIKeyboardHIDUsage = 50;
pub const UIKeyboardHIDUsageKeyboardSemicolon: UIKeyboardHIDUsage = 51;
pub const UIKeyboardHIDUsageKeyboardQuote: UIKeyboardHIDUsage = 52;
pub const UIKeyboardHIDUsageKeyboardGraveAccentAndTilde: UIKeyboardHIDUsage = 53;
pub const UIKeyboardHIDUsageKeyboardComma: UIKeyboardHIDUsage = 54;
pub const UIKeyboardHIDUsageKeyboardPeriod: UIKeyboardHIDUsage = 55;
pub const UIKeyboardHIDUsageKeyboardSlash: UIKeyboardHIDUsage = 56;
pub const UIKeyboardHIDUsageKeyboardCapsLock: UIKeyboardHIDUsage = 57;
pub const UIKeyboardHIDUsageKeyboardF1: UIKeyboardHIDUsage = 58;
pub const UIKeyboardHIDUsageKeyboardF2: UIKeyboardHIDUsage = 59;
pub const UIKeyboardHIDUsageKeyboardF3: UIKeyboardHIDUsage = 60;
pub const UIKeyboardHIDUsageKeyboardF4: UIKeyboardHIDUsage = 61;
pub const UIKeyboardHIDUsageKeyboardF5: UIKeyboardHIDUsage = 62;
pub const UIKeyboardHIDUsageKeyboardF6: UIKeyboardHIDUsage = 63;
pub const UIKeyboardHIDUsageKeyboardF7: UIKeyboardHIDUsage = 64;
pub const UIKeyboardHIDUsageKeyboardF8: UIKeyboardHIDUsage = 65;
pub const UIKeyboardHIDUsageKeyboardF9: UIKeyboardHIDUsage = 66;
pub const UIKeyboardHIDUsageKeyboardF10: UIKeyboardHIDUsage = 67;
pub const UIKeyboardHIDUsageKeyboardF11: UIKeyboardHIDUsage = 68;
pub const UIKeyboardHIDUsageKeyboardF12: UIKeyboardHIDUsage = 69;
pub const UIKeyboardHIDUsageKeyboardPrintScreen: UIKeyboardHIDUsage = 70;
pub const UIKeyboardHIDUsageKeyboardScrollLock: UIKeyboardHIDUsage = 71;
pub const UIKeyboardHIDUsageKeyboardPause: UIKeyboardHIDUsage = 72;
pub const UIKeyboardHIDUsageKeyboardInsert: UIKeyboardHIDUsage = 73;
pub const UIKeyboardHIDUsageKeyboardHome: UIKeyboardHIDUsage = 74;
pub const UIKeyboardHIDUsageKeyboardPageUp: UIKeyboardHIDUsage = 75;
pub const UIKeyboardHIDUsageKeyboardDeleteForward: UIKeyboardHIDUsage = 76;
pub const UIKeyboardHIDUsageKeyboardEnd: UIKeyboardHIDUsage = 77;
pub const UIKeyboardHIDUsageKeyboardPageDown: UIKeyboardHIDUsage = 78;
pub const UIKeyboardHIDUsageKeyboardRightArrow: UIKeyboardHIDUsage = 79;
pub const UIKeyboardHIDUsageKeyboardLeftArrow: UIKeyboardHIDUsage = 80;
pub const UIKeyboardHIDUsageKeyboardDownArrow: UIKeyboardHIDUsage = 81;
pub const UIKeyboardHIDUsageKeyboardUpArrow: UIKeyboardHIDUsage = 82;
pub const UIKeyboardHIDUsageKeypadNumLock: UIKeyboardHIDUsage = 83;
pub const UIKeyboardHIDUsageKeypadSlash: UIKeyboardHIDUsage = 84;
pub const UIKeyboardHIDUsageKeypadAsterisk: UIKeyboardHIDUsage = 85;
pub const UIKeyboardHIDUsageKeypadHyphen: UIKeyboardHIDUsage = 86;
pub const UIKeyboardHIDUsageKeypadPlus: UIKeyboardHIDUsage = 87;
pub const UIKeyboardHIDUsageKeypadEnter: UIKeyboardHIDUsage = 88;
pub const UIKeyboardHIDUsageKeypad1: UIKeyboardHIDUsage = 89;
pub const UIKeyboardHIDUsageKeypad2: UIKeyboardHIDUsage = 90;
pub const UIKeyboardHIDUsageKeypad3: UIKeyboardHIDUsage = 91;
pub const UIKeyboardHIDUsageKeypad4: UIKeyboardHIDUsage = 92;
pub const UIKeyboardHIDUsageKeypad5: UIKeyboardHIDUsage = 93;
pub const UIKeyboardHIDUsageKeypad6: UIKeyboardHIDUsage = 94;
pub const UIKeyboardHIDUsageKeypad7: UIKeyboardHIDUsage = 95;
pub const UIKeyboardHIDUsageKeypad8: UIKeyboardHIDUsage = 96;
pub const UIKeyboardHIDUsageKeypad9: UIKeyboardHIDUsage = 97;
pub const UIKeyboardHIDUsageKeypad0: UIKeyboardHIDUsage = 98;
pub const UIKeyboardHIDUsageKeypadPeriod: UIKeyboardHIDUsage = 99;
pub const UIKeyboardHIDUsageKeyboardNonUSBackslash: UIKeyboardHIDUsage = 100;
pub const UIKeyboardHIDUsageKeyboardApplication: UIKeyboardHIDUsage = 101;
pub const UIKeyboardHIDUsageKeyboardPower: UIKeyboardHIDUsage = 102;
pub const UIKeyboardHIDUsageKeypadEqualSign: UIKeyboardHIDUsage = 103;
pub const UIKeyboardHIDUsageKeyboardF13: UIKeyboardHIDUsage = 104;
pub const UIKeyboardHIDUsageKeyboardF14: UIKeyboardHIDUsage = 105;
pub const UIKeyboardHIDUsageKeyboardF15: UIKeyboardHIDUsage = 106;
pub const UIKeyboardHIDUsageKeyboardF16: UIKeyboardHIDUsage = 107;
pub const UIKeyboardHIDUsageKeyboardF17: UIKeyboardHIDUsage = 108;
pub const UIKeyboardHIDUsageKeyboardF18: UIKeyboardHIDUsage = 109;
pub const UIKeyboardHIDUsageKeyboardF19: UIKeyboardHIDUsage = 110;
pub const UIKeyboardHIDUsageKeyboardF20: UIKeyboardHIDUsage = 111;
pub const UIKeyboardHIDUsageKeyboardF21: UIKeyboardHIDUsage = 112;
pub const UIKeyboardHIDUsageKeyboardF22: UIKeyboardHIDUsage = 113;
pub const UIKeyboardHIDUsageKeyboardF23: UIKeyboardHIDUsage = 114;
pub const UIKeyboardHIDUsageKeyboardF24: UIKeyboardHIDUsage = 115;
pub const UIKeyboardHIDUsageKeyboardExecute: UIKeyboardHIDUsage = 116;
pub const UIKeyboardHIDUsageKeyboardHelp: UIKeyboardHIDUsage = 117;
pub const UIKeyboardHIDUsageKeyboardMenu: UIKeyboardHIDUsage = 118;
pub const UIKeyboardHIDUsageKeyboardSelect: UIKeyboardHIDUsage = 119;
pub const UIKeyboardHIDUsageKeyboardStop: UIKeyboardHIDUsage = 120;
pub const UIKeyboardHIDUsageKeyboardAgain: UIKeyboardHIDUsage = 121;
pub const UIKeyboardHIDUsageKeyboardUndo: UIKeyboardHIDUsage = 122;
pub const UIKeyboardHIDUsageKeyboardCut: UIKeyboardHIDUsage = 123;
pub const UIKeyboardHIDUsageKeyboardCopy: UIKeyboardHIDUsage = 124;
pub const UIKeyboardHIDUsageKeyboardPaste: UIKeyboardHIDUsage = 125;
pub const UIKeyboardHIDUsageKeyboardFind: UIKeyboardHIDUsage = 126;
pub const UIKeyboardHIDUsageKeyboardMute: UIKeyboardHIDUsage = 127;
pub const UIKeyboardHIDUsageKeyboardVolumeUp: UIKeyboardHIDUsage = 128;
pub const UIKeyboardHIDUsageKeyboardVolumeDown: UIKeyboardHIDUsage = 129;
pub const UIKeyboardHIDUsageKeyboardLockingCapsLock: UIKeyboardHIDUsage = 130;
pub const UIKeyboardHIDUsageKeyboardLockingNumLock: UIKeyboardHIDUsage = 131;
pub const UIKeyboardHIDUsageKeyboardLockingScrollLock: UIKeyboardHIDUsage = 132;
pub const UIKeyboardHIDUsageKeypadComma: UIKeyboardHIDUsage = 133;
pub const UIKeyboardHIDUsageKeypadEqualSignAS400: UIKeyboardHIDUsage = 134;
pub const UIKeyboardHIDUsageKeyboardInternational1: UIKeyboardHIDUsage = 135;
pub const UIKeyboardHIDUsageKeyboardInternational2: UIKeyboardHIDUsage = 136;
pub const UIKeyboardHIDUsageKeyboardInternational3: UIKeyboardHIDUsage = 137;
pub const UIKeyboardHIDUsageKeyboardInternational4: UIKeyboardHIDUsage = 138;
pub const UIKeyboardHIDUsageKeyboardInternational5: UIKeyboardHIDUsage = 139;
pub const UIKeyboardHIDUsageKeyboardInternational6: UIKeyboardHIDUsage = 140;
pub const UIKeyboardHIDUsageKeyboardInternational7: UIKeyboardHIDUsage = 141;
pub const UIKeyboardHIDUsageKeyboardInternational8: UIKeyboardHIDUsage = 142;
pub const UIKeyboardHIDUsageKeyboardInternational9: UIKeyboardHIDUsage = 143;
pub const UIKeyboardHIDUsageKeyboardLANG1: UIKeyboardHIDUsage = 144;
pub const UIKeyboardHIDUsageKeyboardLANG2: UIKeyboardHIDUsage = 145;
pub const UIKeyboardHIDUsageKeyboardLANG3: UIKeyboardHIDUsage = 146;
pub const UIKeyboardHIDUsageKeyboardLANG4: UIKeyboardHIDUsage = 147;
pub const UIKeyboardHIDUsageKeyboardLANG5: UIKeyboardHIDUsage = 148;
pub const UIKeyboardHIDUsageKeyboardLANG6: UIKeyboardHIDUsage = 149;
pub const UIKeyboardHIDUsageKeyboardLANG7: UIKeyboardHIDUsage = 150;
pub const UIKeyboardHIDUsageKeyboardLANG8: UIKeyboardHIDUsage = 151;
pub const UIKeyboardHIDUsageKeyboardLANG9: UIKeyboardHIDUsage = 152;
pub const UIKeyboardHIDUsageKeyboardAlternateErase: UIKeyboardHIDUsage = 153;
pub const UIKeyboardHIDUsageKeyboardSysReqOrAttention: UIKeyboardHIDUsage = 154;
pub const UIKeyboardHIDUsageKeyboardCancel: UIKeyboardHIDUsage = 155;
pub const UIKeyboardHIDUsageKeyboardClear: UIKeyboardHIDUsage = 156;
pub const UIKeyboardHIDUsageKeyboardPrior: UIKeyboardHIDUsage = 157;
pub const UIKeyboardHIDUsageKeyboardReturn: UIKeyboardHIDUsage = 158;
pub const UIKeyboardHIDUsageKeyboardSeparator: UIKeyboardHIDUsage = 159;
pub const UIKeyboardHIDUsageKeyboardOut: UIKeyboardHIDUsage = 160;
pub const UIKeyboardHIDUsageKeyboardOper: UIKeyboardHIDUsage = 161;
pub const UIKeyboardHIDUsageKeyboardClearOrAgain: UIKeyboardHIDUsage = 162;
pub const UIKeyboardHIDUsageKeyboardCrSelOrProps: UIKeyboardHIDUsage = 163;
pub const UIKeyboardHIDUsageKeyboardExSel: UIKeyboardHIDUsage = 164;
pub const UIKeyboardHIDUsageKeyboardLeftControl: UIKeyboardHIDUsage = 224;
pub const UIKeyboardHIDUsageKeyboardLeftShift: UIKeyboardHIDUsage = 225;
pub const UIKeyboardHIDUsageKeyboardLeftAlt: UIKeyboardHIDUsage = 226;
pub const UIKeyboardHIDUsageKeyboardLeftGUI: UIKeyboardHIDUsage = 227;
pub const UIKeyboardHIDUsageKeyboardRightControl: UIKeyboardHIDUsage = 228;
pub const UIKeyboardHIDUsageKeyboardRightShift: UIKeyboardHIDUsage = 229;
pub const UIKeyboardHIDUsageKeyboardRightAlt: UIKeyboardHIDUsage = 230;
pub const UIKeyboardHIDUsageKeyboardRightGUI: UIKeyboardHIDUsage = 231;
pub const UIKeyboardHIDUsageKeyboard_Reserved: UIKeyboardHIDUsage = 65535;
pub const UIKeyboardHIDUsageKeyboardHangul: UIKeyboardHIDUsage = 144;
pub const UIKeyboardHIDUsageKeyboardHanja: UIKeyboardHIDUsage = 145;
pub const UIKeyboardHIDUsageKeyboardKanaSwitch: UIKeyboardHIDUsage = 144;
pub const UIKeyboardHIDUsageKeyboardAlphanumericSwitch: UIKeyboardHIDUsage = 145;
pub const UIKeyboardHIDUsageKeyboardKatakana: UIKeyboardHIDUsage = 146;
pub const UIKeyboardHIDUsageKeyboardHiragana: UIKeyboardHIDUsage = 147;
pub const UIKeyboardHIDUsageKeyboardZenkakuHankakuKanji: UIKeyboardHIDUsage = 148;

pub const UIKeyModifierFlags = ns.Integer;
pub const UIKeyModifierAlphaShift: UIKeyModifierFlags = 65536;
pub const UIKeyModifierShift: UIKeyModifierFlags = 131072;
pub const UIKeyModifierControl: UIKeyModifierFlags = 262144;
pub const UIKeyModifierAlternate: UIKeyModifierFlags = 524288;
pub const UIKeyModifierCommand: UIKeyModifierFlags = 1048576;
pub const UIKeyModifierNumericPad: UIKeyModifierFlags = 2097152;

pub const UIGestureRecognizerState = ns.Integer;
pub const UIGestureRecognizerStatePossible: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateBegan: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateChanged: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateEnded: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateCancelled: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateFailed: UIGestureRecognizerState = 0;
pub const UIGestureRecognizerStateRecognized: UIGestureRecognizerState = 3;

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

pub const UIApplication = opaque {
    pub const InternalInfo = objc.ExternClass("UIApplication", @This(), UIResponder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn sharedApplication() *UIApplication {
        return objc.msgSend(@This().InternalInfo.class(), "sharedApplication", *UIApplication, .{});
    }
    pub fn delegate(self_: *@This()) ?*UIApplicationDelegate {
        return objc.msgSend(self_, "delegate", ?*UIApplicationDelegate, .{});
    }
    pub fn setDelegate(self_: *@This(), delegate_: ?*UIApplicationDelegate) void {
        return objc.msgSend(self_, "setDelegate:", void, .{delegate_});
    }
};

pub const UIResponder = opaque {
    pub const InternalInfo = objc.ExternClass("UIResponder", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn becomeFirstResponder(self_: *@This()) bool {
        return objc.msgSend(self_, "becomeFirstResponder", bool, .{});
    }
    pub fn resignFirstResponder(self_: *@This()) bool {
        return objc.msgSend(self_, "resignFirstResponder", bool, .{});
    }
    pub fn nextResponder(self_: *@This()) ?*UIResponder {
        return objc.msgSend(self_, "nextResponder", ?*UIResponder, .{});
    }
    pub fn canBecomeFirstResponder(self_: *@This()) bool {
        return objc.msgSend(self_, "canBecomeFirstResponder", bool, .{});
    }
};

pub const UIScene = opaque {
    pub const InternalInfo = objc.ExternClass("UIScene", @This(), UIResponder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn session(self_: *@This()) *UISceneSession {
        return objc.msgSend(self_, "session", *UISceneSession, .{});
    }
    pub fn activationState(self_: *@This()) UISceneActivationState {
        return objc.msgSend(self_, "activationState", UISceneActivationState, .{});
    }
};

pub const UISceneConfiguration = opaque {
    pub const InternalInfo = objc.ExternClass("UISceneConfiguration", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithName_sessionRole(self_: *@This(), name_: ?*ns.String, sessionRole_: UISceneSessionRole) *@This() {
        return objc.msgSend(self_, "initWithName:sessionRole:", *@This(), .{ name_, sessionRole_ });
    }
    pub fn delegateClass(self_: *@This()) ?*objc.Class {
        return objc.msgSend(self_, "delegateClass", ?*objc.Class, .{});
    }
    pub fn setDelegateClass(self_: *@This(), delegateClass_: ?*objc.Class) void {
        return objc.msgSend(self_, "setDelegateClass:", void, .{delegateClass_});
    }
};

pub const UISceneSession = opaque {
    pub const InternalInfo = objc.ExternClass("UISceneSession", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn role(self_: *@This()) UISceneSessionRole {
        return objc.msgSend(self_, "role", UISceneSessionRole, .{});
    }
    pub fn configuration(self_: *@This()) *UISceneConfiguration {
        return objc.msgSend(self_, "configuration", *UISceneConfiguration, .{});
    }
};

pub const UIWindowScene = opaque {
    pub const InternalInfo = objc.ExternClass("UIWindowScene", @This(), UIScene, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn screen(self_: *@This()) *UIScreen {
        return objc.msgSend(self_, "screen", *UIScreen, .{});
    }
    pub fn windows(self_: *@This()) *ns.Array(*UIWindow) {
        return objc.msgSend(self_, "windows", *ns.Array(*UIWindow), .{});
    }
};

pub const UIScreen = opaque {
    pub const InternalInfo = objc.ExternClass("UIScreen", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn screens() *ns.Array(*UIScreen) {
        return objc.msgSend(@This().InternalInfo.class(), "screens", *ns.Array(*UIScreen), .{});
    }
    pub fn mainScreen() *UIScreen {
        return objc.msgSend(@This().InternalInfo.class(), "mainScreen", *UIScreen, .{});
    }
    pub fn bounds(self_: *@This()) cg.Rect {
        return objc.msgSend(self_, "bounds", cg.Rect, .{});
    }
    pub fn scale(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "scale", cg.Float, .{});
    }
    pub fn nativeBounds(self_: *@This()) cg.Rect {
        return objc.msgSend(self_, "nativeBounds", cg.Rect, .{});
    }
    pub fn nativeScale(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "nativeScale", cg.Float, .{});
    }
};

pub const UIWindow = opaque {
    pub const InternalInfo = objc.ExternClass("UIWindow", @This(), UIView, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithWindowScene(self_: *@This(), windowScene_: *UIWindowScene) *@This() {
        return objc.msgSend(self_, "initWithWindowScene:", *@This(), .{windowScene_});
    }
    pub fn makeKeyAndVisible(self_: *@This()) void {
        return objc.msgSend(self_, "makeKeyAndVisible", void, .{});
    }
    pub fn windowScene(self_: *@This()) *UIWindowScene {
        return objc.msgSend(self_, "windowScene", *UIWindowScene, .{});
    }
    pub fn setWindowScene(self_: *@This(), windowScene_: *UIWindowScene) void {
        return objc.msgSend(self_, "setWindowScene:", void, .{windowScene_});
    }
    pub fn isKeyWindow(self_: *@This()) bool {
        return objc.msgSend(self_, "isKeyWindow", bool, .{});
    }
    pub fn rootViewController(self_: *@This()) *UIViewController {
        return objc.msgSend(self_, "rootViewController", *UIViewController, .{});
    }
    pub fn setRootViewController(self_: *@This(), rootViewController_: *UIViewController) void {
        return objc.msgSend(self_, "setRootViewController:", void, .{rootViewController_});
    }
};

pub const UIView = opaque {
    pub const InternalInfo = objc.ExternClass("UIView", @This(), UIResponder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithFrame(self_: *@This(), frame_: cg.Rect) *@This() {
        return objc.msgSend(self_, "initWithFrame:", *@This(), .{frame_});
    }
    pub fn layer(self_: *@This()) *ca.Layer {
        return objc.msgSend(self_, "layer", *ca.Layer, .{});
    }
    pub fn frame(self_: *@This()) cg.Rect {
        return objc.msgSend(self_, "frame", cg.Rect, .{});
    }
    pub fn setFrame(self_: *@This(), frame_: cg.Rect) void {
        return objc.msgSend(self_, "setFrame:", void, .{frame_});
    }
    pub fn bounds(self_: *@This()) cg.Rect {
        return objc.msgSend(self_, "bounds", cg.Rect, .{});
    }
    pub fn setBounds(self_: *@This(), bounds_: cg.Rect) void {
        return objc.msgSend(self_, "setBounds:", void, .{bounds_});
    }
    pub fn contentScaleFactor(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "contentScaleFactor", cg.Float, .{});
    }
    pub fn setContentScaleFactor(self_: *@This(), contentScaleFactor_: cg.Float) void {
        return objc.msgSend(self_, "setContentScaleFactor:", void, .{contentScaleFactor_});
    }
    pub fn addSubview(self_: *@This(), view_: *UIView) void {
        return objc.msgSend(self_, "addSubview:", void, .{view_});
    }
    pub fn setNeedsLayout(self_: *@This()) void {
        return objc.msgSend(self_, "setNeedsLayout", void, .{});
    }
    pub fn layoutIfNeeded(self_: *@This()) void {
        return objc.msgSend(self_, "layoutIfNeeded", void, .{});
    }
    pub fn window(self_: *@This()) ?*UIWindow {
        return objc.msgSend(self_, "window", ?*UIWindow, .{});
    }
    pub fn setNeedsDisplay(self_: *@This()) void {
        return objc.msgSend(self_, "setNeedsDisplay", void, .{});
    }
    pub fn backgroundColor(self_: *@This()) *UIColor {
        return objc.msgSend(self_, "backgroundColor", *UIColor, .{});
    }
    pub fn setBackgroundColor(self_: *@This(), backgroundColor_: *UIColor) void {
        return objc.msgSend(self_, "setBackgroundColor:", void, .{backgroundColor_});
    }
    pub fn isOpaque(self_: *@This()) bool {
        return objc.msgSend(self_, "isOpaque", bool, .{});
    }
    pub fn setOpaque(self_: *@This(), opaque_: bool) void {
        return objc.msgSend(self_, "setOpaque:", void, .{opaque_});
    }
    pub fn isHidden(self_: *@This()) bool {
        return objc.msgSend(self_, "isHidden", bool, .{});
    }
    pub fn setHidden(self_: *@This(), hidden_: bool) void {
        return objc.msgSend(self_, "setHidden:", void, .{hidden_});
    }
    pub fn addGestureRecognizer(self_: *@This(), gestureRecognizer_: *UIGestureRecognizer) void {
        return objc.msgSend(self_, "addGestureRecognizer:", void, .{gestureRecognizer_});
    }
};

pub const UIViewController = opaque {
    pub const InternalInfo = objc.ExternClass("UIViewController", @This(), UIResponder, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn view(self_: *@This()) *UIView {
        return objc.msgSend(self_, "view", *UIView, .{});
    }
    pub fn setView(self_: *@This(), view_: ?*UIView) void {
        return objc.msgSend(self_, "setView:", void, .{view_});
    }
};

pub const UITouch = opaque {
    pub const InternalInfo = objc.ExternClass("UITouch", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn locationInView(self_: *@This(), view_: ?*UIView) cg.Point {
        return objc.msgSend(self_, "locationInView:", cg.Point, .{view_});
    }
    pub fn previousLocationInView(self_: *@This(), view_: ?*UIView) cg.Point {
        return objc.msgSend(self_, "previousLocationInView:", cg.Point, .{view_});
    }
    pub fn timestamp(self_: *@This()) ns.TimeInterval {
        return objc.msgSend(self_, "timestamp", ns.TimeInterval, .{});
    }
    pub fn phase(self_: *@This()) UITouchPhase {
        return objc.msgSend(self_, "phase", UITouchPhase, .{});
    }
    pub fn tapCount(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "tapCount", ns.UInteger, .{});
    }
    pub fn @"type"(self_: *@This()) UITouchType {
        return objc.msgSend(self_, "type", UITouchType, .{});
    }
    pub fn window(self_: *@This()) ?*UIWindow {
        return objc.msgSend(self_, "window", ?*UIWindow, .{});
    }
    pub fn view(self_: *@This()) ?*UIView {
        return objc.msgSend(self_, "view", ?*UIView, .{});
    }
    pub fn force(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "force", cg.Float, .{});
    }
    pub fn maximumPossibleForce(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "maximumPossibleForce", cg.Float, .{});
    }
};

pub const UIEvent = opaque {
    pub const InternalInfo = objc.ExternClass("UIEvent", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn @"type"(self_: *@This()) UIEventType {
        return objc.msgSend(self_, "type", UIEventType, .{});
    }
    pub fn subtype(self_: *@This()) UIEventSubtype {
        return objc.msgSend(self_, "subtype", UIEventSubtype, .{});
    }
    pub fn timestamp(self_: *@This()) ns.TimeInterval {
        return objc.msgSend(self_, "timestamp", ns.TimeInterval, .{});
    }
    pub fn allTouches(self_: *@This()) ?*ns.Set(*UITouch) {
        return objc.msgSend(self_, "allTouches", ?*ns.Set(*UITouch), .{});
    }
};

pub const UIPress = opaque {
    pub const InternalInfo = objc.ExternClass("UIPress", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn phase(self_: *@This()) UIPressPhase {
        return objc.msgSend(self_, "phase", UIPressPhase, .{});
    }
    pub fn @"type"(self_: *@This()) UIPressType {
        return objc.msgSend(self_, "type", UIPressType, .{});
    }
    pub fn force(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "force", cg.Float, .{});
    }
    pub fn key(self_: *@This()) ?*UIKey {
        return objc.msgSend(self_, "key", ?*UIKey, .{});
    }
};

pub const UIPressesEvent = opaque {
    pub const InternalInfo = objc.ExternClass("UIPressesEvent", @This(), UIEvent, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn allPresses(self_: *@This()) *ns.Set(*UIPress) {
        return objc.msgSend(self_, "allPresses", *ns.Set(*UIPress), .{});
    }
};

pub const UIKey = opaque {
    pub const InternalInfo = objc.ExternClass("UIKey", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn characters(self_: *@This()) *ns.String {
        return objc.msgSend(self_, "characters", *ns.String, .{});
    }
    pub fn charactersIgnoringModifiers(self_: *@This()) *ns.String {
        return objc.msgSend(self_, "charactersIgnoringModifiers", *ns.String, .{});
    }
    pub fn modifierFlags(self_: *@This()) UIKeyModifierFlags {
        return objc.msgSend(self_, "modifierFlags", UIKeyModifierFlags, .{});
    }
    pub fn keyCode(self_: *@This()) UIKeyboardHIDUsage {
        return objc.msgSend(self_, "keyCode", UIKeyboardHIDUsage, .{});
    }
};

pub const UIGestureRecognizer = opaque {
    pub const InternalInfo = objc.ExternClass("UIGestureRecognizer", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn initWithTarget_action(self_: *@This(), target_: ?*objc.Id, action_: ?*objc.Selector) *@This() {
        return objc.msgSend(self_, "initWithTarget:action:", *@This(), .{ target_, action_ });
    }
    pub fn locationInView(self_: *@This(), view_: ?*UIView) cg.Point {
        return objc.msgSend(self_, "locationInView:", cg.Point, .{view_});
    }
    pub fn state(self_: *@This()) UIGestureRecognizerState {
        return objc.msgSend(self_, "state", UIGestureRecognizerState, .{});
    }
    pub fn numberOfTouches(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "numberOfTouches", ns.UInteger, .{});
    }
};

pub const UIPinchGestureRecognizer = opaque {
    pub const InternalInfo = objc.ExternClass("UIPinchGestureRecognizer", @This(), UIGestureRecognizer, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn scale(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "scale", cg.Float, .{});
    }
    pub fn setScale(self_: *@This(), scale_: cg.Float) void {
        return objc.msgSend(self_, "setScale:", void, .{scale_});
    }
    pub fn velocity(self_: *@This()) cg.Float {
        return objc.msgSend(self_, "velocity", cg.Float, .{});
    }
};

pub const UIColor = opaque {
    pub const InternalInfo = objc.ExternClass("UIColor", @This(), ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn colorWithRed_green_blue_alpha(red_: cg.Float, green_: cg.Float, blue_: cg.Float, alpha_: cg.Float) *UIColor {
        return objc.msgSend(@This().InternalInfo.class(), "colorWithRed:green:blue:alpha:", *UIColor, .{ red_, green_, blue_, alpha_ });
    }
    pub fn blackColor() *UIColor {
        return objc.msgSend(@This().InternalInfo.class(), "blackColor", *UIColor, .{});
    }
    pub fn whiteColor() *UIColor {
        return objc.msgSend(@This().InternalInfo.class(), "whiteColor", *UIColor, .{});
    }
    pub fn clearColor() *UIColor {
        return objc.msgSend(@This().InternalInfo.class(), "clearColor", *UIColor, .{});
    }
};

pub const UIApplicationDelegate = opaque {
    pub const InternalInfo = objc.ExternProtocol("UIApplicationDelegate", @This(), &.{ ObjectProtocol, ObjectProtocol });
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn application_didFinishLaunchingWithOptions(self_: *@This(), application_: *UIApplication, launchOptions_: ?*ns.Dictionary(UIApplicationLaunchOptionsKey, *objc.Id)) bool {
        return objc.msgSend(self_, "application:didFinishLaunchingWithOptions:", bool, .{ application_, launchOptions_ });
    }
    pub fn application_configurationForConnectingSceneSession_options(self_: *@This(), application_: *UIApplication, connectingSceneSession_: *UISceneSession, options_: *UISceneConnectionOptions) *UISceneConfiguration {
        return objc.msgSend(self_, "application:configurationForConnectingSceneSession:options:", *UISceneConfiguration, .{ application_, connectingSceneSession_, options_ });
    }
};

pub const UISceneDelegate = opaque {
    pub const InternalInfo = objc.ExternProtocol("UISceneDelegate", @This(), &.{ ObjectProtocol, ObjectProtocol });
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn sceneDidBecomeActive(self_: *@This(), scene_: *UIScene) void {
        return objc.msgSend(self_, "sceneDidBecomeActive:", void, .{scene_});
    }
    pub fn sceneWillResignActive(self_: *@This(), scene_: *UIScene) void {
        return objc.msgSend(self_, "sceneWillResignActive:", void, .{scene_});
    }
    pub fn sceneWillEnterForeground(self_: *@This(), scene_: *UIScene) void {
        return objc.msgSend(self_, "sceneWillEnterForeground:", void, .{scene_});
    }
    pub fn sceneDidEnterBackground(self_: *@This(), scene_: *UIScene) void {
        return objc.msgSend(self_, "sceneDidEnterBackground:", void, .{scene_});
    }
};

pub const UIWindowSceneDelegateProtocol = opaque {
    pub const InternalInfo = objc.ExternProtocol("UIWindowSceneDelegate", @This(), &.{UISceneDelegate});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
};

pub const ObjectProtocol = opaque {
    pub const InternalInfo = objc.ExternProtocol("NSObject", @This(), &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;

    pub fn retainCount(self_: *@This()) ns.UInteger {
        return objc.msgSend(self_, "retainCount", ns.UInteger, .{});
    }
};

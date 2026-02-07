// Cocoa initialization for CEF on macOS.
// CEF requires NSApplication to be subclassed with CefAppProtocol before
// CefInitialize is called. This file provides BoltInitCocoa() which must
// be called from main() before any CEF initialization.

#import <Cocoa/Cocoa.h>
#include "include/cef_application_mac.h"

// NSApplication subclass that implements CEF's required CefAppProtocol.
@interface BoltApplication : NSApplication <CefAppProtocol> {
 @private
	BOOL handlingSendEvent_;
}
@end

@implementation BoltApplication
- (BOOL)isHandlingSendEvent {
	return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
	handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
	CefScopedSendingEvent sendingEventScoper;
	[super sendEvent:event];
}

// Override terminate: to allow CEF to handle shutdown gracefully.
// The default implementation calls exit() which bypasses CEF's cleanup.
- (void)terminate:(id)sender {
	// Post a quit notification that CEF can handle
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NSApplicationWillTerminateNotification
		object:self];
}

// Requests secure state restoration (macOS 12+).
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app {
	return YES;
}
@end

// C-linkage function callable from main.cxx
extern "C" void BoltInitCocoa() {
	@autoreleasepool {
		[BoltApplication sharedApplication];
	}
}

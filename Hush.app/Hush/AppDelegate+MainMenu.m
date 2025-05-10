#import <Cocoa/Cocoa.h>

// This file exists to ensure the AppDelegate class is properly registered with
// NSBundle before the MainMenu.xib is loaded.

@interface AppDelegateLoader : NSObject
@end

@implementation AppDelegateLoader
+ (void)load {
  // Force the Swift AppDelegate class to be fully loaded
  [[NSBundle mainBundle] classNamed:@"Hush.AppDelegate"];
}
@end
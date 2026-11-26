// Simulator-only link stubs for the retargeted Godot 4.7.2 device library (see retarget_ios_sim_lib.py).
// metal-cpp's static initializer references these two error-domain constants. The iPhoneOS SDK's
// Metal.tbd exports them, the iPhoneSimulator SDK's does not, so the simulator link fails without them.
// Never linked into a device build. Delete together with retarget_ios_sim_lib.py.
#import <Foundation/Foundation.h>

NSString *const MTLIOErrorDomain = @"MTLIOErrorDomain";
NSString *const MTLTensorDomain = @"MTLTensorDomain";

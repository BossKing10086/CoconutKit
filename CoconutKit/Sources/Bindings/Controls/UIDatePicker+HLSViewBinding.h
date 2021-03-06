//
//  Copyright (c) Samuel Défago. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIView+HLSViewBindingImplementation.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * Binding support for UIDatePicker:
 *   - binds to NSDate model values
 *   - displays and updates the underlying model value
 *   - can animate updates
 *   - check (if not disabled via bindInputChecked) and update the value each time it is changed
 */
@interface UIDatePicker (HLSViewBinding)

@end

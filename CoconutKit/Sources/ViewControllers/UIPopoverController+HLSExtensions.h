//
//  Copyright (c) Samuel Défago. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (UIPopoverController_HLSExtensions)

/**
 * Return the popover controller which displays the receiver, or nil if none
 */
@property (nonatomic, readonly, weak, nullable) UIPopoverController *popoverController;

@end

NS_ASSUME_NONNULL_END

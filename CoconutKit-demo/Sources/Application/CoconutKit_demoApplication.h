//
//  Copyright (c) Samuel Défago. All rights reserved.
//
//  License information is available from the LICENSE file.
//

NS_ASSUME_NONNULL_BEGIN

@interface CoconutKit_demoApplication : NSObject <
    HLSStackControllerDelegate,
    UIActionSheetDelegate,
    UINavigationControllerDelegate,
    UISplitViewControllerDelegate,
    UITabBarControllerDelegate
>

@property (nonatomic, readonly) UIViewController *rootViewController;

- (void)savePendingChanges;

@end

NS_ASSUME_NONNULL_END

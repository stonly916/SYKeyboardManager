//
//  SYKeyboardManager.h
//  QianQianDog
//
//  Created by whg on 17/4/19.
//  Copyright © 2017年 LongPei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SYKeyboardManager : NSObject

@property(nonatomic, assign, getter = isEnabled) BOOL enable;

+ (SYKeyboardManager*)sharedManager;

@end

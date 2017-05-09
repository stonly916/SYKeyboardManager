//
//  SYKeyboardManager.m
//  QianQianDog
//
//  Created by whg on 17/4/19.
//  Copyright © 2017年 LongPei. All rights reserved.
//

#import "SYKeyboardManager.h"

@interface UIView(SYKeyboard)
- (UIScrollView*)superScrollView;
@end

@implementation UIView(SYKeyboard)
- (UIScrollView*)superScrollView
{
    UIView *superview = self.superview;
    
    while (superview) {
        if ([superview isKindOfClass:[UIScrollView class]] && ![superview isKindOfClass:NSClassFromString(@"UITableViewWrapperView")]) {
            return (UIScrollView*)superview;
        } else
            superview = superview.superview;
    }
    return nil;
}
@end

@interface SYKeyboardManager()<UIGestureRecognizerDelegate>

@property(nonatomic, strong) UIWindow *keyWindow;

- (void)adjustFrame;

- (void)keyboardWillShow:(NSNotification*)aNotification;
- (void)keyboardWillHide:(NSNotification*)aNotification;
- (void)textFieldViewDidBeginEditing:(NSNotification*)notification;
- (void)textFieldViewDidEndEditing:(NSNotification*)notification;
- (void)textFieldViewDidChange:(NSNotification*)notification;

- (void)tapRecognized:(UITapGestureRecognizer*)gesture;

@end

@implementation SYKeyboardManager
{
    @package
    /*! Boolean to maintain keyboard is showing or it is hide. To solve rootViewController.view.frame calculations. */
    BOOL isKeyboardShowing;

    /*! To save keyboard animation duration. */
    CGFloat animationDuration;
    
    /*! To mimic the keyboard animation */
    NSInteger animationCurve;
    
    UIView *_textFieldView;
    
    /*! To save keyboard size */
    CGSize kbSize;
    
    /*! To save keyboardWillShowNotification. Needed for enable keyboard functionality. */
    NSNotification *kbShowNotification;
    
    /*! Variable to save lastScrollView that was scrolled. */
    UIScrollView *lastScrollView;
    
    UIScrollView *lastSuperScrollView;
    
    /*! LastScrollView's initial contentOffset. */
    CGPoint startingContentOffset;
    
    UIEdgeInsets lastContentInset;
    
    /*! TapGesture to resign keyboard on view's touch*/
    UITapGestureRecognizer *tapGesture;
}

@synthesize enable                          = _enable;

#pragma mark - Initializing functions

//+(void)load
//{
//    [super load];
//    [[SYKeyboardManager sharedManager] setEnable:YES];
//}

-(id)init
{
    if (self = [super init])
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            //  Registering for keyboard notification.
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
            
            //  Registering for textField notification.
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldViewDidBeginEditing:) name:UITextFieldTextDidBeginEditingNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldViewDidEndEditing:) name:UITextFieldTextDidEndEditingNotification object:nil];
            
            //  Registering for textView notification.
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldViewDidBeginEditing:) name:UITextViewTextDidBeginEditingNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldViewDidEndEditing:) name:UITextViewTextDidEndEditingNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldViewDidChange:) name:UITextViewTextDidChangeNotification object:nil];
            
            tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
            [tapGesture setDelegate:self];
            
            animationDuration = 0.25;
            
            _enable = NO;
            
            _keyWindow = [self keyWindow];
        });
    }
    return self;
}

+ (SYKeyboardManager*)sharedManager
{
    static SYKeyboardManager *SYManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SYManager = [[self alloc] init];
    });
    
    return SYManager;
}

#pragma mark - Dealloc
-(void)dealloc
{
    //  Disable the keyboard manager.
    [self setEnable:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Property functions
-(void)setEnable:(BOOL)enable
{
    if (enable == YES && _enable == NO) {
        _enable = enable;

        if (kbShowNotification)	[self keyboardWillShow:kbShowNotification];
        
        NSLog(@"Keyboard Manager enabled");
    } else if (enable == NO && _enable == YES) {
        [self keyboardWillHide:nil];
        
        _enable = enable;
        
        NSLog(@"Keyboard Manager disabled");
    } else if (enable == NO && _enable == NO) {
        NSLog(@"Keyboard Manger already disabled");
    } else if (enable == YES && _enable == YES) {
        NSLog(@"Keyboard Manager already enabled");
    }
}

//Is enabled
-(BOOL)isEnabled
{
    return _enable;
}

-(UIWindow *)keyWindow
{
    if (_keyWindow == nil)      _keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    return _keyWindow;
}

#pragma mark - UITextFieldView Delegate methods
//  Removing fetched object.
-(void)textFieldViewDidEndEditing:(NSNotification*)notification
{
    [_textFieldView.window removeGestureRecognizer:tapGesture];
    
    _textFieldView = nil;
}

//  Fetching UITextFieldView object from notification.
-(void)textFieldViewDidBeginEditing:(NSNotification*)notification
{
    //  Getting object
    _textFieldView = notification.object;
    
    if (_enable == NO)	return;
    
    [_textFieldView.window addGestureRecognizer:tapGesture];
    
    //  keyboard is already showing. adjust frame.
    [self adjustFrame];
}

-(void)textFieldViewDidChange:(NSNotification*)notification
{
    UITextView *textView = (UITextView *)notification.object;
    
    CGRect line = [textView caretRectForPosition: textView.selectedTextRange.start];
    CGFloat overflow = CGRectGetMaxY(line) - (textView.contentOffset.y + CGRectGetHeight(textView.bounds) - textView.contentInset.bottom - textView.contentInset.top);
    
    if ( overflow > 0 )
    {
        // We are at the bottom of the visible text and introduced a line feed, scroll down (iOS 7 does not do it)
        // Scroll caret to visible area
        CGPoint offset = textView.contentOffset;
        offset.y += overflow + 7; // leave 7 pixels margin
        
        // Cannot animate with setContentOffset:animated: or caret will not appear
        [UIView animateWithDuration:animationDuration delay:0 options:(animationCurve|UIViewAnimationOptionBeginFromCurrentState) animations:^{
            [textView setContentOffset:offset];
        } completion:^(BOOL finished) {
            
        }];
    }
}

#pragma mark - UIKeyboad Notification methods
//  UIKeyboard Will show
-(void)keyboardWillShow:(NSNotification*)aNotification
{
    kbShowNotification = aNotification;
    
    if (_enable == NO)	return;
    
    //  Getting keyboard animation duration
    CGFloat duration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    //Saving animation duration
    if (duration != 0.0)    animationDuration = duration;
    
    CGSize oldKBSize = kbSize;
    
    //  Getting UIKeyboardSize.
    kbSize = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    
    if (!CGSizeEqualToSize(kbSize, oldKBSize))
    {
        [self adjustFrame];
    }
}

//  Keyboard Will hide. So setting rootViewController to it's default frame.
- (void)keyboardWillHide:(NSNotification*)aNotification
{
    if (aNotification != nil)	kbShowNotification = nil;
    kbSize = CGSizeZero;
    
    if (_enable == NO)	return;
    
    //  We are unable to get textField object while keyboard showing on UIWebView's textField.
    if (_textFieldView == nil){
        lastSuperScrollView.contentInset = lastContentInset;
        lastSuperScrollView = nil;;
        lastScrollView = nil;
        
        startingContentOffset = CGPointZero;
        lastContentInset = UIEdgeInsetsZero;
        return;
    }
    
    
    //  Boolean to know keyboard is showing/hiding
    isKeyboardShowing = NO;
    
    //  Getting keyboard animation duration
    CGFloat aDuration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    if (aDuration!= 0.0f)
    {
        //  Setitng keyboard animation duration
        animationDuration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    }
    
    
    [UIView animateWithDuration:animationDuration delay:0 options:(animationCurve|UIViewAnimationOptionBeginFromCurrentState) animations:^{
        lastScrollView.contentOffset = startingContentOffset;
    } completion:^(BOOL finished) {
    }];
    
    lastSuperScrollView.contentInset = lastContentInset;
    lastSuperScrollView = nil;;
    lastScrollView = nil;
    
    startingContentOffset = CGPointZero;
    lastContentInset = UIEdgeInsetsZero;
}


-(void)adjustFrame
{
    //  We are unable to get textField object while keyboard showing on UIWebView's textField.(当返回上一个页面有编辑状态文本框时，keyboardWillShow先调用，且取不到_textFieldView)
    if (_textFieldView == nil){
        return;
    }
    
    //  Boolean to know keyboard is showing/hiding
    isKeyboardShowing = YES;
    
    //  Getting KeyWindow object.
    UIWindow *window = [self keyWindow];

    
    //  Converting Rectangle according to window bounds.
    CGRect textFieldViewRect = [[_textFieldView superview] convertRect:_textFieldView.frame toView:window];
    
    CGFloat shouldMove = CGRectGetMaxY(textFieldViewRect)-(CGRectGetHeight(window.frame)-kbSize.height);

    
    //  Getting it's superScrollView.
    UIScrollView *superScrollView = [_textFieldView superScrollView];
    
    if (lastSuperScrollView) {
        lastSuperScrollView.contentInset = lastContentInset;
        lastSuperScrollView = nil;
    }
    
    //之前已有textFieldView处于 正开始编辑、或者编辑中，且在scrollView上
    if (lastScrollView) //还原之前textFieldView所做的自适应
    {
        //当前textFieldView不在scrollView中
        if (superScrollView == nil) {
            [lastScrollView setContentOffset:startingContentOffset animated:YES];
            
            lastScrollView = nil;
            startingContentOffset = CGPointZero;
            lastContentInset = UIEdgeInsetsZero;
        }
        //之前textFieldView与当前textFieldView不同,当前textFieldView在scrollView上
        if (superScrollView != lastScrollView) {
            [lastScrollView setContentOffset:startingContentOffset animated:YES];
            
            lastScrollView = superScrollView;
            startingContentOffset = superScrollView.contentOffset;
            lastContentInset = superScrollView.contentInset;
        }
    } else if(superScrollView) {
        lastScrollView = superScrollView;
        startingContentOffset = superScrollView.contentOffset;
    }
    //当前lastScrollView = 当前处于编辑状态下的textFieldView
    
    
    {
        //  If we found lastScrollView then setting it's contentOffset to show textField.
        if (lastScrollView) {
                UIScrollView *superScrollView = lastScrollView;
                while (superScrollView && shouldMove > 0) {
                    UIEdgeInsets inset = superScrollView.contentInset;
                    if(shouldMove > 0) {
                        CGFloat maxOffset = superScrollView.contentSize.height + inset.bottom - superScrollView.frame.size.height;
                        CGFloat canOffset = MAX(0, maxOffset - superScrollView.contentOffset.y);
                        
                        CGFloat offset = MIN(shouldMove, canOffset);
                        shouldMove -= offset;
                        
                        UIScrollView *lastView = [superScrollView superScrollView];
                        if (shouldMove > 0) {
                            
                            if (lastView == nil) {
                                //需要设置superScrollView的contentInset
                                CGRect superScrollViewRect = [superScrollView.superview convertRect:superScrollView.frame toView:window];
                                //superScrollView底部应该设置的contentInset.bottom
                                CGFloat shouldBottom = CGRectGetMaxY(superScrollViewRect)-(CGRectGetHeight(window.frame)-kbSize.height);
                                if (shouldBottom > 0) {
                                    
                                    UIEdgeInsets inset = superScrollView.contentInset;
                                    lastContentInset = inset;
                                    //重新设置superScrollView的contentInset
                                    superScrollView.contentInset = UIEdgeInsetsMake(inset.top, inset.left, inset.bottom + shouldBottom, inset.right);
                                    
                                    lastSuperScrollView = superScrollView;
                                }
                                
                                CGFloat shouldOffset = shouldMove;
                                //在设置contentInset后，需要重新更新offset
                                offset += shouldOffset;
                                shouldMove -= shouldOffset;
                            }
                        }
                        
                        [UIView animateWithDuration:animationDuration delay:0 options:(animationCurve|UIViewAnimationOptionBeginFromCurrentState) animations:^{
                            superScrollView.contentOffset = CGPointMake(superScrollView.contentOffset.x, superScrollView.contentOffset.y + offset);
                        } completion:^(BOOL finished) {
                        }];
                        
                        superScrollView = lastView;
                    }
                }
            
        }
    }
}


#pragma mark AutoResign methods

- (void)tapRecognized:(UITapGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [gesture.view endEditing:YES];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}

@end

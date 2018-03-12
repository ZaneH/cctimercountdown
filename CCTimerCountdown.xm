//
//  CCTimerCountdown.x
//  CCTimerCountdown
//
//  Created by Zane Helton on 08.11.2015.
//  Copyright (c) 2015 Zane Helton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>

@interface TimerManager
+ (instancetype)sharedManager;
@end

@interface UIConcreteLocalNotification
- (NSDate *)fireDate;
@end

@interface SBCCShortcutButtonController
- (void)setHidden:(_Bool)arg1;
- (UIView *)view;
@end

@interface SBCCButtonSectionController
- (NSString *)prettyPrintTime:(int)seconds;
- (void)updateLabel:(NSTimer *)timer;
@end

@interface CCUIContentModuleContainerView
- (void)setAlpha:(CGFloat)alpha;
- (CGRect)frame;
- (void)addSubview:(id)arg1;
- (id)containerView; // this is the clock icon, used to lower the alpha

- (void)viewWillAppear:(BOOL)arg1;
- (void)viewWillDisappear:(BOOL)arg1;
@end

@interface CCUIModuleCollectionViewController
// %new
- (NSString *)prettyPrintTime:(int)seconds;
// %new
- (void)updateLabel:(NSTimer *)timer;
@end

UILabel *timeRemainingLabel;
NSDate *pendingDate;
NSTimer *pendingTimer;
SBCCShortcutButtonController *timerButton;
CCUIContentModuleContainerView *timerModuleContainerView;

/*
	Heavily documented for educational purposes
 */
%group iOS11
	%hook CCUIModuleCollectionViewController
	- (void)viewWillAppear:(BOOL)arg1 {
		%orig;

		NSDictionary *moduleDictionary = MSHookIvar<NSDictionary *>(self, "_moduleContainerViewByIdentifier");
		timerModuleContainerView = [moduleDictionary objectForKey:@"com.apple.mobiletimer.controlcenter.timer"];

		TimerManager *timeManager = [%c(TimerManager) sharedManager];
		UIConcreteLocalNotification *notification = MSHookIvar<UIConcreteLocalNotification *>(timeManager, "_notification");
		pendingDate = [notification fireDate];

		int timeDelta = [pendingDate timeIntervalSinceDate:[NSDate date]];
		if (timeDelta > 0) {
			[[timerModuleContainerView containerView] setAlpha:0.25f];
			if (timeRemainingLabel) {
				[timeRemainingLabel removeFromSuperview];
				timeRemainingLabel = nil;
			}

			timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [timerModuleContainerView frame].size.width, [timerModuleContainerView frame].size.height)];
			[timeRemainingLabel setText:[self prettyPrintTime:timeDelta]];
			[timeRemainingLabel setFont:[UIFont systemFontOfSize:12]];
			[timeRemainingLabel setTextColor:[UIColor whiteColor]];
			[timeRemainingLabel setTextAlignment:NSTextAlignmentCenter];
			[timerModuleContainerView addSubview:timeRemainingLabel];

			pendingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(updateLabel:) userInfo:nil repeats:YES];
		}
	}

	%new
	- (void)updateLabel:(NSTimer *)timer {
		if ([pendingDate timeIntervalSinceDate:[NSDate date]] <= 0) {
			[timeRemainingLabel removeFromSuperview];
			[[timerModuleContainerView containerView] setAlpha:1.0f];
			return;
		}

		[timeRemainingLabel setText:[self prettyPrintTime:[pendingDate timeIntervalSinceDate:[NSDate date]]]];
	}

	// giving credit where due
	// http://stackoverflow.com/a/7059284/3411191
	%new
	- (NSString *)prettyPrintTime:(int)seconds {
		int hours = floor(seconds /  (60 * 60));
		float minute_divisor = seconds % (60 * 60);
		int minutes = floor(minute_divisor / 60);
		float seconds_divisor = seconds % 60;
		seconds = ceil(seconds_divisor);
		if (hours > 0) {
			return [NSString stringWithFormat:@"%0.2d:%0.2d:%0.2d", hours, minutes, seconds];
		} else {
			return [NSString stringWithFormat:@"%0.2d:%0.2d", minutes, seconds];
		}
	}

	- (void)viewDidDisappear:(BOOL)arg1 {
		[pendingTimer invalidate];
		pendingTimer = nil;
		[timeRemainingLabel removeFromSuperview];
		timeRemainingLabel = nil;
		[[timerModuleContainerView containerView] setAlpha:1.0f];

		%orig;
	}
	%end
%end

%group iOS10
	%hook SBCCButtonSectionController
	%new
	- (void)updateLabel:(NSTimer *)timer {
		// if the cc was open when the timer went off, some goofy stuff happens; this fixes it
		if ([pendingDate timeIntervalSinceDate:[NSDate date]] <= 0) {
			[timeRemainingLabel removeFromSuperview];
			[[[[timerButton view] subviews] lastObject] setHidden:NO];
			return;
		}
		[timeRemainingLabel setText:[self prettyPrintTime:[pendingDate timeIntervalSinceDate:[NSDate date]]]];
	}

	- (void)viewWillAppear:(_Bool)arg1 {
		[pendingTimer invalidate];
		[timeRemainingLabel removeFromSuperview];
		timeRemainingLabel = nil;
		// grab the time manager (model (where all the information resides))
		TimerManager *timeManager = [%c(TimerManager) sharedManager];
		// get the notification from the time manager
		UIConcreteLocalNotification *notification = MSHookIvar<UIConcreteLocalNotification *>(timeManager, "_notification");
		if (!notification) {
			[[[[timerButton view] subviews] lastObject] setHidden:NO];
			return %orig;
		}
		// calculate the time between when the timer goes off and now (in seconds)
		pendingDate = [notification fireDate];
		NSTimeInterval secondsBetweenNowAndFireDate = [pendingDate timeIntervalSinceDate:[NSDate date]];
		// create our label as long as there is a timer running
		if (secondsBetweenNowAndFireDate > 0) {
			if (timeRemainingLabel) {
				[timeRemainingLabel removeFromSuperview];
				timeRemainingLabel = nil;
			}

			// grab the timer cc shortcut from a SBCCButtonSectionController ivar
			NSDictionary *ccShortcuts = MSHookIvar<NSDictionary *>(self, "_moduleControllersByID");
			// grab the timer cc button from the ivar's mutable array
			timerButton = [ccShortcuts objectForKey:@"com.apple.mobiletimer"];
			// hide the image view so we can see the label better
			[[[[timerButton view] subviews] lastObject] setHidden:YES];
			// create a label to display the time
			timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [[timerButton view] frame].size.width, [[timerButton view] frame].size.height)];
			[timeRemainingLabel setText:[self prettyPrintTime:secondsBetweenNowAndFireDate]];
			[timeRemainingLabel setFont:[UIFont systemFontOfSize:12]];
			[timeRemainingLabel setTextAlignment:NSTextAlignmentCenter];
			[[timerButton view] addSubview:timeRemainingLabel];

			// create a timer to keep our label up-to-date
			pendingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(updateLabel:) userInfo:nil repeats:YES];
		}
		return %orig;
	}

	- (void)viewDidDisappear:(BOOL)animated {
		[pendingTimer invalidate];
		pendingTimer = nil;
		[timeRemainingLabel removeFromSuperview];
		timeRemainingLabel = nil;

		%orig;
	}

	%new
	// giving credit where due
	// http://stackoverflow.com/a/7059284/3411191
	- (NSString *)prettyPrintTime:(int)seconds {
		int hours = floor(seconds /  (60 * 60));
		float minute_divisor = seconds % (60 * 60);
		int minutes = floor(minute_divisor / 60);
		float seconds_divisor = seconds % 60;
		seconds = ceil(seconds_divisor);
		if (hours > 0) {
			return [NSString stringWithFormat:@"%0.2d:%0.2d:%0.2d", hours, minutes, seconds];
		} else {
			return [NSString stringWithFormat:@"%0.2d:%0.2d", minutes, seconds];
		}
	}
	%end
%end

// iOS 10 and iOS 11 have different control centers
%ctor {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0 && [[[UIDevice currentDevice] systemVersion] floatValue] < 11.0) {
        %init(iOS10);
    } else if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0 && [[[UIDevice currentDevice] systemVersion] floatValue] < 12.0) {
        %init(iOS11);
    }
}
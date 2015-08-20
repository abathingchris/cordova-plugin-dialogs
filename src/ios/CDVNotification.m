/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVNotification.h"

#define DIALOG_TYPE_ALERT @"alert"
#define DIALOG_TYPE_PROMPT @"prompt"

static void soundCompletionCallback(SystemSoundID ssid, void* data);

@implementation CDVNotification

- (void)pluginInitialize
{
    NSNotificationCenter* notificationCenter = [NSNotificationCenter
                                                defaultCenter];
    
    [notificationCenter addObserver: self
                           selector: @selector(didReceiveLocalNotification:)
                               name: @"BeaconNotification"
                             object: nil];
    
    
    NSLog(@"Plugin is initialized!");
}

// Handles local notification event.
- (void) didReceiveLocalNotification:(NSNotification*)localNotification
{
    NSLog(@"Received local notification! %@\n\n", localNotification.name);
    UILocalNotification* notification = [localNotification object];
    NSDictionary *userOptions2 = [notification userInfo];
    
    NSString *rValue = [userOptions2 objectForKey: @"RETURN"];
    
    CDVPluginResult* result;
    
    
    NSString *callbackId = [userOptions2 objectForKey:@"callbackId"];
    
    
    
    if ([rValue isEqualToString:@"YES"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:1];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:2];
    }
    
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    
    //Cancel notification and clear badge count.
    UIApplication *app = [UIApplication sharedApplication];
    @synchronized(app) {
        NSInteger currentBadge = [app applicationIconBadgeNumber];
        
        [app setApplicationIconBadgeNumber: (currentBadge - 1)];
    }
//    [app cancelLocalNotification: localNotification];
}

/*
 * showDialogWithMessage - Common method to instantiate the alert view for alert, confirm, and prompt notifications.
 * Parameters:
 *  message       The alert view message.
 *  title         The alert view title.
 *  buttons       The array of customized strings for the buttons.
 *  defaultText   The input text for the textbox (if textbox exists).
 *  callbackId    The commmand callback id.
 *  dialogType    The type of alert view [alert | prompt].
 */
- (void)showDialogWithMessage:(NSString*)message title:(NSString*)title buttons:(NSArray*)buttons defaultText:(NSString*)defaultText callbackId:(NSString*)callbackId dialogType:(NSString*)dialogType
{

    NSUInteger count = [buttons count];
#ifdef __IPHONE_8_0
    if (NSClassFromString(@"UIAlertController")) {
        
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        
        if (state == UIApplicationStateBackground) {

            UIMutableUserNotificationAction *acceptAction = [[UIMutableUserNotificationAction alloc] init];
            UIMutableUserNotificationAction *declineAction = [[UIMutableUserNotificationAction alloc] init];
            
            acceptAction.identifier = @"ACCEPT_IDENTIFIER";
            acceptAction.title = [buttons objectAtIndex:0];
            
            
            
            
            // Given seconds, not minutes, to run in the background
            acceptAction.activationMode = UIUserNotificationActivationModeBackground;
            
            
            // If YES the action is red
            acceptAction.destructive = NO;
            
            
            
            // If YES requires passcode, but does not unlock the device
            acceptAction.authenticationRequired = NO;
            
            
            NSArray *actions = nil;
            if (buttons.count > 1) {
                declineAction.identifier = @"DECLINE_IDENTIFIER";
                declineAction.title = [buttons objectAtIndex:1];
                declineAction.activationMode = UIUserNotificationActivationModeBackground;
                declineAction.destructive = YES;
                declineAction.authenticationRequired = NO;
                actions = @[acceptAction, declineAction];
            } else {
                actions = @[acceptAction];
            }
            
            
            UIMutableUserNotificationCategory *inviteCategory = [[UIMutableUserNotificationCategory alloc] init];
            inviteCategory.identifier = @"INVITE_CATEGORY";
            
            // You can define up to 4 actions in the 'default' context
            // On the lock screen, only the first two will be shown
            // If you want to specify which two actions get used on the lockscreen, use UIUserNotificationActionContextMinimal
            [inviteCategory setActions:actions forContext:UIUserNotificationActionContextDefault];
            
            // These would get set on the lock screen specifically
            [inviteCategory setActions:actions forContext:UIUserNotificationActionContextMinimal];
            
            UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
            
            NSSet *categories = [NSSet setWithObjects:inviteCategory, nil];
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:categories];
            
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            notification.alertBody = message;
            notification.alertTitle = title;
            notification.userInfo = @{@"callbackId": callbackId};
            notification.category = @"INVITE_CATEGORY";
            
            // The notification will arrive in 5 seconds, leave the app or lock your device to see
            // it since we aren't doing anything to handle notifications that arrive while the app is open
            notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:0];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
        } else {
        
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            
            if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.3) {
                
                CGRect alertFrame = [UIScreen mainScreen].applicationFrame;
                
                if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
                    // swap the values for the app frame since it is now in landscape
                    CGFloat temp = alertFrame.size.width;
                    alertFrame.size.width = alertFrame.size.height;
                    alertFrame.size.height = temp;
                }
                
                alertController.view.frame =  alertFrame;
            }
            
            for (int n = 0; n < count; n++) {
                
                UIAlertAction* action = [UIAlertAction actionWithTitle:[buttons objectAtIndex:n] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
                                         {
                                             CDVPluginResult* result;
                                             
                                             if ([dialogType isEqualToString:DIALOG_TYPE_PROMPT]) {
                                                 
                                                 NSString* value0 = [[alertController.textFields objectAtIndex:0] text];
                                                 NSDictionary* info = @{
                                                                        @"buttonIndex":@(n + 1),
                                                                        @"input1":(value0 ? value0 : [NSNull null])
                                                                        };
                                                 result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:info];
                                                 
                                             } else {
                                                 
                                                 result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:(int)(n  + 1)];
                                                 
                                             }
                                             
                                             [self.commandDelegate sendPluginResult:result callbackId:callbackId];
                                             
                                         }];
                [alertController addAction:action];
                
            }
            
            if ([dialogType isEqualToString:DIALOG_TYPE_PROMPT]) {
                
                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = defaultText;
                }];
            }
            
            
            
            [self.viewController presentViewController:alertController animated:YES completion:nil];
        }
    
    } else {
#endif
        CDVAlertView* alertView = [[CDVAlertView alloc]
                                   initWithTitle:title
                                   message:message
                                   delegate:self
                                   cancelButtonTitle:nil
                                   otherButtonTitles:nil];
        
        alertView.callbackId = callbackId;
        
        
        
        for (int n = 0; n < count; n++) {
            [alertView addButtonWithTitle:[buttons objectAtIndex:n]];
        }
        
        if ([dialogType isEqualToString:DIALOG_TYPE_PROMPT]) {
            alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField* textField = [alertView textFieldAtIndex:0];
            textField.text = defaultText;
        }
        
        [alertView show];
#ifdef __IPHONE_8_0
    }
#endif
    
}

- (void)alert:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSString* message = [command argumentAtIndex:0];
    NSString* title = [command argumentAtIndex:1];
    NSString* buttons = [command argumentAtIndex:2];

    [self showDialogWithMessage:message title:title buttons:@[buttons] defaultText:nil callbackId:callbackId dialogType:DIALOG_TYPE_ALERT];
}

- (void)confirm:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSString* message = [command argumentAtIndex:0];
    NSString* title = [command argumentAtIndex:1];
    NSArray* buttons = [command argumentAtIndex:2];

    [self showDialogWithMessage:message title:title buttons:buttons defaultText:nil callbackId:callbackId dialogType:DIALOG_TYPE_ALERT];
}

- (void)prompt:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSString* message = [command argumentAtIndex:0];
    NSString* title = [command argumentAtIndex:1];
    NSArray* buttons = [command argumentAtIndex:2];
    NSString* defaultText = [command argumentAtIndex:3];

    [self showDialogWithMessage:message title:title buttons:buttons defaultText:defaultText callbackId:callbackId dialogType:DIALOG_TYPE_PROMPT];
}

/**
  * Callback invoked when an alert dialog's buttons are clicked.
  */
- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    CDVAlertView* cdvAlertView = (CDVAlertView*)alertView;
    CDVPluginResult* result;

    // Determine what gets returned to JS based on the alert view type.
    if (alertView.alertViewStyle == UIAlertViewStyleDefault) {
        // For alert and confirm, return button index as int back to JS.
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:(int)(buttonIndex + 1)];
    } else {
        // For prompt, return button index and input text back to JS.
        NSString* value0 = [[alertView textFieldAtIndex:0] text];
        NSDictionary* info = @{
            @"buttonIndex":@(buttonIndex + 1),
            @"input1":(value0 ? value0 : [NSNull null])
        };
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:info];
    }
    [self.commandDelegate sendPluginResult:result callbackId:cdvAlertView.callbackId];
}

static void playBeep(int count) {
    SystemSoundID completeSound;
    NSInteger cbDataCount = count;
    NSURL* audioPath = [[NSBundle mainBundle] URLForResource:@"CDVNotification.bundle/beep" withExtension:@"wav"];
    #if __has_feature(objc_arc)
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)audioPath, &completeSound);
    #else
        AudioServicesCreateSystemSoundID((CFURLRef)audioPath, &completeSound);
    #endif
    AudioServicesAddSystemSoundCompletion(completeSound, NULL, NULL, soundCompletionCallback, (void*)(cbDataCount-1));
    AudioServicesPlaySystemSound(completeSound);
}

static void soundCompletionCallback(SystemSoundID  ssid, void* data) {
    int count = (int)data;
    AudioServicesRemoveSystemSoundCompletion (ssid);
    AudioServicesDisposeSystemSoundID(ssid);
    if (count > 0) {
        playBeep(count);
    }
}

- (void)beep:(CDVInvokedUrlCommand*)command
{
    NSNumber* count = [command argumentAtIndex:0 withDefault:[NSNumber numberWithInt:1]];
    playBeep([count intValue]);
}


@end

@implementation CDVAlertView

@synthesize callbackId;

@end

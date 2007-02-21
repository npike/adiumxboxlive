//
//  AWXBoxLiveService.m
//  Adium
//
//  Created by Adam Iser on 8/26/04.
//  Copyright (c) 2004-2006 The Adium Team. All rights reserved.
//

#import <Adium/AIStatusControllerProtocol.h>
#import "AWXBoxLiveAccount.h"
#import "AWXBoxLiveService.h"
#import "ESXBoxLiveAccountViewController.h"
#import <Adium/DCJoinChatViewController.h>

@implementation AWXBoxLiveService

//Account Creation
- (Class)accountClass{
	return [AWXBoxLiveAccount class];
}

- (AIAccountViewController *)accountViewController{
    return [ESXBoxLiveAccountViewController accountViewController];
}

- (DCJoinChatViewController *)joinChatView{
	return [DCJoinChatViewController joinChatView];
}

//Service Description
- (NSString *)serviceCodeUniqueID{
	return @"XBoxLive-libezv";
}
- (NSString *)serviceID{
	return @"XBoxLive";
}
- (NSString *)serviceClass{
	return @"XBoxLive";
}
- (NSString *)shortDescription{
	return @"XBoxLive";
}
- (NSString *)longDescription{
	return @"XBoxLive";
}
- (NSCharacterSet *)allowedCharacters{
	return [[NSCharacterSet illegalCharacterSet] invertedSet];
}
- (NSCharacterSet *)ignoredCharacters{
	return [NSCharacterSet characterSetWithCharactersInString:@""];
}
- (int)allowedLength{
	return 999;
}
- (BOOL)caseSensitive{
	return YES;
}
- (AIServiceImportance)serviceImportance{
	return AIServiceSecondary;
}
- (BOOL)supportsProxySettings{
	return NO;
}
//No need for a password for XBoxLive accounts
- (BOOL)requiresPassword
{
	return NO;
}
- (void)registerStatuses{
	[[adium statusController] registerStatus:STATUS_NAME_AVAILABLE
							 withDescription:[[adium statusController] localizedDescriptionForCoreStatusName:STATUS_NAME_AVAILABLE]
									  ofType:AIAvailableStatusType
								  forService:self];
	
	[[adium statusController] registerStatus:STATUS_NAME_AWAY
							 withDescription:[[adium statusController] localizedDescriptionForCoreStatusName:STATUS_NAME_AWAY]
									  ofType:AIAwayStatusType
								  forService:self];
}
- (NSString *)defaultUserName { 
	return NSFullUserName(); 
}
@end

/*
 * Project:     Adium Bonjour Plugin
 * File:        AWBonjourAccount.m
 * Author:      Andrew Wellington <proton[at]wiretapped.net>
 *
 * License:
 * Copyright (C) 2004-2005 Andrew Wellington.
 * All rights reserved.
 * 
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AWBonjourAccount.h"
#import "AWEzv.h"
#import "AWEzvContact.h"
#import "AWEzvDefines.h"
#import "AWBonjourPlugin.h"
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentTyping.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIListContact.h>
#import <Adium/AIStatus.h>
#import <Adium/NDRunLoopMessenger.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AIObjectAdditions.h>

static	NSLock				*threadPreparednessLock = nil;
static	NDRunLoopMessenger	*bonjourThreadMessenger = nil;
static	AWEzv				*_libezvThreadProxy = nil;
static	NSAutoreleasePool	*currentAutoreleasePool = nil;

#define	AUTORELEASE_POOL_REFRESH	5.0

@interface AWBonjourAccount (PRIVATE)
- (NSString *)UIDForContact:(AWEzvContact *)contact;

- (void)setAccountIdleTo:(NSDate *)idle;
- (void)setAccountAwayTo:(NSAttributedString *)awayMessage;
- (void)setAccountUserImage:(NSImage *)image;
@end

@implementation AWBonjourAccount
//
- (void)initAccount
{
    [super initAccount];
	
    libezvContacts = [[NSMutableSet alloc] init];
    libezv = [[AWEzv alloc] initWithClient:self];	
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[libezvContacts release];
	[libezv release];

	[super dealloc];
}

- (BOOL)disconnectOnFastUserSwitch
{
	return YES;
}

//Bonjour should just ignore network reachability
- (BOOL)connectivityBasedOnNetworkReachability
{
	return NO;
}

- (AWEzv *)libezvThreadProxy
{
	if (!_libezvThreadProxy) {
		//Obtain the lock
		threadPreparednessLock = [[NSLock alloc] init];
		[threadPreparednessLock lock];
		
		//Detach the thread, which will unlock threadPreparednessLock when it is ready
		[NSThread detachNewThreadSelector:@selector(prepareBonjourThread)
								 toTarget:self
							   withObject:nil];
		
		//Obtain the lock - this will spinlock until the thread is ready
		[threadPreparednessLock lock];
		[threadPreparednessLock release]; threadPreparednessLock = nil;
	}

	return _libezvThreadProxy;
}
- (void)connect
{
    // Say we're connecting...
    [self setStatusObject:[NSNumber numberWithBool:YES] forKey:@"Connecting" notify:YES];

    [[self libezvThreadProxy] setName:[self displayName]];
	AILog(@"%@: Logging in using libezvThreadProxy %@",self, [self libezvThreadProxy]);
    [[self libezvThreadProxy] login];
}

- (void)disconnect
{
	//As per AIAccount's documentation, call super's implementation
	[super disconnect];

    // Say we're disconnecting...
    [self setStatusObject:[NSNumber numberWithBool:YES] forKey:@"Disconnecting" notify:YES];
    
    [[self libezvThreadProxy] logout];
}

- (void)removeContacts:(NSArray *)objects
{

}

#pragma mark Libezv Callbacks
/*!
 * @brief Logged in, called on the main thread
 */
- (void)mainThreadReportLoggedIn
{
	[self didConnect];
    
	//Silence updates
    [self silenceAllContactUpdatesForInterval:18.0];
	[[adium contactController] delayListObjectNotificationsUntilInactivity];
	
	//We need to set our user icon after connecting
    [self updateStatusForKey:KEY_USER_ICON];	
}

/*!
 * @brief libezv: we logged in
 *
 * Sent on the libezv thread
 */
- (void)reportLoggedIn
{
	AILog(@"%@: reportLoggedIn",self);
	[self mainPerformSelector:@selector(mainThreadReportLoggedIn)];
}

/*!
 * @brief libezv: we logged out
 *
 * Sent on the libezv thread
 */
- (void)reportLoggedOut 
{
	AILog(@"%@: reportLoggedOut",self);
	[libezvContacts removeAllObjects];
		
	[self mainPerformSelector:@selector(didDisconnect)];
}

- (void)mainThreadUserChangedState:(AWEzvContact *)contact
{
    AIListContact	*listContact;
	NSString		*contactName, *statusMessage;
	NSDate			*idleSinceDate;
	NSImage			*contactImage;
	
    listContact = [[adium contactController] contactWithService:service
														account:self
															UID:[self UIDForContact:contact]];  
	
	if ([contact status] == AWEzvUndefined) {
		[listContact setRemoteGroupName:nil];
		[listContact setOnline:NO notify:NotifyLater silently:silentAndDelayed];

	} else {
		if (![listContact remoteGroupName]) {
			[listContact setRemoteGroupName:@"Bonjour"];
		}
		
		//We only get state change updates on Online contacts
		[listContact setOnline:YES notify:NotifyLater silently:silentAndDelayed];
	}

	[listContact setStatusWithName:nil
					   statusType:(([contact status] == AWEzvAway) ? AIAwayStatusType : AIAvailableStatusType)
						   notify:NotifyLater];
	[listContact setStatusMessage:[[[NSAttributedString alloc] initWithString:[contact statusMessage]] autorelease]
						  notify:NotifyLater];
	
	idleSinceDate = [contact idleSinceDate];
	[listContact setIdle:(idleSinceDate != nil)
			   sinceDate:idleSinceDate
				  notify:NotifyLater];

	contactImage = [contact contactImage];
	if (contactImage != [listContact userIcon]) {
		[listContact setStatusObject:contactImage forKey:KEY_USER_ICON notify:NotifyLater];
	}
	
    //Use the contact alias as the serverside display name
	contactName = [contact name];
		
	if (![[listContact statusObjectForKey:@"Server Display Name"] isEqualToString:contactName]) {
		[listContact setServersideAlias:contactName
						asStatusMessage:NO
							   silently:silentAndDelayed];
	}

    //Apply any changes
    [listContact notifyOfChangedStatusSilently:silentAndDelayed];	
}

/*!
 * @brief libezv: A contact was updated 
 *
 * Sent on the libezv thread
 */
- (void)userChangedState:(AWEzvContact *)contact
{
	[self mainPerformSelector:@selector(mainThreadUserChangedState:)
				   withObject:contact];
	
	//Adding an existing object to a set has no effect, so just ensure it is added
	[libezvContacts addObject:contact];
}

- (void)mainThreadUserWithUIDLoggedOut:(NSString *)inUID
{
    AIListContact *listContact;
    
    listContact = [[adium contactController] existingContactWithService:service
																account:self 
																	UID:inUID];
    
    [listContact setRemoteGroupName:nil];	
}

- (void)userLoggedOut:(AWEzvContact *)contact
{
	[self mainPerformSelector:@selector(mainThreadUserWithUIDLoggedOut:)
				   withObject:[contact uniqueID]];

    [libezvContacts removeObject:contact];
}

- (void)mainThreadUserWithUID:(NSString *)inUID sentMessage:(NSString *)message withHtml:(NSString *)html
{
    AIListContact		*listContact;
    AIContentMessage	*msgObj;
    AIChat				*chat;
	NSAttributedString	*attributedMessage;

    listContact = [[adium contactController] existingContactWithService:service
																account:self
																	UID:inUID];
	chat = [[adium chatController] chatWithContact:listContact];
	
	attributedMessage = [[adium contentController] decodedIncomingMessage:html
															  fromContact:listContact
																onAccount:self];
	
    msgObj = [AIContentMessage messageInChat:chat
								  withSource:listContact
								 destination:self
										date:nil
									 message:attributedMessage
								   autoreply:NO];
    
    [[adium contentController] receiveContentObject:msgObj];
	
	//Clear the typing flag
	[chat setStatusObject:nil
				   forKey:KEY_TYPING
				   notify:YES];	
}

//We received a message from an AWEzvContact
- (void)user:(AWEzvContact *)contact sentMessage:(NSString *)message withHtml:(NSString *)html
{
	[self mainPerformSelector:@selector(mainThreadUserWithUID:sentMessage:withHtml:)
				   withObject:[contact uniqueID]
				   withObject:message
				   withObject:html];
}

- (void)mainThreadUserWithUID:(NSString *)inUID typingNotificationNumber:(NSNumber *)typingNumber
{
    AIListContact   *listContact;
    AIChat			*chat;
    listContact = [[adium contactController] existingContactWithService:service
																account:self
																	UID:inUID];
	chat = [[adium chatController] existingChatWithContact:listContact];
	
    [chat setStatusObject:typingNumber
				   forKey:KEY_TYPING
				   notify:YES];	
}

- (void)user:(AWEzvContact *)contact typingNotification:(AWEzvTyping)typingStatus
{
	[self mainPerformSelector:@selector(mainThreadUserWithUID:typingNotificationNumber:)
				   withObject:[contact uniqueID]
				   withObject:((typingStatus == AWEzvIsTyping) ? [NSNumber numberWithInt:AITyping] : nil)];
}

/*!
 * @brief A message could not be sent
 *
 * @param inContactUniqueID Unique ID of the contact to whom the message could not be sent
 */
- (void)mainThreadCouldNotSendToUserWithUID:(NSString *)inContactUniqueID
{
    AIListContact   *listContact;
    AIChat			*chat;

    listContact = [[adium contactController] existingContactWithService:service
																account:self
																	UID:inContactUniqueID];
	chat = [[adium chatController] existingChatWithContact:listContact];

	[chat setStatusObject:[NSNumber numberWithInt:AIChatMessageSendingUserNotAvailable]
				   forKey:KEY_CHAT_ERROR
				   notify:NotifyNow];
	[chat setStatusObject:nil
				   forKey:KEY_CHAT_ERROR
				   notify:NotifyNever];
}

- (void)user:(AWEzvContact *)contact typeAhead:(NSString *)message withHtml:(NSString *)html {
/* unimplemented in libezv at this stage */
}

- (void)user:(AWEzvContact *)contact sentFile:(NSString *)filename size:(size_t)size cookie:(int)cookie
{
/* sorry, no file transfer in libezv at the moment */
}

- (void)reportError:(NSString *)error ofLevel:(AWEzvErrorSeverity)severity
{
	NSLog(@"Bonjour Error (%i): %@", severity, error);
	AILog(@"Bonjour Error (%i): %@", severity, error);
}

- (void)reportError:(NSString *)error ofLevel:(AWEzvErrorSeverity)severity forUser:(NSString *)contactUniqueID
{
	if ([error isEqualToString:@"Could Not Send"]) {
		[self mainPerformSelector:@selector(mainThreadCouldNotSendToUserWithUID:)
					   withObject:contactUniqueID];
		
	} else {
		NSLog(@"Bonjour Error (%i): %@", severity, error);
		AILog(@"Bonjour Error (%i): %@", severity, error);
	}
}

#pragma mark AIAccount Messaging
// AIAccount_Messaging ---------------------------------------------------------------------------
// Send a content object
- (void)sendTypingObject:(AIContentTyping *)inContentTyping
{
	AIChat			*chat = [inContentTyping chat];
	AIListObject    *listObject = [chat listObject];
	NSString		*to = [listObject UID];
	
	[[self libezvThreadProxy] sendTypingNotification:(([inContentTyping typingState] == AITyping) ? AWEzvIsTyping : AWEzvNotTyping)
												  to:to];
}

- (BOOL)sendMessageObject:(AIContentMessage *)inContentMessage
{
	[[self libezvThreadProxy] sendMessage:[inContentMessage messageString] 
									   to:[[inContentMessage destination] UID]
								 withHtml:[inContentMessage encodedMessage]];
	
	return YES;
}

/*!
 * @brief Return the string encoded for sending to a remote contact
 *
 * We return nil if the string turns out to have been a / command.
 */
- (NSString *)encodedAttributedStringForSendingContentMessage:(AIContentMessage *)inContentMessage
{
	return [AIHTMLDecoder encodeHTML:[inContentMessage message]
							 headers:NO
							fontTags:YES
				  includingColorTags:YES
					   closeFontTags:YES
						   styleTags:YES
		  closeStyleTagsOnFontChange:YES
					  encodeNonASCII:YES
						encodeSpaces:NO
						  imagesPath:nil
				   attachmentsAsText:YES
		   onlyIncludeOutgoingImages:NO
					  simpleTagsOnly:NO
					  bodyBackground:NO];
}

//Initiate a new chat
- (BOOL)openChat:(AIChat *)chat
{
    return YES;
}

//Close a chat instance
- (BOOL)closeChat:(AIChat *)inChat
{
    return YES;
}

#pragma mark Account Status
//Respond to account status changes
- (void)updateStatusForKey:(NSString *)key
{
    [super updateStatusForKey:key];
    
    BOOL    areOnline = [[self statusObjectForKey:@"Online"] boolValue];
    
    //Now look at keys which only make sense while online
    if (areOnline) {
        if ([key isEqualToString:@"IdleSince"]) {
            NSDate	*idleSince = [self preferenceForKey:@"IdleSince" group:GROUP_ACCOUNT_STATUS];
			
			[[self libezvThreadProxy] setStatus:AWEzvIdle
									withMessage:[[self statusMessage] string]];
            [self setAccountIdleTo:idleSince];
			
        }else if ([key isEqualToString:KEY_USER_ICON]) {
			NSData  *data = [self userIconData];

			[self setAccountUserImage:(data ? [[[NSImage alloc] initWithData:data] autorelease] : nil)];
		}
    }
}

- (void)setStatusState:(AIStatus *)statusState usingStatusMessage:(NSAttributedString *)statusMessage
{
	if ([statusState statusType] == AIOfflineStatusType) {
		[self disconnect];

	} else {
		if ([self online]) {
			AIStatusType	statusType = [statusState statusType];
			switch(statusType) {
				case AIAvailableStatusType:
					[self setAccountAwayTo:nil];
					break;
				case AIAwayStatusType:
				case AIInvisibleStatusType:
					[self setAccountAwayTo:statusMessage];
					break;
				default:
					break;
			}
		} else {
			[self connect];
		}
	}
}

- (void)setAccountIdleTo:(NSDate *)idle
{
	[[self libezvThreadProxy] setIdleTime:idle];

	//We are now idle
	[self setStatusObject:idle forKey:@"IdleSince" notify:YES];
}

- (void)setAccountAwayTo:(NSAttributedString *)awayMessage
{
	if (!awayMessage || ![[awayMessage string] isEqualToString:[[self statusObjectForKey:@"StatusMessage"] string]]) {
		if (awayMessage != nil)
		    [[self libezvThreadProxy] setStatus:AWEzvAway withMessage:[awayMessage string]];
		else
		    [[self libezvThreadProxy] setStatus:AWEzvOnline withMessage:nil];
		
		//We are now away or not
		[self setStatusObject:[NSNumber numberWithBool:(awayMessage != nil)] forKey:@"Away" notify:YES];
		[self setStatusObject:awayMessage forKey:@"StatusMessage" notify:YES];
	}
}

/*!
 * @brief Set our user image
 *
 * Pass nil for no image.
 */
- (void)setAccountUserImage:(NSImage *)image
{
	[[self libezvThreadProxy] setContactImage:image];	

	//We now have an icon
	[self setStatusObject:image forKey:KEY_USER_ICON notify:YES];
}

//Status keys this account supports
- (NSSet *)supportedPropertyKeys
{
	static NSMutableSet *supportedPropertyKeys = nil;
	
	if (!supportedPropertyKeys) {
		supportedPropertyKeys = [[NSMutableSet alloc] initWithObjects:
			@"Online",
			@"Offline",
			@"IdleSince",
			@"IdleManuallySet",
			@"Away",
			@"AwayMessage",
			nil];

		[supportedPropertyKeys unionSet:[super supportedPropertyKeys]];
	}

	return supportedPropertyKeys;
}

- (NSString *)UIDForContact:(AWEzvContact *)contact
{
	/*
	NSString	*uniqueID = [contact uniqueID];
	NSArray		*components = [uniqueID componentsSeparatedByString:@"@"];
	NSString	*userName = [contact name];
	return [NSString stringWithFormat:@"%@ [%@]",name,[ substringFromIndex:[name length]]];
	 */
	return [contact uniqueID];
}

#pragma mark Bonjour Thread

- (void)clearBonjourThreadInfo
{
   [_libezvThreadProxy release]; _libezvThreadProxy = nil;
   [bonjourThreadMessenger release]; bonjourThreadMessenger = nil;
   [currentAutoreleasePool release]; currentAutoreleasePool = nil;
}

- (void)prepareBonjourThread
{
	NSTimer				*autoreleaseTimer;

	currentAutoreleasePool = [[NSAutoreleasePool alloc] init];

	bonjourThreadMessenger = [[NDRunLoopMessenger runLoopMessengerForCurrentRunLoop] retain];
	_libezvThreadProxy = [[bonjourThreadMessenger target:libezv] retain];
	
	//Use a timer to periodically release our autorelease pool so we don't continually grow in memory usage
	autoreleaseTimer = [[NSTimer scheduledTimerWithTimeInterval:AUTORELEASE_POOL_REFRESH
														 target:self
													   selector:@selector(refreshAutoreleasePool:)
													   userInfo:nil
														repeats:YES] retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(threadWillExit:) 
												 name:NSThreadWillExitNotification
											   object:[NSThread currentThread]];

	//We're good to go; release that lock
	[threadPreparednessLock unlock];
	CFRunLoopRun();

	[self clearBonjourThreadInfo];
	[autoreleaseTimer invalidate]; [autoreleaseTimer release];
}

/*!
 * @brief The bonjour thread is about to exit for some reason...
 *
 * I have no idea why the thread might exit, but it does.  Messaging the libezvThreadProxy after it exits throws an
 * NDRunLoopMessengerConnectionNoLongerExistsException exception.  If we clear out our data, perhaps we can recover fairly gracefully.
 *
 * It will be recreated when next needed.
 */
- (void)threadWillExit:(NSNotification *)inNotification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
												selector:@selector(threadWillExit:) 
												  object:[inNotification object]];
	
	[self clearBonjourThreadInfo];
}

/*!
 * @brief Release and recreate our autorelease pool
 *
 * Our autoreleased objects will only be released when the outermost autorelease pool is released.
 * This is handled automatically in the main thread, but we need to do it manually here.
 * Release the current pool, then create a new one.
 */
- (void)refreshAutoreleasePool:(NSTimer *)inTimer
{
	[currentAutoreleasePool release];
	currentAutoreleasePool = [[NSAutoreleasePool alloc] init];
}

@end

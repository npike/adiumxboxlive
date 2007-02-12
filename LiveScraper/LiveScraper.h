//
//  LiveScraper.h
//  MacLive
//
//  Created by James Howard on 12/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
@class SendMessage;

@protocol LiveScraperDelegate

- (void)loginIncorrect;
// if you get this message, the best thing
// for you to do as the delegate is to show the WebView
// and it will already be at the sign in page and the
// user will have to go through it themselves to get past
// the captcha and/or reset the password
- (void)accountLocked;
- (void)loadStart;
- (void)loadComplete;
- (void)loadFailed: (NSError*)error;

- (void)addFriendSucceededForGamertag: (NSString*)gamertag;

- (void)addFriendFailedForGamertag: (NSString*)gamertag
						 withError: (NSError*)error;

- (void)sendMessageSucceeded: (NSString*)message
				  recipients: (NSArray*)recipients;

@end

@interface LiveScraper : NSObject {

	NSMutableArray* friends;
	NSMutableArray* games;

	WebView* view;
	
	NSString* username;
	NSString* password;
	
	id<LiveScraperDelegate> delegate;
	
	NSMutableArray* operationQueue;
	
	NSMutableArray* friendRequestQueue;
	NSMutableArray* messageQueue;
	
	SendMessage* messageToSend;
	
}

- (void)setWebView: (WebView*)wv;

- (void)setDelegate: (id<LiveScraperDelegate>)del;

- (void)updateWithUsername: (NSString*)name
			   andPassword: (NSString*)pw;

// enqueue a friend request to be made at the next update cycle
- (void)queueFriendRequest: (NSString*)gamertag;

- (void)queueMessage: (NSString*)message
		   toFriends: (NSArray* /* of Friend */)recipients;


- (NSArray*)friends;
- (NSArray*)games;


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector;

@end

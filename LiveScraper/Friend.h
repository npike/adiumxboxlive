//
//  Friend.h
//  MacLive
//
//  Created by James Howard on 12/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XBNotable.h"


@interface Friend : XBNotable {

	NSString* gamertag;
	NSURL* icon;
	NSString* status;	
}

- (id)initWithGamertag: (NSString*)tag
			   iconURL: (NSString*)iconURL
			statusText: (NSString*)statusText;

- (NSString*)gamertag;
- (NSURL*)icon;
- (NSString*)status;

- (BOOL)online;
- (NSString*)currentGame;

@end

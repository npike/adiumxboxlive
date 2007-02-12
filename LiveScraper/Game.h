//
//  Game.h
//  MacLive
//
//  Created by James Howard on 12/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XBNotable.h"

@interface Game : XBNotable {

	NSString* name;
	NSURL* icon;
	
}

- (id)initWithName: (NSString*)name
		   iconURL: (NSString*)iconURL;

- (NSString*)name;
- (NSURL*)icon;

@end

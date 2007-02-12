//
//  Friend.m
//  MacLive
//
//  Created by James Howard on 12/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Friend.h"

@implementation Friend

- (id)initWithGamertag: (NSString*)tag
			   iconURL: (NSString*)iconURL
			statusText: (NSString*)statusText
{
	if(self = [super init]) {
		gamertag = [tag retain];
		icon = [[NSURL URLWithString: iconURL] retain];
		status = [statusText retain];
	}
	return self;
}

- (void)dealloc 
{
	[gamertag release];
	[icon release];
	[status release];
	[super dealloc];
}

- (NSString*)gamertag
{
	return gamertag;
}
- (NSURL*)icon
{
	return icon;
}
- (NSString*)status
{
	return status;
}
- (NSString*)name
{
	return [self gamertag];
}
- (NSString*)prefPrefix
{
	return @"Friend";
}
- (BOOL)online
{
	return 0 == [status rangeOfString: @"Playing"].location;
}
- (NSString*)currentGame
{
	if(![self online]) return nil;
	int start = [@"Playing " length];
	int end = [status rangeOfString: @"\n"].location;
	if(NSNotFound == end) end = [status length];
	return [status substringWithRange: NSMakeRange(start, end-start)];
}

@end

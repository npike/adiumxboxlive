//
//  Game.m
//  MacLive
//
//  Created by James Howard on 12/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Game.h"


@implementation Game

- (id)initWithName: (NSString*)gameName
		   iconURL: (NSString*)iconURL
{
	if(self = [super init]) {
		name = [gameName retain];
		icon = [[NSURL URLWithString: iconURL] retain];
	}
	return self;
}

- (void)dealloc
{
	[name release];
	[icon release];
	[super dealloc];
}

- (NSString*)name
{
	return name;
}
- (NSURL*)icon
{
	return icon;
}
- (NSString*)prefPrefix
{
	return @"Game";
}

@end

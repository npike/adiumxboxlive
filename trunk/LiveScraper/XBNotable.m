//
//  XBNotable.m
//  MacLive
//
//  Created by James Howard on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "XBNotable.h"


@implementation XBNotable

- (NSString*)prefPrefix
{
	[NSException raise: @"XBNotableAbstractMethod" 
				format: @"Yo, you gotta implement -prefPrefix"];
	return nil; // dumb compiler
}
- (NSString*)name
{
	[NSException raise: @"XBNotableAbstractMethod" 
				format: @"Yo, you gotta implement -name"];
	return nil;
}


- (BOOL)notify
{
	return [[NSUserDefaults standardUserDefaults] boolForKey: 
		[NSString stringWithFormat: @"%@_%@", [self prefPrefix], [self name]]];
}
- (void)setNotify: (BOOL)note
{
	[[NSUserDefaults standardUserDefaults] setBool: note 
											forKey: 
		[NSString stringWithFormat: @"%@_%@", [self prefPrefix], [self name]]];
}

@end

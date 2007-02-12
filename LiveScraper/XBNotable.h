//
//  XBNotable.h
//  MacLive
//
//  Created by James Howard on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface XBNotable : NSObject {

}

- (NSString*)prefPrefix;
- (NSString*)name;

- (BOOL)notify;
- (void)setNotify: (BOOL)note;



@end

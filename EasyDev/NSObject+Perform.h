//
//  NSObject+Perform.h
//  EasyDev
//
//  Created by hcb on 2019/12/29.
//  Copyright © 2019 cb. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Perform)

- (id)myPerform:(SEL)aSelector withTheObjects:(NSArray*)objects;

@end

NS_ASSUME_NONNULL_END

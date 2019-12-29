//
//  NSObject+Perform.m
//  EasyDev
//
//  Created by hcb on 2019/12/29.
//  Copyright © 2019 cb. All rights reserved.
//

#import "NSObject+Perform.h"

@implementation NSObject (Perform)

- (id)myPerform:(SEL)aSelector withTheObjects:(NSArray*)objects{
    //1、创建签名对象
    //  NSMethodSignature*signature = [self methodSignatureForSelector:aSelector];
    NSMethodSignature*signature = [[self class] instanceMethodSignatureForSelector:aSelector];
    //2、判断传入的方法是否存在
    if (!signature) {
        //传入的方法不存在 就抛异常
        NSString*info = [NSString stringWithFormat:@"-[%@ %@]:unrecognized selector sent to instance",[self class],NSStringFromSelector(aSelector)];
        @throw [[NSException alloc] initWithName:@"no method" reason:info userInfo:nil];
        return nil;
    }
    //3、创建NSInvocation对象
    NSInvocation*invocation = [NSInvocation invocationWithMethodSignature:signature];
    //4、保存方法所属的对象
    invocation.target = self;           // index 0
    invocation.selector = aSelector;    // index 1

    //5、设置参数
    NSInteger arguments = signature.numberOfArguments -2;
    NSUInteger objectsCount = objects.count;
    NSInteger count = MIN(arguments, objectsCount);
    [self setInv:invocation andArgs:objects argsCount:count];

    //6、调用NSinvocation对象
    [invocation invoke];

    //7、获取返回值
    id res = nil;
    if (signature.methodReturnLength ==0) return nil;
    //getReturnValue获取返回值
    [invocation getReturnValue:&res];
    return res;
}

- (void)setInv:(NSInvocation *)inv andArgs:(NSArray *)args argsCount:(NSUInteger)count{
    for (int i = 0; i<count; i++) {
        NSObject*obj = args[i];
        //处理参数是NULL类型的情况
        if ([obj isKindOfClass:[NSNull class]]) {
            obj = nil;
        }
        //对整形数值等的处理
        if([obj isKindOfClass:[NSNumber class]])      //对数值数据的处理
        {
            void *p;
            NSNumber *num = (NSNumber *)obj;
            if(strcmp([num objCType], @encode(float)) == 0)
            {
                float v = [num floatValue];
                p = &v;
            }
            else if(strcmp([num objCType], @encode(double)) == 0)
            {
                double v = [num doubleValue];
                p = &v;
            }
            else
            {
                long v = [num longValue];
                p = &v;
            }

            [inv setArgument:p atIndex:i+2];
            continue;
        }

        [inv setArgument:&obj atIndex:i+2];
    }
}

@end

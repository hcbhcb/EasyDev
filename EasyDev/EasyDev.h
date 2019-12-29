//
//  EasyDev.h
//  EasyDev
//
//  Created by hcb on 2019/12/13.
//  Copyright © 2019 cb. All rights reserved.
//

#ifndef EasyDev_h
#define EasyDev_h
#import <Foundation/Foundation.h>

@interface EasyDev : NSObject

+ (instancetype)share;
/// 解析脚本
/// @param src 脚本内容字符串
/// @param arg 调用函数时的参数，字典形式，参数名为key，参数值为value
- (id)loadSrc:(NSString *)src agr:(NSDictionary *)arg;

@end


#endif /* EasyDev_h */

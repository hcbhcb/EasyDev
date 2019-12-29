//
//  Calculator.m
//  EasyDev
//
//  Created by hcb on 2019/12/13.
//  Copyright © 2019 cb. All rights reserved.
//

#import "EasyDev.h"
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#import <objc/message.h>
#import "AppDelegate.h"
#import "Calculator.h"
#import "NSObject+Perform.h"

#define LogOn 0
@interface EasyDev ()
{
    // 利用objc_msgSend形式调用方法，需要提前声明返回值类型，参数个数和参数类型，因此不同参数类型和参数个数组合起来有非常多的可能，因此此处还有许多需要定义的原型函数。正在尝试使用通用形式调用。通过performselector调用，无法传入数字类型的参数，且参数个数无法支持多个。尝试在NSObject下增加NSInvocation形式的调用，但是其也不是万能的，部分函数调用提示无对应方法，如UIFont的systemFontOfSize类方法，不论通过何种方式，得出的font均是font字体为0的结果。
    id (*idfunc1)(id, SEL, id);
    id (*intfunc1)(id, SEL, NSInteger);
    id (*floatfunc1)(id, SEL, float);
    id (*idintidfunc1)(id, SEL, id, NSInteger, id);
}

@property (nonatomic, assign) UIWindow *win;
@property (nonatomic, strong) NSMutableArray <NSDictionary <NSString *,id>*>*allObjs;
@property (nonatomic, strong) NSMutableArray <NSDictionary *>*functions;

@end

@implementation EasyDev

+ (instancetype)share {
    static dispatch_once_t onceToken;
    static EasyDev *dev;
    dispatch_once(&onceToken, ^{
        dev = [[EasyDev alloc] init];
        // NSLog(@"EasyDev init successfully");
    });
    return dev;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        idfunc1 = (id (*)(id, SEL, id))objc_msgSend;
        intfunc1 = (id (*)(id, SEL, NSInteger))objc_msgSend;
        idintidfunc1 = (id (*)(id, SEL, id, NSInteger, id))objc_msgSend;
        floatfunc1 = (id (*)(id, SEL, float))objc_msgSend;
    }
    return self;
}

/// 存储所有创建的对象
- (NSMutableArray *)allObjs {
    if (!_allObjs) {
        _allObjs = [NSMutableArray array];
    }
    return _allObjs;
}

/// 存储定义的函数
- (NSMutableArray *)functions {
    if (!_functions) {
        _functions = [NSMutableArray array];
    }
    return _functions;
}

- (id)commonMethod:(NSString *)name args:(id)args {
    return [self loadSrc:args agr:nil];
}

- (NSDictionary *)funcBodyWithName:(NSString *)name {
    for (NSDictionary *dic in self.functions) {
        if ([dic[@"name"] isEqualToString:name]) {
            return dic;
        }
    }
    return nil;
}

- (id)btnCommonMethod:(UIButton *)args {
    NSString *script = [self getProperty:args key:@"userScript"];
    NSLog(@"按钮点击：%@",script);
    NSDictionary *f = [self funcBodyWithName:script];
    if (!f) {
        NSLog(@"函数未定义");
        return nil;
    }
    NSString *varName = f[@"args"][0];
    return [self loadSrc:f[@"body"] agr:@{varName:args}];
}


- (NSString *)splitSrc:(NSString *)src {
    if (![src containsString:@"def "]) {
        return src;
    }

    NSMutableArray <NSString *>*lines = [src componentsSeparatedByString:@"\n"].mutableCopy;
    // 如果某一行顶头开始，则函数结束
    __block NSUInteger endInd = 0;
    __block NSUInteger startInd = 0;
    // 除去函数剩余的行
    __block NSMutableArray *restLines = [NSMutableArray array];
    __block NSMutableArray *remove = [NSMutableArray array];

    [lines enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self handleShouldReturn:obj]) {
            [remove addObject:obj];
        }
    }];
    [remove enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [lines removeObject:obj];
    }];
    __block BOOL isinfunc = NO;
    [lines enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {

        if (![obj hasPrefix:@"    "] && isinfunc) {
            isinfunc = NO;
            endInd = idx;
            NSString *def = lines[startInd];
            NSRange r = [def rangeOfString:@"("];
            NSString *name = [def substringWithRange:NSMakeRange(4, r.location-4)];
            NSArray *funs = [lines subarrayWithRange:NSMakeRange(startInd+1, endInd-startInd-1)];
            NSArray *args = [[def substringWithRange:NSMakeRange(r.location+1, [def rangeOfString:@")"].location-r.location-1)] componentsSeparatedByString:@","];
            NSMutableArray *newarr = [NSMutableArray array];
            [funs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [newarr addObject:obj];
            }];
            NSDictionary *funcDic = @{
                @"name":name,
                @"body":newarr,
                @"args":args,
            };
            [self.functions addObject:funcDic];
            startInd = 0;
            endInd = 0;
            if (![obj hasPrefix:@"def "]) {
                [restLines addObject:obj];
            }
        } else {
            if (!isinfunc && ![obj hasPrefix:@"def "]) {
                [restLines addObject:obj];
            }
        }
        if ([obj hasPrefix:@"def "]) {
            startInd = idx;
            endInd = startInd;
            isinfunc = YES;
        }
    }];

    NSString *result = [restLines componentsJoinedByString:@"\n"];
    return result;
}

/// 解析脚本
/// @param src 脚本内容字符串
/// @param arg 调用函数时的参数，字典形式，参数名为key，参数值为value
- (id)loadSrc:(id )src agr:(nullable NSDictionary *)arg {
    if (arg) {
        // NSLog(@"入参：%@",arg);
    }

    NSArray <NSString *>*script;
    if ([src isKindOfClass:NSArray.class]) {
        script = (NSArray *)src;
    } else {
        src = [src stringByReplacingOccurrencesOfString:@"\t" withString:@"    "];
        // 拆分普通语句和函数定义
        src = [self splitSrc:src];
        script = [src componentsSeparatedByString:@"\n"];
    }
    __block NSUInteger funcJump = 0;
    // 解析脚本
    [script enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (funcJump > 0) {
            funcJump -= 1;
            return;
        }
        // 语句中的字符串数字变量替换
        if ([obj containsString:@" = "] || [obj containsString:@" > "] || [obj containsString:@" < "]) {
            NSArray *res = [self handelReplaceVar:obj arg:arg];
            // 若遇到赋值语句直接执行了，不用往下
            if ([res[1] integerValue]) {
                return;
            } else {
                obj = res[0];
            }
        }

        if ([obj rangeOfString:@"^ *\\w+ = \\[.*\\]" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 数组定义 a_arr = [1, 2, 3, 4, b]
            [self handleDefineArr:obj arg:arg];
        }else if ([obj rangeOfString:@"^ *\\w+ = \\{.*\\}" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 字典定义 dic = {"key":"value", "key2":"value2"}
            [self handleDefineDict:obj arg:arg];
        } else if ([obj rangeOfString:@"^ *\\w+\\[\\d+\\] = .*" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 数组赋值a[0] = 1   a[1] = "123"  a[1] = a[0]     a[1] = a
            [self handleArrSaveValue:obj arg:arg];
        } else if ([obj rangeOfString:@"^ *\\w+\\[.*\\] = .*" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 字典赋值 dic["ke_y"] = "12345"
            [self handleDictSaveValue:obj arg:arg];
        } else if ([obj rangeOfString:@"print\\(.*\\)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 打印语句
            [self handlePrint:obj arg:arg];
        } else if ([obj rangeOfString:@" = NS"].location != NSNotFound || [obj rangeOfString:@" = UI"].location != NSNotFound) {
            // UIKit和Foundation库对象创建
            [self handelCreateUI:obj];
        } else if ([obj rangeOfString:@"^ *\\w+\\(.*\\)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // python格式的函数调用：a_b_c(arg1,key=arg), 暂不支持带星号的参数传递，此模式可匹配print，print需单独处理
            [self handelCallPyFunc:obj];
        } else if ([obj rangeOfString:@"^ *\\w+ = (\\w+\\.){1,}\\w+\\(.*\\)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // OC风格函数调用并赋值：符合形如 var = a.b.func(arg1,arg2)    a = b.c()   OC函数调用并进行单变量赋值的语句
            [self handleCallOCMethondAndSave:obj arg:arg];
        }  else if ([obj rangeOfString:@"^ *(\\w+\\.)+\\w+\\(.*\\)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // OC风格函数调用：符合形如  a.b.func(arg1,arg2)
            [self handleCallOCMethond:obj arg:arg];
        } else if ([obj rangeOfString:@"(\\w+\\.){1,}\\w+ = .*" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 对象属性赋值 a.b = c
            [self handleObjProperty:obj arg:arg];
        }  else if ([obj rangeOfString:@"(\\w+_?){1,} = (\".*\")?(\\d+.?\\d+)?(\\w+_?)?$" options:NSRegularExpressionSearch].location != NSNotFound) {
            // 普通变量赋值 a = b, a_b = c a = "123_123fm;ew"
            [self handelSaveVar:obj];
        } else if ([obj containsString:@"+"] || [obj containsString:@"-"] || [obj containsString:@"*"] || [obj containsString:@"/"]) {
            // 四则混合运算
            [self handelCalculate:obj arg:arg];
        } else if ([obj containsString:@"for x in range("]) {
            // for循环语句
            NSMutableArray *lastScript = [script subarrayWithRange:NSMakeRange(idx, script.count-idx)].mutableCopy;
            lastScript[0] = obj; // 上面替换过的值需要放进去
            funcJump = [self handleFor:obj script:lastScript arg:arg];
        } else if ([obj containsString:@"if "] && [obj hasSuffix:@":"]) {
            // if语句
            NSMutableArray *lastScript = [script subarrayWithRange:NSMakeRange(idx, script.count-idx)].mutableCopy;
            lastScript[0] = obj; // 上面替换过的值需要放进去
            funcJump = [self handleIf:obj script:lastScript arg:arg];
        } else {
            NSLog(@"不支持的语句：%@",obj);
        }
    }];

    return nil;
}

- (void)handleDefineDict:(NSString *) obj arg:(id)arg {
    NSArray *part = [obj componentsSeparatedByString:@" = "];
    NSString *data = part.lastObject;
    // = 后面部分必须为json字符串格式才能解析
    NSMutableDictionary *dic = [[NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil] mutableCopy];

    NSDictionary *newDic = @{part[0]:dic};
    NSInteger indx = [self haveVar:part[0]];
    if (indx>=0) {
        [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
    } else {
        [self.allObjs addObject:newDic];
    }
}

- (void)handleDictSaveValue:(NSString *) obj arg:(id)arg {
    NSArray *part = [obj componentsSeparatedByString:@" = "];
    NSString *first = part[0];

    NSRange r2 = [first rangeOfString:@"["];
    NSString *dictName = [first substringToIndex:r2.location];
    NSString *key = [first substringWithRange:NSMakeRange(r2.location+1, first.length-2-r2.location)];
    key = [self removeFix:key];
    NSMutableDictionary *dict = [self getObjFromAllobj:dictName];
    NSString *value = part[1];
    if ([value hasPrefix:@"\""]) {
        // 字符串
        value = [self removeFix:value];
    } else if ([value rangeOfString:@"^\\d+" options:NSRegularExpressionSearch].location != NSNotFound) {
        // 数字
    } else {
        // 变量引用
        id res = [self getObjFromAllobj:value];
        if (res) {
            value = res;
        }
    }

    if (value) {
        dict[key] = value;
    }
}


- (void)handleArrSaveValue:(NSString *) obj arg:(id)arg {
    NSArray *part = [obj componentsSeparatedByString:@" = "];
    NSString *first = part[0];

    NSRange r2 = [first rangeOfString:@"["];
    NSString *arrName = [first substringToIndex:r2.location];
    NSString *indexStr = [first substringWithRange:NSMakeRange(r2.location+1, first.length-2-r2.location)];
    NSUInteger index = [indexStr integerValue];
    NSMutableArray *arr = [self getObjFromAllobj:arrName];
    NSString *value = part[1];
    if ([value hasPrefix:@"\""]) {
        // 字符串
        value = [self removeFix:value];
    } else if ([value rangeOfString:@"^\\d+" options:NSRegularExpressionSearch].location != NSNotFound) {
        // 数字
    } else {
        // 变量引用
        value = [self getObjFromAllobj:value];
    }

    if (value && index < arr.count-1) {
        arr[index] = value;
    }
}

- (void)handleDefineArr:(NSString *) obj arg:(id)arg {
    NSArray *part = [obj componentsSeparatedByString:@" = "];
    NSString *data = [part.lastObject stringByReplacingOccurrencesOfString:@"[" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@"]" withString:@""];
    NSMutableArray *arrobjs = [data componentsSeparatedByString:@", "].mutableCopy;
    [arrobjs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        arrobjs[idx] = [self removeFix:obj];
    }];
    NSDictionary *newDic = @{part[0]:arrobjs};
    NSInteger indx = [self haveVar:part[0]];
    if (indx>=0) {
        [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
    } else {
        [self.allObjs addObject:newDic];
    }
}

- (void)handelCallPyFunc:(NSString *) obj  {
    NSRange r = [obj rangeOfString:@"\\w+" options:NSRegularExpressionSearch];
    NSString *name = [obj substringWithRange:r];
    NSString *endArg = [obj substringFromIndex:name.length+1];
    endArg = [endArg substringToIndex:endArg.length-1];

    NSDictionary *f = [self funcBodyWithName:name];
    if (!f) {
        NSLog(@"函数未定义:%@",obj);
        return;
    }
    NSString *varName = f[@"args"][0];
    [self loadSrc:f[@"body"] agr:@{varName:endArg}];
}

- (BOOL)handleShouldReturn:(NSString *) obj {
    if ([obj hasPrefix:@"#"] || [obj isEqualToString:@"    "] || obj.length<3) {
        return YES;
    }
    return NO;
}

- (NSUInteger)handleIf:(NSString *)obj script:(NSArray *)script arg:(NSDictionary *)arg{
    // 取得if else语句整体，若哪块满足，执行哪块，完毕后跳过整体行数

    NSArray <NSArray <NSString *>*>*body = [self getFuncBody:script isIf:YES];
    [body enumerateObjectsUsingBlock:^(NSArray<NSString *> * _Nonnull subbody, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *first = subbody.firstObject;
        first = [first stringByReplacingOccurrencesOfString:@"elif" withString:@""];
        first = [first stringByReplacingOccurrencesOfString:@"if" withString:@""];
        first = [first stringByReplacingOccurrencesOfString:@":" withString:@""];
        first = [first stringByReplacingOccurrencesOfString:@" " withString:@""];
        first = [self handelReplaceVar:first arg:nil][0];
        if ([self compare:first]) {
            [self loadSrc:[subbody subarrayWithRange:NSMakeRange(1, subbody.count-1)] agr:nil];
            *stop = YES;
        }
    }];
    __block NSUInteger allCount = 0;
    [body enumerateObjectsUsingBlock:^(NSArray<NSString *> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        allCount += obj.count;
    }];
    return allCount;
}

- (BOOL)compare:(NSString *)first {
    if (![first isKindOfClass:NSString.class]) {
        return NO;
    }
    if ([first isEqualToString:@"else"]) {
        return YES;
    }
    BOOL res = NO;
    NSArray *nums = nil;
    if ([first containsString:@">="]) {
        nums = [first componentsSeparatedByString:@">="];
        if ([nums.firstObject floatValue] >= [nums.lastObject floatValue]) {
            res = YES;
        }
    } else if ([first containsString:@"<="]) {
        nums = [first componentsSeparatedByString:@"<="];
        if ([nums.firstObject floatValue] <= [nums.lastObject floatValue]) {
            res = YES;
        }
    } else if ([first containsString:@">"]) {
        nums = [first componentsSeparatedByString:@">"];
        if ([nums.firstObject floatValue] > [nums.lastObject floatValue]) {
            res = YES;
        }
    } else if ([first containsString:@"<"]) {
        nums = [first componentsSeparatedByString:@"<"];
        if ([nums.firstObject floatValue] < [nums.lastObject floatValue]) {
            res = YES;
        }
    } else if ([first containsString:@"=="]) {
        nums = [first componentsSeparatedByString:@"=="];
        if ([nums.firstObject floatValue] == [nums.lastObject floatValue]) {
            res = YES;
        }
    }
    return res;

}

- (NSUInteger)handleFor:(NSString *)obj script:(NSArray *)script arg:(NSDictionary *)arg{
    // 循环语句 获取循环次数，函数体，for执行 函数体（重新调用本方法）
    NSString *countStr = [obj substringWithRange:NSMakeRange([obj rangeOfString:@"("].location+1, [obj rangeOfString:@")"].location-[obj rangeOfString:@"("].location-1)];
    NSUInteger count = [countStr integerValue];
    if (!count) {
        count = [[self getObjFromAllobj:countStr] integerValue];
    }
    NSArray *body = [self getFuncBody:script isIf:NO];
    // 因为for下面的语句在当前遍历中，会在for执行完了后继续执行，需要跳过for循环体
    for (NSUInteger i = 0; i < count; i++) {
        NSDictionary *dic = @{@"i":@(i)};
        [self loadSrc:body agr:dic];
    }
    return body.count;
}

- (void)handlePrint:(NSString *)obj arg:(NSDictionary *)arg {
    NSRange r = [obj rangeOfString:@")"];
    if (r.location != NSNotFound) {
        NSRange r2 = [obj rangeOfString:@"print("];
        NSString *varName = [obj substringWithRange:NSMakeRange(r2.location+r2.length, obj.length-r2.location-r2.length-1)];
        // 打印普通字符串
        if ([varName hasPrefix:@"\""] && [varName hasSuffix:@"\""]) {
            NSLog(@"%@", [self removeFix:varName]);
        } else {
            // 打印对象的属性
            __block id value = nil;
            if ([varName containsString:@"."]) {
                NSArray *prop = [varName componentsSeparatedByString:@"."];

                value = [self getObjFromAllobj:prop.firstObject];
                if (prop.count>1) {
                    [prop enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (idx) {
                            @try {
                                value = [value valueForKey:obj];
                            } @catch (NSException *exception) {
                                NSLog(@"取值错误print func  key=%@",obj);
                            } @finally {

                            }
                        }
                    }];
                }
            } else {
                value = [self getObjFromAllobj:varName];
                if (!value) {
                    value = arg.allValues.firstObject;
                }
                if (!value) {
                    value = varName;
                }
            }
            NSLog(@"%@",value);
        }
    }
}

- (NSString *)removeFix:(NSString *)str {

    if ([str isKindOfClass:NSString.class] && [str hasPrefix:@"\""] && [str hasSuffix:@"\""]) {
        str = [str substringWithRange:NSMakeRange(1, str.length-2)];
        // 去除转义
        str = [str stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    }
    return str;
}
- (void)handleObjProperty:(NSString *)origStr arg:(NSDictionary *)arg{
    // 对象赋值语句
    NSArray <NSString *>*outs = [origStr componentsSeparatedByString:@" = "];

    NSArray *a = [outs.firstObject componentsSeparatedByString:@"."];

    NSString *var = [a.firstObject stringByReplacingOccurrencesOfString:@" " withString:@""];
    __block id ocObj = [self getObjFromAllobj:var];

    if (a.count>2) {
        [a enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx && idx < a.count-1) {
                @try {
                    ocObj = [ocObj valueForKey:obj];
                } @catch (NSException *exception) {
                    NSLog(@"取值错误handleObjProperty：%@ key=%@",origStr,obj);
                } @finally {

                }
            }
        }];
    }

    if ([var isEqualToString:@"sender"] && arg && arg[@"sender"]) {
        ocObj = arg[@"sender"];
    }
    if (ocObj) {
        NSString *key = a.lastObject;
        // a.b = c  如果a没有属性，则添加b属性，有则是赋值
        // frame color 单独设置
        id value = outs.lastObject;
        id tmp = [self getObjFromAllobj:value];
        if (tmp) {
            value = tmp;
        }
        [self processObjProperty:ocObj key:key value:value];

    }
}

- (id)processObjProperty:(id)ocObj key:(NSString *)key value:(id)value {
    if (!value) {
        return [self executeFunc:ocObj func:key args:value];
    }
    BOOL isNumber = NO;
    if ([value isKindOfClass:NSString.class] && ![value hasPrefix:@"\""] && ![value hasSuffix:@"\""]) {
        if ([value rangeOfString:@"\\d+[.]?\\d*" options:NSRegularExpressionSearch].location != NSNotFound) {
            isNumber = YES;
        }
    } else if ([value isKindOfClass:NSString.class]) {
        value = [self removeFix:value];
    }
    BOOL shouldSet = YES;
    if ([key isEqualToString:@"title"] && [ocObj isKindOfClass:UIButton.class]) {
        UIButton *btn = (UIButton *)ocObj;
        shouldSet = NO;
        [btn setTitle:value forState:UIControlStateNormal];
    } else if ([key isEqualToString:@"frame"] || [key isEqualToString:@"center"] || [key isEqualToString:@"point"]) {
        NSString *frame = value;
        if ([frame containsString:@"NSPoint"]) {
            CGPoint p = CGPointFromString(frame);
            value = [NSValue valueWithCGPoint:p];
        } else if ([frame containsString:@"NSRect"]) {
            CGRect p = CGRectFromString(frame);
            value = [NSValue valueWithCGRect:p];
        } else {
            frame = [frame substringWithRange:NSMakeRange(1, frame.length-2)];
            NSArray *points = [frame componentsSeparatedByString:@","];
            if (points.count == 2) {
                CGPoint p = CGPointMake([points[0] floatValue],[points[1] floatValue]);
                value = [NSValue valueWithCGPoint:p];
            } else if (points.count==4) {
                CGRect rect = CGRectMake([points[0] floatValue],[points[1] floatValue], [points[2] floatValue], [points[3] floatValue]);
                value = [NSValue valueWithCGRect:rect];
            }
        }
    } else if ([key containsString:@"Color"]) {
        NSString *cl = value;
        cl = [cl substringWithRange:NSMakeRange(1, cl.length-2)];
        UIColor *c = [self colorWithHexString:cl];
        value = c;
    }
    if (!shouldSet) {
        return nil;
    }
    @try {
        // 若为数字
        //        if (isNumber) {
        //            value = @([value floatValue]);
        //        }
        //
        // 若ocObj响应set方法，则可以使用setValue:forKey，否则执行原方法
        NSString *fname = key;
        if (![fname hasPrefix:@"set"]) {
            fname = [NSString stringWithFormat:@"set%@%@%@",[fname substringToIndex:1].uppercaseString,[fname substringFromIndex:1],[fname hasSuffix:@":"]?@"":@":"];
            if ([ocObj respondsToSelector:NSSelectorFromString(fname)]) {
                return [self executeFunc:ocObj func:fname args:@[value]];
            } else if ([ocObj respondsToSelector:NSSelectorFromString(key)]) {
                if ([key isEqualToString:@"objectAtIndex:"]) {
                    NSArray *a = ocObj;
                    if ([value integerValue] < a.count) {
                        return [a objectAtIndex:[value integerValue]];
                    } else {
                        NSLog(@"数组越界：%@  %@",value,key);
                    }
                    return nil;
                }
                return [self executeFunc:ocObj func:key args:@[value]];
            }
        } else {
            if ([ocObj respondsToSelector:NSSelectorFromString(key)]) {
                return [self executeFunc:ocObj func:key args:@[value]];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"设置属性出错：%@  %@  %@",value,key,exception);
    } @finally {

    }
}

- (void)handelCalculate:(NSString *)obj arg:(NSDictionary *)arg{
    NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];
    NSString *replace = @"";
    if (arg) {
        replace = [arg[@"i"] stringValue];
    }

    NSString *exp = [outs.lastObject stringByReplacingOccurrencesOfString:@"x" withString:replace?:@""];

    NSString *res = [Calculator calcComplexFormulaString:exp];
    NSString *varname = [outs.firstObject stringByReplacingOccurrencesOfString:@"    " withString:@""];
    // 若其中已存在该变量，直接替换
    NSDictionary *newDic = @{varname:res};
    NSInteger indx = [self haveVar:varname];
    if (indx>=0) {
        [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
    } else {
        [self.allObjs addObject:newDic];
    }

}

- (void)handelCreateUI:(NSString *)obj {
    NSArray *a = [self splitOCObjCreator:obj];
    if (a.count == 3) {
        id ocObj = [self ocobjWithCls:a[1] property:a[2]];
        if ([ocObj isKindOfClass:UIViewController.class]) {
            UIViewController *vc = (UIViewController *)ocObj;
            [self.win.rootViewController presentViewController:vc animated:YES completion:nil];
            vc.view.backgroundColor = [UIColor lightGrayColor];
        }
        NSString *varname = [a[0] stringByReplacingOccurrencesOfString:@"    " withString:@""];
        if (ocObj) {
            [self.allObjs addObject:@{varname:ocObj}];
        }
    }
}

- (NSArray *)handelReplaceVar:(NSString *)obj  arg:(NSDictionary *)arg{
    if ([obj containsString:@"print("]) {
        return @[obj,@0];
    }
    NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];
    __block NSString *lst = outs.lastObject.copy;
    // 原始字符串，不用替换
    if ([lst hasPrefix:@"\""] && [lst hasSuffix:@"\""]) {
        return @[obj,@0];
    }
    // 数组字典元素访问
    NSRange r = [lst rangeOfString:@"\\w+\\[[^=]*\\]" options:NSRegularExpressionSearch];
    while (r.location != NSNotFound) {
        NSString *tmp = [lst substringWithRange:r];
        NSRange r2 = [tmp rangeOfString:@"["];
        NSString *varName = [tmp substringToIndex:r2.location];
        NSString *indexStr = [tmp substringWithRange:NSMakeRange(r2.location+1, tmp.length-2-r2.location)];
        NSArray *var = [self getObjFromAllobj:varName];
        if ([var isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *dict = (NSMutableDictionary *)var;
            if ([indexStr hasPrefix:@"\""]) {
                indexStr = [self removeFix:indexStr];
            }
            lst = [lst stringByReplacingCharactersInRange:r withString: dict[indexStr]];
        } else {
            NSUInteger index = 0;
            NSString *savedIndex = [self getObjFromAllobj:indexStr];
            if (savedIndex) {
                index = [savedIndex integerValue];
            } else if ([indexStr rangeOfString:@"\\d+" options:NSRegularExpressionSearch].location != NSNotFound) {
                index = [indexStr integerValue];
            } else if (arg && arg[@"i"] && ([indexStr isEqualToString:@"x"] || [indexStr isEqualToString:@"i"])) {
                index = [arg[@"i"] integerValue];
            }
            if (var && index > var.count-1) {
                NSLog(@"Index out of range of array:%@, index:%lu",var,index);
                return @[obj,@1];
            } else {
                lst = [lst stringByReplacingCharactersInRange:r withString:var[index]];
            }
        }
        r = [lst rangeOfString:@"\\w+\\[\\w+\\]" options:NSRegularExpressionSearch];

    }
    // 对象属性值替换 和方法调用后的赋值
    if ([lst containsString:@"."] && ![lst containsString:@"("]) {
        NSArray *objPro = [outs.lastObject componentsSeparatedByString:@"."];
        __block id ocObj = [self getObjFromAllobj:objPro.firstObject];

        if (!ocObj && arg && arg[@"sender"]) {
            ocObj = arg[@"sender"];
        }
        [objPro enumerateObjectsUsingBlock:^(NSString *tmpKey, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx) {
                ocObj = [ocObj valueForKey:tmpKey];
            }
        }];
        obj = [NSString stringWithFormat:@"%@ = %@",outs.firstObject, ocObj];
        return @[obj,@0];
    } else if ([lst containsString:@"."] && [lst containsString:@"("]) {
        id ocobj = [self handleCallOCMethond:lst arg:arg];
        if ([ocobj isKindOfClass:NSObject.class]) {
            // 是OC源类型，暂不替换到字符串，否则下一步在解析时出错，为OC类型，若本句为赋值，则赋值并返回跳过一行，
            NSString *varname = [outs.firstObject stringByReplacingOccurrencesOfString:@" " withString:@""];
            if ([varname rangeOfString:@"\\w+" options:NSRegularExpressionSearch].location != NSNotFound) {
                // 记录赋值语句
                NSInteger indx = [self haveVar:varname];
                if (indx>=0) {
                    [self.allObjs replaceObjectAtIndex:indx withObject:@{varname:ocobj}];
                } else {
                    [self.allObjs addObject:@{varname:ocobj}];
                }
                return @[ocobj,@1];
            }

        }
        if (ocobj) {
            obj = [NSString stringWithFormat:@"%@ = %@",outs.firstObject, ocobj];
            return @[obj,@0];
        }
    }

    // 单变量替换
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];

    [self.allObjs.reverseObjectEnumerator.allObjects enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id v = obj.allValues.firstObject;
        if ([v isKindOfClass:NSString.class]) {
            [keys addObject:obj.allKeys.firstObject];
            [values addObject:v];
        }
    }];
    // 执行替换
    [keys enumerateObjectsUsingBlock:^(NSString *tmpKey, NSUInteger idx, BOOL * _Nonnull stop) {
        // 单词开始和结束时是所记录的变量，不能是其中一部分
        NSString *regex = [NSString stringWithFormat:@"\\b%@\\b", tmpKey];
        if ([lst rangeOfString:regex options:NSRegularExpressionSearch].location != NSNotFound) {
            lst = [lst stringByReplacingOccurrencesOfString:tmpKey withString:values[idx]];
        }
    }];
    if (outs.count==1) {
        return @[lst,@0];
    }
    obj = [NSString stringWithFormat:@"%@ = %@",outs.firstObject, lst];
    return @[obj,@0];

}

- (id)handleCallOCMethondAndSave:(NSString *)orgStr arg:(NSDictionary *)arg {
    NSArray *part = [orgStr componentsSeparatedByString:@" = "];
    id res = [self handleCallOCMethond:part.lastObject arg:arg];
    if (res) {
        NSDictionary *newDic = @{part[0]:res};
        // 若其中已存在该变量，直接替换
        NSInteger indx = [self haveVar:part[0]];
        if (indx>=0) {
            [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
        } else {
            [self.allObjs addObject:newDic];
        }
    }
    return nil;
}


- (id)handleCallOCMethond:(NSString *)tmpStr arg:(NSDictionary *)arg {

    NSString *orgStr = tmpStr;
    // 找出函数执行的对象
    NSMutableArray *a = [[orgStr substringToIndex:[orgStr rangeOfString:@"("].location] componentsSeparatedByString:@"."].mutableCopy;
    NSString *funcName = a.lastObject;
    // 将函数名称更改为形如  a:b:c:d形式
    // 函数名称：a_b__c,下划线代表一个参数位置，两个下划线代表函数声明时自身的下划线
    funcName = [funcName stringByReplacingOccurrencesOfString:@"__" withString:@"#"]; // 先把双下划线替换为其他符号，避免下一步被换成冒号
    funcName = [funcName stringByReplacingOccurrencesOfString:@"_" withString:@":"]; // 替换为冒号参数
    funcName = [funcName stringByReplacingOccurrencesOfString:@"#" withString:@"_"]; // 替换回去
    NSString *firstName = a.firstObject;

    // 取出括号内的参数
    NSRange r1 = [orgStr rangeOfString:@"("];
    NSString *argsValue = [orgStr substringWithRange:NSMakeRange(r1.location+1,orgStr.length-r1.location-2)];

    Class cls = NSClassFromString(firstName);
    if (cls) {
        // OC类方法的调用，转为类  Class.a().b(1)  Class.a__b_c_d_d(1, 2, 3)
        if (a.count == 2) {
            NSMutableArray *tmpArgs = [argsValue componentsSeparatedByString:@", "].mutableCopy;
            [tmpArgs enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                // 如果该参数是数字，则转为NSNumber
                if ([obj rangeOfString:@"^\\d+\\.\\d+$" options:NSRegularExpressionSearch].location != NSNotFound) {
                    // 小数
                    [tmpArgs replaceObjectAtIndex:idx withObject:[NSString stringWithFormat:@"@FLOAT:%@",obj]];
                } else if ([obj rangeOfString:@"^\\d+$" options:NSRegularExpressionSearch].location != NSNotFound) {
                    // 整数
                    [tmpArgs replaceObjectAtIndex:idx withObject:[NSString stringWithFormat:@"@INT:%@",obj]];
                } else {
                    id r = [self getObjFromAllobj:obj];
                    if (r) {
                        [tmpArgs replaceObjectAtIndex:idx withObject:r];
                    }
                }
            }];
            if (argsValue.length) {
                // 最后一个参数需要在函数名称上拼接冒号(一个参数位置)
                funcName = [funcName stringByAppendingString:@":"];
            }
            id callRes = [self executeFunc:cls func:funcName args:tmpArgs];
            return callRes;
        }
        return nil;
    }
    // 非类方法调用，则为对象方法调用，vc.view.setBgcolor(xxxx), 需要取出属性，再调用方法
    [a removeLastObject];
    __block id endobj = nil;
    [a enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0) {
            endobj = [self getObjFromAllobj:obj];

        } else {
            @try {
                endobj = [endobj valueForKey:obj];
            } @catch (NSException *exception) {
                NSLog(@"取值错误：%@ key=%@",orgStr,obj);
            } @finally {

            }
        }
    }];

    id value = [self getObjFromAllobj:argsValue];
    // 有参数则改变函数名
    if (argsValue || argsValue.length) {
        funcName = [funcName stringByAppendingString:@":"];
    }
    if (!endobj) {
        NSLog(@"解析错误：%@",orgStr);
        return nil;
    }
    @try {
        return [self processObjProperty:endobj key:funcName value:value?:argsValue];
    } @catch (NSException *exception) {
        NSLog(@"Call OC Faild:%@  %@",exception,orgStr);
    } @finally {

    }
    return nil;
}

- (void)handelSaveVar:(NSString *)obj {
    // 存储变量
    NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];
    NSString *varname = [outs.firstObject stringByReplacingOccurrencesOfString:@"    " withString:@""];
    // 若其中已存在该变量，直接替换
    NSString *v = outs.lastObject;
    v = [self removeFix:v];
    NSDictionary *newDic = @{varname:v};
    NSInteger indx = [self haveVar:varname];
    if (indx>=0) {
        [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
    } else {
        [self.allObjs addObject:newDic];
    }
}

#pragma mark - 通用方法
- (NSInteger)haveVar:(NSString *)name {
    __block NSInteger indx = -1;
    name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
    [self.allObjs enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.allKeys.firstObject isEqualToString:name]) {
            indx = idx;
            *stop = YES;
        }
    }];
    return indx;
}

/// 获取一条for if等语句的语句体
/// @param arr 语句列表
- (NSArray *)getFuncBody:(NSArray <NSString *>*)arr isIf:(BOOL)isIf{
    // 看语句首行缩进，随后比其大的缩进都属于语句体，直到和其一样缩进的语句
    NSUInteger enter = [self enterCount:arr[0]];
    NSMutableArray *ifArr = [NSMutableArray array];

    __block NSUInteger endind = 0;
    __block NSUInteger tmpind = 0;

    [arr enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 忽略注释语句
        if ([[obj stringByReplacingOccurrencesOfString:@" " withString:@""] hasPrefix:@"#"]) {
            return ;
        }
        if (idx>0) {
            if ([self enterCount:obj] <= enter) {
                if (isIf) {
                    // 看这一行是不是else。elif:
                    if ([obj containsString:@"else:"] || [obj containsString:@"elif "]) {
                        [ifArr addObject:[arr subarrayWithRange:NSMakeRange(tmpind, idx-tmpind)]];
                        tmpind = idx;
                    } else {
                        endind = idx;
                        *stop = YES;
                    }
                } else {

                    endind = idx;
                    *stop = YES;
                }
            }
        }
    }];
    if (isIf) {

        [ifArr addObject:[arr subarrayWithRange:NSMakeRange(tmpind, arr.count-tmpind)]];

        return ifArr;
    }
    if (!endind) {
        endind = arr.count;
    }
    return [arr subarrayWithRange:NSMakeRange(1, endind-1)];
}

/// 判断一条语句的缩进
/// @param str 单行语句字符串
- (NSUInteger)enterCount:(NSString *)str {
    NSUInteger enter = 0;
    for (int i=0; i<str.length; i++) {
        if ([str characterAtIndex:i] != ' ') {
            break;
        } else {
            enter += 1;
        }
    }
    return enter;
}

/// 从已创建对象池中取出对应名字的对象
/// @param varName 变量名
- (id)getObjFromAllobj:(NSString *)varName {
    varName = [varName stringByReplacingOccurrencesOfString:@" " withString:@""];
    __block id end = nil;
    [self.allObjs.reverseObjectEnumerator.allObjects enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = (NSDictionary *)obj;
        if ([dic.allKeys.firstObject isEqualToString:varName]) {
            end = dic.allValues.firstObject;
            *stop = YES;
        }
    }];
    return end;
}

/// 添加属性，跟对象有关
- (void)setProperty:(id)obj key:(NSString *)key value:(id)value {
    objc_setAssociatedObject(obj, (__bridge const void * _Nonnull)(key), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/// 获取属性
- (id)getProperty:(id)obj key:(NSString *)key {
    SEL slc = NSSelectorFromString(key);
    if ([obj respondsToSelector:slc]) {
        return [self executeFunc:obj func:key args:nil];
    }
    return objc_getAssociatedObject(obj, (__bridge const void * _Nonnull)(key));
}

/// 返回[变量名，类名，属性字典]
/// @param src 文本，不能换行
- (NSArray *)splitOCObjCreator:(NSString *)src {
    NSArray *a = [src componentsSeparatedByString:@" = "];
    NSString *varName = a.firstObject;
    NSString *lst = (NSString *)a.lastObject;
    lst = [lst substringToIndex:lst.length-1];  // 去除后括号
    NSString *className = [lst substringToIndex:[lst rangeOfString:@"("].location];
    NSArray *pro = [[lst substringFromIndex:[lst rangeOfString:@"("].location+1] componentsSeparatedByString:@", "];
    __block NSMutableDictionary *prodic = [NSMutableDictionary dictionary];
    [pro enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 当属性列表中为a=b, 时，以等号进行key和value值解析，当b中含等号，则解析错误
        if (obj.length) {
            NSArray *b = [obj componentsSeparatedByString:@"="];

            if ([b.firstObject isEqualToString:@"frame"]) {
                NSString *f = (NSString *)b.lastObject;
                f = [f substringWithRange:NSMakeRange(1, f.length-2)];
                NSArray *a = [f componentsSeparatedByString:@","];
                CGRect rect = CGRectMake([a[0] floatValue],[a[1] floatValue], [a[2] floatValue], [a[3] floatValue]);
                [prodic setValue:[NSValue valueWithCGRect:rect] forKey:b.firstObject];

            } else if ([b.firstObject containsString:@"Color"]) {
                NSString *cl = (NSString *)b.lastObject;
                cl = [cl substringWithRange:NSMakeRange(1, cl.length-2)];
                UIColor *c = [self colorWithHexString:cl];
                [prodic setValue:c forKey:b.firstObject];

            } else {
                if ([obj containsString:@"=="]) {
                    [prodic setValue:@"=" forKey:b.firstObject];
                } else {
                    [prodic setValue:b.lastObject forKey:b.firstObject];
                }

            }
        }
    }];

    return @[varName,className,prodic];
}


/// 创建OC中的对象
/// @param className 类名
/// @param dic 属性字典
- (id)ocobjWithCls:(NSString *)className property:(NSDictionary *)dic {
    id ocObj = [[NSClassFromString(className) alloc] init];;

    if (LogOn) {
        NSLog(@"className:%@ : %@",className,dic);
    }
    [dic enumerateKeysAndObjectsUsingBlock:^(NSString *key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSString.class]) {
            obj = [self removeFix:obj];
        }
        if ([key isEqualToString:@"title"]) {
            UIButton *btn = (UIButton *)ocObj;
            [btn setTitle:obj forState:UIControlStateNormal];
        } else if ([key isEqualToString:@"target"]) {
            UIButton *btn = (UIButton *)ocObj;
            [btn addTarget:self action:@selector(btnCommonMethod:) forControlEvents:UIControlEventTouchUpInside];
            [self setProperty:btn key:@"userScript" value:obj];
        } else if ([key isEqualToString:@"cornerRadius"]) {
            UIView *btn = (UIButton *)ocObj;
            btn.layer.cornerRadius = [obj floatValue];
        } else {
            @try {
                [ocObj setValue:obj forKey:key];
            } @catch (NSException *exception) {
                NSLog(@"设置key出错：%@ %@",key,obj);
            } @finally {

            }
        }
    }];
    return ocObj;
}

- (UIWindow *)win {
    AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return app.window;
}

// 颜色转换三：iOS中十六进制的颜色（以#开头）转换为UIColor
- (UIColor *)colorWithHexString: (NSString *)color
{
    NSString *cString = [[color stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

    // String should be 6 or 8 characters
    if ([cString length] < 6) {
        return [UIColor clearColor];
    }

    // 判断前缀并剪切掉
    if ([cString hasPrefix:@"0X"])
        cString = [cString substringFromIndex:2];
    if ([cString hasPrefix:@"#"])
        cString = [cString substringFromIndex:1];
    if ([cString length] != 6)
        return [UIColor clearColor];

    // 从六位数值中找到RGB对应的位数并转换
    NSRange range;
    range.location = 0;
    range.length = 2;

    //R、G、B
    NSString *rString = [cString substringWithRange:range];

    range.location = 2;
    NSString *gString = [cString substringWithRange:range];

    range.location = 4;
    NSString *bString = [cString substringWithRange:range];

    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];

    return [UIColor colorWithRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:1.0f];
}

- (id)executeFunc:(id)obj func:(NSString *)funcs args:(NSMutableArray *)arg {
    if (!obj || !funcs) {
        return nil;
    }

    if (!arg) {
        return [obj performSelector:NSSelectorFromString(funcs)];
    }
    if (arg.count==1) {
        // 若为数字参数
        id first = arg[0];
        if ([first isKindOfClass:NSString.class]) {
            if ([arg[0] hasPrefix:@"@INT:"]) {
                NSInteger val = [[arg[0] stringByReplacingOccurrencesOfString:@"@INT:" withString:@""] integerValue];
                id res = intfunc1(obj,NSSelectorFromString(funcs),val);
                return res;
            } else if ([arg[0] hasPrefix:@"@FLOAT:"]) {
                float val = [[arg[0] stringByReplacingOccurrencesOfString:@"@FLOAT:" withString:@""] floatValue];
                id res = floatfunc1(obj,NSSelectorFromString(funcs),val);
                return res;
            } else {
                id res = idfunc1(obj,NSSelectorFromString(funcs),first);
                return res;
            }
        } else {
//            id res = idfunc1(obj,NSSelectorFromString(funcs),first);
            id res = [obj performSelector:NSSelectorFromString(funcs) withObject:first];
            return res;
        }

    }
    if (arg.count == 3) {
        NSMutableArray *types = @[@0,@0,@0].mutableCopy;

        [arg enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:NSString.class]) {
                if ([obj rangeOfString:@"^\\d+$" options:NSRegularExpressionSearch].location != NSNotFound) {
                    // 某一位是数字
                    types[idx] = @1;
                }
            }
        }];
        NSString *typesstr = [types componentsJoinedByString:@""];
        if ([typesstr isEqualToString:@"000"]) {
            // 全id参数
        } else if ([typesstr isEqualToString:@"100"]) {

        } else if ([typesstr isEqualToString:@"001"]) {
            // 第3位是int参数
        } else if ([typesstr isEqualToString:@"010"]) {
            // 第2位是int参数
            id res = idintidfunc1(obj,NSSelectorFromString(funcs),arg[0], [arg[1] integerValue], [arg[2] isEqualToString:@"nil"]?nil:arg[2]);
            return res;
        } else if ([typesstr isEqualToString:@"010"]) {
            // 第2位是int参数
            id res = idintidfunc1(obj,NSSelectorFromString(funcs),arg[0], [arg[1] integerValue], [arg[2] isEqualToString:@"nil"]?nil:arg[2]);
            return res;
        }

    }
    id res = [obj performSelector:NSSelectorFromString(funcs) withObject:arg];
    return res;
}
@end

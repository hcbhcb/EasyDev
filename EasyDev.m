
#import "EasyDev.h"
#import <UIKit/UIKit.h>
//#include <objc/runtime.h>
#import <objc/message.h>
#import "AppDelegate.h"
#import "Calculator.h"

#define LogOn 0
@interface EasyDev ()

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
   [lines enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
       if (startInd && [obj hasPrefix:@"    "]) {
           endInd += 1;
       } else {
           if (endInd) {
               NSString *def = lines[startInd];
               NSRange r = [def rangeOfString:@"("];
               NSString *name = [def substringWithRange:NSMakeRange(4, r.location-4)];
               NSArray *funs = [lines subarrayWithRange:NSMakeRange(startInd+1, endInd-startInd)];
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
           }
           if ([obj hasPrefix:@"def "]) {
               startInd = idx;
               endInd = startInd;
           } else {
               [restLines addObject:obj];
           }
       }
   }];

   NSString *result = [restLines componentsJoinedByString:@"\n"];
   return result;
}

/// 解析脚本
/// @param src 脚本内容字符串
/// @param arg 调用函数时的参数，字典形式，参数名为key，参数值为value
- (id)loadSrc:(NSString *)src agr:(NSDictionary *)arg {
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
//        if ([self handleShouldReturn:obj]) {
//            // 不需要直接执行的语句
//            return ;
//        }
#warning print need replace too
       if ([obj containsString:@" = "] || [obj containsString:@" > "] || [obj containsString:@" < "]) {
           obj = [self handelReplaceVar:obj arg:arg];
       }
       if ([obj containsString:@" = UI"]) {
           [self handelCreateUI:obj];
       } else if ([obj containsString:@"+"] || [obj containsString:@"-"] || [obj containsString:@"*"] || [obj containsString:@"/"]) {
           [self handelCalculate:obj arg:arg];
       } else if ([obj containsString:@"."] && [obj containsString:@" = "]) {
           [self handleObjProperty:obj arg:arg];
       } else if ([obj containsString:@"print("]) {
           [self handlePrint:obj arg:arg];
       } else if ([obj containsString:@".addSubview("]) {
           [self handleAddView:obj];
       } else if ([obj containsString:@"for x in range("]) {
           NSMutableArray *lastScript = [script subarrayWithRange:NSMakeRange(idx, script.count-idx)].mutableCopy;
           lastScript[0] = obj; // 上面替换过的值需要放进去
           funcJump = [self handleFor:obj script:lastScript arg:arg];
       } else if ([obj containsString:@"if "] && [obj hasSuffix:@":"]) {
           NSMutableArray *lastScript = [script subarrayWithRange:NSMakeRange(idx, script.count-idx)].mutableCopy;
           lastScript[0] = obj; // 上面替换过的值需要放进去
           funcJump = [self handleIf:obj script:lastScript arg:arg];
       } else if ([obj rangeOfString:@"^\\w+\\(\\w+\\)$" options:NSRegularExpressionSearch].location != NSNotFound) {
           [self handelCallFunc:obj];
       } else if ([obj containsString:@" = "]) {
           [self handelSaveVar:obj];
       } else {
           NSLog(@"不支持的语句：%@",obj);
       }
   }];
   return nil;
}

- (void)handelCallFunc:(NSString *) obj  {
   NSRange r = [obj rangeOfString:@"\\w+" options:NSRegularExpressionSearch];
   NSString *name = [obj substringWithRange:r];
   NSString *endArg = [obj substringFromIndex:name.length+1];
   endArg = [endArg substringToIndex:endArg.length-1];

   NSDictionary *f = [self funcBodyWithName:name];
   if (!f) {
       NSLog(@"函数未定义");
   }
   NSString *varName = f[@"args"][0];
   [self loadSrc:f[@"body"] agr:@{varName:endArg}];
}

- (BOOL)handleShouldReturn:(NSString *) obj {
   if ([obj isEqualToString:@"    "] || [obj hasPrefix:@"# "] || [obj hasPrefix:@"    # "] || [obj hasPrefix:@"        # "] || [obj hasPrefix:@"import"] || [obj hasPrefix:@"from "] || obj.length<3) {
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
       first = [self handelReplaceVar:first arg:nil];
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
       NSString *v = [obj substringWithRange:NSMakeRange(r2.location+r2.length, obj.length-r2.location-r2.length-1)];
       if ([v hasPrefix:@"\""] && [v hasSuffix:@"\""]) {
           NSLog(@"%@", [v substringWithRange:NSMakeRange(1, v.length-2)]);
       } else if ([v containsString:@"."]) {
           NSArray *a = [v componentsSeparatedByString:@"."];
           id obj = [self getObjFromAllobj:a.firstObject];
           if (obj) {
               id value = [self getProperty:obj key:a.lastObject];
               NSLog(@"%@",value);
           }
       } else {
           if ([v isEqualToString:@"x"]) {
               //                        NSLog(@"%@",arg?arg[@"i"]:@"");
           } else {
               id varValue = [self getObjFromAllobj:v];
               if (varValue) {
                   NSLog(@"%@",varValue);
               } else {
                   NSLog(@"%@",arg.allValues.firstObject);
               }
           }
       }
   }
}

- (NSString *)removeFix:(NSString *)str {

   if ([str isKindOfClass:NSString.class] && [str hasPrefix:@"\""] && [str hasSuffix:@"\""]) {
       return [str substringWithRange:NSMakeRange(1, str.length-2)];
   }
   return str;
}
- (void)handleObjProperty:(NSString *)obj arg:(NSDictionary *)arg{
   // 对象赋值语句
   NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];

   NSArray *a = [outs.firstObject componentsSeparatedByString:@"."];
   NSString *var = [a.firstObject stringByReplacingOccurrencesOfString:@" " withString:@""];
   id uiObj = [self getObjFromAllobj:var];
   if ([var isEqualToString:@"sender"] && arg && arg[@"sender"]) {
       uiObj = arg[@"sender"];
   }
   if (uiObj) {
       NSString *key = a.lastObject;
       // a.b = c  如果a没有属性，则添加b属性，有则是赋值
       // frame color 单独设置
       id value = outs.lastObject;
       if ([value isKindOfClass:NSString.class]) {
           value = [self removeFix:value];
       }
       if ([key isEqualToString:@"title"]) {
           UIButton *btn = (UIButton *)uiObj;
           [btn setTitle:value forState:UIControlStateNormal];
       } else if ([key isEqualToString:@"frame"] || [key isEqualToString:@"center"] || [key isEqualToString:@"point"]) {
           NSString *frame = outs.lastObject;
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

           @try {
               [uiObj setValue:value forKey:key];
           } @catch (NSException *exception) {
               NSLog(@"设置属性出错：%@  %@",value,key);
           } @finally {
           }

       } else if ([key containsString:@"Color"]) {
           NSString *cl = (NSString *)outs.lastObject;
           cl = [cl substringWithRange:NSMakeRange(1, cl.length-2)];
           UIColor *c = [self colorWithHexString:cl];
           value = c;
           [uiObj setValue:value forKey:key];
       } else {
           NSString *setfunc = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString,[key substringFromIndex:1]];
           if ([uiObj respondsToSelector:NSSelectorFromString(setfunc)]) {
               [uiObj setValue:value forKey:key];
           } else {
               [self setProperty:uiObj key:key value:outs.lastObject];
           }
       }

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
   int indx = [self haveVar:varname];
   if (indx>=0) {
       [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
   } else {
       [self.allObjs addObject:newDic];
   }

}

- (void)handelCreateUI:(NSString *)obj {
   NSArray *a = [self splitUICreator:obj];
   if (a.count == 3) {
       id uiObj = [self viewWithCls:a[1] property:a[2]];
       if ([uiObj isKindOfClass:UIViewController.class]) {
           UIViewController *vc = (UIViewController *)uiObj;
           self.win.rootViewController = uiObj;
           vc.view.backgroundColor = [UIColor lightGrayColor];
       }
       NSString *varname = [a[0] stringByReplacingOccurrencesOfString:@"    " withString:@""];
       [self.allObjs addObject:@{varname:uiObj}];
   }
}

- (NSString *)handelReplaceVar:(NSString *)obj  arg:(NSDictionary *)arg{
   if ([obj containsString:@"print("]) {
       return obj;
   }
   NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];
   __block NSString *lst = outs.lastObject.copy;
   // 原始字符串，不用替换
   if ([lst hasPrefix:@"\""] && [lst hasSuffix:@"\""]) {
       return obj;
   }
   // 对象属性值替换
   if ([lst containsString:@"."]) {
       NSArray *objPro = [outs.lastObject componentsSeparatedByString:@"."];
       __block id uiObj = [self getObjFromAllobj:objPro.firstObject];

       if (!uiObj && arg && arg[@"sender"]) {
           uiObj = arg[@"sender"];
       }
       [objPro enumerateObjectsUsingBlock:^(NSString *tmpKey, NSUInteger idx, BOOL * _Nonnull stop) {
           if (idx) {
               uiObj = [uiObj valueForKey:tmpKey];
           }
       }];
       obj = [NSString stringWithFormat:@"%@ = %@",outs.firstObject, uiObj];
       return obj;
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
       if ([lst containsString:tmpKey]) {
           lst = [lst stringByReplacingOccurrencesOfString:tmpKey withString:values[idx]];
       }
   }];
   if (outs.count==1) {
       return lst;
   }
   obj = [NSString stringWithFormat:@"%@ = %@",outs.firstObject, lst];
   return obj;
}

- (void)handleAddView:(NSString *)obj {
   // 视图添加
   NSArray *a = [[obj substringToIndex:[obj rangeOfString:@".addSubview("].location] componentsSeparatedByString:@"."];
   __block id endobj = nil;
   [a enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
       if (idx == 0) {
           endobj = [self getObjFromAllobj:obj];

       } else {
           endobj = [endobj valueForKey:obj];
       }
   }];
   NSRange r1 = [obj rangeOfString:@"("];
   NSString *objName = [obj substringWithRange:NSMakeRange(r1.location+1,obj.length-r1.location-1-1)];
   UIView *view = [self getObjFromAllobj:objName];
   if (view) {
       UIView *v = endobj;
       [v addSubview:view];
   }
}

- (void)handelSaveVar:(NSString *)obj {
   // 存储变量
   NSArray <NSString *>*outs = [obj componentsSeparatedByString:@" = "];
   NSString *varname = [outs.firstObject stringByReplacingOccurrencesOfString:@"    " withString:@""];
   // 若其中已存在该变量，直接替换
   NSDictionary *newDic = @{varname:outs.lastObject};
   int indx = [self haveVar:varname];
   if (indx>=0) {
       [self.allObjs replaceObjectAtIndex:indx withObject:newDic];
   } else {
       [self.allObjs addObject:newDic];
   }
}

#pragma mark - 通用方法
- (int)haveVar:(NSString *)name {
   __block int indx = -1;
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
       return [obj performSelector:slc];
   }
   return objc_getAssociatedObject(obj, (__bridge const void * _Nonnull)(key));
}

/// 返回[变量名，类名，属性字典]
/// @param src 文本，不能换行
- (NSArray *)splitUICreator:(NSString *)src {
   NSArray *a = [src componentsSeparatedByString:@" = "];
   NSString *varName = a.firstObject;
   NSString *lst = (NSString *)a.lastObject;
   lst = [lst substringToIndex:lst.length-1];  // 去除后括号
   NSString *className = [lst substringToIndex:[lst rangeOfString:@"("].location];
   NSArray *pro = [[lst substringFromIndex:[lst rangeOfString:@"("].location+1] componentsSeparatedByString:@", "];
   __block NSMutableDictionary *prodic = [NSMutableDictionary dictionary];
   [pro enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {

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
               [prodic setValue:b.lastObject forKey:b.firstObject];

           }
       }
   }];
   return @[varName,className,prodic];
}


/// 创建UIKit中的对象
/// @param className 类名
/// @param dic 属性字典
- (UIView *)viewWithCls:(NSString *)className property:(NSDictionary *)dic {
   UIView *view = [[NSClassFromString(className) alloc] init];
   if (LogOn) {
       NSLog(@"className:%@ : %@",className,dic);
   }
   [dic enumerateKeysAndObjectsUsingBlock:^(NSString *key, id  _Nonnull obj, BOOL * _Nonnull stop) {
       if ([obj isKindOfClass:NSString.class]) {
           obj = [self removeFix:obj];
       }
       if ([key isEqualToString:@"title"]) {
           UIButton *btn = (UIButton *)view;
           [btn setTitle:obj forState:UIControlStateNormal];
       } else if ([key isEqualToString:@"target"]) {
           UIButton *btn = (UIButton *)view;
           [btn addTarget:self action:@selector(btnCommonMethod:) forControlEvents:UIControlEventTouchUpInside];
           [self setProperty:btn key:@"userScript" value:obj];
       } else if ([key isEqualToString:@"cornerRadius"]) {
           view.layer.cornerRadius = [obj floatValue];
       } else {
           @try {
               [view setValue:obj forKey:key];
           } @catch (NSException *exception) {
                NSLog(@"设置key出错：%@ %@",key,obj);
           } @finally {

           }
       }
   }];

   return view;
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

@end
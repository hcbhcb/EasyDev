# 此为借助python语法开发iOS代码，后经中间件进行解析，转为iOS原生UI和逻辑的组件。
# 当前对词法解析能力有限，暂时只支持简单写法且空格格式必须标准，不支持数组字典嵌套取值、if/for循环嵌套、函数定义嵌套
# 只支持单层for循环：for x in range(2),for只能使用此格式，
# UI类创建，其中的属性和值必须形如:(key=value, key2=value2),key为该UI已有属性 等号前后不能有空格，逗号后面必须有空格
# 普通赋值语句等号前后必须有一个空格,函数定义前后之间必须有一行空行
# 暂不支持Python类定义、Python自有库、Python自有函数、OC类定义
# 部分OC类的方法调用无法成功，正在调试适用于所有函数调用的方法。
# 已支持的范围：OC类创建，方法调用，属性赋值取值，python print函数（不支持format），数组字典定义取值赋值，单层if/elif/else, 单层for循环，四则混合运算

# 主控制器
vc = UIViewController()

# 标题label
label = UILabel(frame=(0,20,375,40), text="Calculator", textColor="#FFFFFF", textAlignment=1)
vc.view.addSubview(label)

# 输入框
field = UITextField(frame=(0,100,375,50), text="0", backgroundColor="#FF2233", textColor="#FFFFFF", textAlignment=2)
vc.view.addSubview(field)

# 按钮背景视图
aview = UIView(frame=(0,200,375,400))
vc.view.addSubview(aview)

btnTitleArr = ["C", "DEL", "÷", "x", "7", "8", "9", "-", "4", "5", "6", "+", "1", "2", "3", "="]
btnw = 80
index = 0
y = 10
# 创建一行4个按钮
def createUI():
    for x in range(4):
        btnx = x * 90 + 10
        btn = UIButton(frame=(btnx,y,btnw,btnw), title=btnTitleArr[index], backgroundColor="#11CC66", cornerRadius=40, target=clicked)
        aview.addSubview(btn)
        index = index + 1
# 创建4行按钮
for x in range(4):
    createUI()
    y = y + 90
print("def functoin")
# 按钮点击响应方法
def clicked(sender):
    field.text = sender.currentTitle
    
print("load done")

# MISO CHANGELOG

## 0.3.0 (2014-04-11)

重写实现方式——去除「Built-in」和「Constructor」的概念，通过调用函数的方式来构造对象，而非新建实例。

每个「核心」方法都添加了 `__miso__` 属性，供之后扩展时识别用。

## 0.2.0 (2014-04-11)

第一次版本发布。主要内容包括：

1.  Built-in Object
2.  Constructor
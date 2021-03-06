"use strict"

# Config of library
META =
  name: "Miso"
  version: "0.4.1"

# Save a reference to some core methods.
toString = {}.toString

# default settings
settings =
  validator: ->
    return true

# storage for internal usage
storage =
  # map of object types
  types: {}

###
# Fill the map object-types, and add methods to detect object-type.
# 
# @private
# @method   objectTypes
# @return   {Object}
###
objectTypes = ->
  types = "Boolean Number String Function Array Date RegExp Object".split " "

  for type in types
    do ( type ) ->
      # populate the storage.types map
      storage.types["[object #{type}]"] = lc = type.toLowerCase()

      if type is "Number"
        handler = ( target ) ->
          return if isNaN(target) then false else @type(target) is lc
      else
        handler = ( target ) ->
          return @type(target) is lc

      # add methods such as isNumber/isBoolean/...
      storage.methods["is#{type}"] = handler

  return storage.types

###
# 判断某个对象是否有自己的指定属性
#
# !!! 不能用 object.hasOwnProperty(prop) 这种方式，低版本 IE 不支持。
#
# @private
# @method   hasOwnProp
# @param    obj {Object}    Target object
# @param    prop {String}   Property to be tested
# @return   {Boolean}
###
hasOwnProp = ( obj, prop ) ->
  return if not obj? then false else Object::hasOwnProperty.call obj, prop

###
# 为指定 object 或 function 定义属性
#
# @private
# @method   defineProp
# @param    obj {Object}
# @param    prop {String}
# @param    value {Mixed}
# @param    [writable] {Boolean}
# @return   {Boolean}
###
defineProp = ( obj, prop, value, writable = false ) ->
  # throw an exception in IE9-
  try
    Object.defineProperty obj, prop,
      __proto__: null
      writable: writable
      value: value
  catch error
    obj[prop] = value

  return true

###
# 批量添加 method
#
# @private
# @method  batch
# @param   handlers {Object}   data of a method
# @param   data {Object}       data of a module
# @param   host {Object}       the host of methods to be added
# @return
###
batch = ( handlers, data, host ) ->
  methods = storage.methods

  if methods.isArray(data) or (methods.isPlainObject(data) and not methods.isArray(data.handlers))
    methods.each data, ( d ) ->
      batch d?.handlers, d, host
  else if methods.isPlainObject(data) and methods.isArray(data.handlers)
    methods.each handlers, ( info ) ->
      attach info, data, host

  return host

###
# 构造 method
#
# @private
# @method  attach
# @param   set {Object}        data of a method
# @param   data {Object}       data of a module
# @param   host {Object}       the host of methods to be added
# @return
###
attach = ( set, data, host ) ->
  name = set.name
  methods = storage.methods

  if set.expose isnt false and not methods.isFunction host[name]
    handler = set.handler
    value = if hasOwnProp(set, "value") then set.value else data.value
    validators = [
        set.validator
        data.validator
        settings.validator
        ->
          return true
      ]

    break for validator in validators when methods.isFunction validator

    method = ->
      return if methods.isFunction(handler) and validator.apply(host, arguments) is true then handler.apply(host, arguments) else value;
    
    host[name] = method

  return host

storage.methods =
  # ====================
  # Core methods
  # ====================

  ###
  # 扩充对象
  # 
  # @method   extend
  # @param    data {Plain Object/Array}
  # @param    [host] {Object}
  # @return   {Object}
  ###
  extend: ( data, host ) ->
    return @ data, host ? @

  ###
  # 扩展指定对象
  # 
  # @method  mixin
  # @param   unspecified {Mixed}
  # @return  {Object}
  ###
  mixin: ->
    args = arguments
    length = args.length
    target = args[0] or {}
    i = 1
    deep = false

    # Handle a deep copy situation
    if @type(target) is "boolean"
      deep = target
      target = args[1] or {}
      # skip the boolean and the target
      i = 2

    # Handle case when target is a string or something (possible in deep copy)
    target = {} if typeof target isnt "object" and not @isFunction target

    # 只传一个参数时，扩展自身
    if length is 1
      target = @
      i--

    while i < length
      opts = args[i]

      # Only deal with non-null/undefined values
      if opts?
        for name, copy of opts
          src = target[name]

          # 阻止无限循环
          if copy is target
            continue

          # Recurse if we're merging plain objects or arrays
          if deep and copy and (@isPlainObject(copy) or (copyIsArray = @isArray(copy)))
            if copyIsArray
              copyIsArray = false
              clone = if src and @isArray(src) then src else []
            else
              clone = if src and @isPlainObject(src) then src else {}

            # Never move original objects, clone them
            target[name] = @mixin deep, clone, copy
          # Don't bring in undefined values
          else if copy isnt undefined
            target[name] = copy

      i++

    return target

  ###
  # 遍历
  # 
  # @method  each
  # @param   object {Object/Array/Array-Like/Function/String}
  # @param   callback {Function}
  # @return  {Mixed}
  ###
  each: ( object, callback ) ->
    if @isArray(object) or @isArrayLike(object) or @isString(object)
      index = 0
      while index < object.length
        ele = if @isString(object) then object.charAt(index) else object[index]
        break if callback.apply(ele, [ele, index++, object]) is false
    else if @isObject(object) or @isFunction(object)
      break for name, value of object when callback.apply(value, [value, name, object]) is false

    return object

  ###
  # 获取对象类型
  # 
  # @method  type
  # @param   object {Mixed}
  # @return  {String}
  ###
  type: ( object ) ->
    if arguments.length is 0
      result = null
    else
      result = if not object? then String(object) else storage.types[toString.call(object)] || "object"
      
    return result

  ###
  # 切割 Array-Like Object 片段
  #
  # @method   slice
  # @param    target {Array-Like}
  # @param    begin {Integer}
  # @param    end {Integer}
  # @return
  ###
  slice: ( target, begin, end ) ->
    if not target?
      result = []
    else
      end = Number end
      args = [(Number(begin) || 0)]

      args.push(end) if arguments.length > 2 and not isNaN(end)

      result = [].slice.apply target, args
      
    return  result

  ###
  # 判断某个对象是否有自己的指定属性
  #
  # @method   hasProp
  # @param    prop {String}   Property to be tested
  # @param    obj {Object}    Target object
  # @return   {Boolean}
  ###
  hasProp: ( prop, obj ) ->
    return hasOwnProp.apply @, [(if arguments.length < 2 then @ else obj), prop]

  ###
  # Returns the namespace specified and creates it if it doesn't exist.
  # Be careful when naming packages.
  # Reserved words may work in some browsers and not others.
  #
  # @method  namespace
  # @param   [host] {Object}      Host object namespace will be added to
  # @param   [ns_str_1] {String}     The first namespace string
  # @param   [ns_str_2] {String}     The second namespace string
  # @param   [ns_str_*] {String}     Numerous namespace string
  # @param   [isGlobal] {Boolean}    Whether set window as the host object
  # @return  {Object}                A reference to the last namespace object created
  ###
  namespace: ( host ) ->
    args = arguments
    ns = {}
    
    # 当 host 不是纯对象时
    # 若最后一个参数是 true 则 host 是 window 对象
    # 否则为 this
    (host = if args[args.length - 1] is true then window else @) if not @isPlainObject host

    @each args, ( arg ) =>
      if @isString(arg) and /^[0-9A-Z_.]+[^_.]?$/i.test(arg)
        obj = host

        @each arg.split("."), ( part, idx, parts ) =>
          if not obj?
            return false

          if not @hasProp part, obj
            obj[part] = if idx is parts.length - 1 then null else {}

          obj = obj[part]

          return true

        ns = obj

      return true

    return ns

  # ====================
  # Extension of detecting type of variables
  # ====================

  ###
  # 判断是否为 window 对象
  # 
  # @method  isWindow
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isWindow: ( object ) ->
    return object and @isObject(object) and "setInterval" of object

  ###
  # 判断是否为 DOM 对象
  # 
  # @method  isElement
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isElement: ( object ) ->
    return object and @isObject(object) and object.nodeType is 1

  ###
  # 判断是否为数字类型（字符串）
  # 
  # @method  isNumeric
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isNumeric: ( object ) ->
    return not @isArray(object) and not isNaN(parseFloat(object)) and isFinite(object)

  ###
  # Determine whether a number is an integer.
  #
  # @method  isInteger
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isInteger: ( object ) ->
    return @isNumeric(object) and /^-?[1-9]\d*$/.test(object)

  ###
  # 判断对象是否为纯粹的对象（由 {} 或 new Object 创建）
  # 
  # @method  isPlainObject
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isPlainObject: ( object ) ->
    # This is a copy of jQuery 1.7.1.
    
    # Must be an Object.
    # Because of IE, we also have to check the presence of the constructor property.
    # Make sure that DOM nodes and window objects don't pass through, as well
    if not object or not @isObject(object) or object.nodeType or @isWindow(object)
      return false

    try
      # Not own constructor property must be Object
      if object.constructor and not @hasProp("constructor", object) and not @hasProp("isPrototypeOf", object.constructor.prototype)
        return false
    catch error
        # IE8,9 will throw exceptions on certain host objects
        return false

    key for key of object

    return key is undefined or @hasProp(key, object)

  ###
  # Determin whether a variable is considered to be empty.
  #
  # A variable is considered empty if its value is or like:
  #  - null
  #  - undefined
  #  - ""
  #  - []
  #  - {}
  #
  # @method  isEmpty
  # @param   object {Mixed}
  # @return  {Boolean}
  #
  # refer: http://www.php.net/manual/en/function.empty.php
  ###
  isEmpty: ( object ) ->
    result = false

    # null, undefined and ""
    if not object? or object is ""
      result = true
    # array and array-like object
    else if (@isArray(object) or @isArrayLike(object)) and object.length is 0
      result = true
    # plain object
    else if @isObject(object)
      result = true

      for name of object
        result = false
        break

    return result

  ###
  # 是否为类数组对象
  #
  # 类数组对象（Array-Like Object）是指具备以下特征的对象：
  # -
  # 1. 不是数组（Array）
  # 2. 有自动增长的 length 属性
  # 3. 以从 0 开始的数字做属性名
  #
  # @method  isArrayLike
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isArrayLike: ( object ) ->
    result = false

    if @isObject(object) and not @isWindow object
      length = object.length

      result = true if object.nodeType is 1 and length or
        not @isArray(object) and
        not @isFunction(object) and
        (length is 0 or @isNumber(length) and length > 0 and (length - 1) of object)

    return result

  # ====================
  # Library config
  # ====================

  ###
  # 更改 META.name
  # 
  # @method   mask
  # @param    guise {String}    New name for library
  # @return   {Boolean}
  ###
  mask: ( guise ) ->
    if @isString guise
      if @hasProp guise, window
        console.error "'#{guise}' has existed as a property of Window object." if window.console
      else
        lib_name = @__meta__.name
        window[guise] = window[lib_name]

        # IE9- 不能用 delete 关键字删除 window 的属性
        try
          result = delete window[lib_name]
        catch error
          window[lib_name] = undefined
          result = true
        
        @__meta__.name = guise
    else
      result = false

    return result

  ###
  # 别名
  # 
  # @method  alias
  # @param   name {String}
  # @return
  ###
  alias: ( name ) ->
    # 通过 _alias 判断是否已经设置过别名
    # 设置别名时要将原来的别名释放
    # 如果设置别名了，是否将原名所占的空间清除？（需要征求别人意见）

    window[name] = @ if @isString(name) and window[name] is undefined

    return window[String(name)]

class Environment
  nav = navigator
  ua = nav.userAgent.toLowerCase()

  suffix =
    windows:
      "5.1": "XP"
      "5.2": "XP x64 Edition"
      "6.0": "Vista"
      "6.1": "7"
      "6.2": "8"
      "6.3": "8.1"

  platformName = ->
    name = /^[\w.\/]+ \(([^;]+?)[;)]/.exec(ua)[1].split(" ").shift()
    return if name is "compatible" then "windows" else name

  platformVersion = ->
    return (/windows nt ([\w.]+)/.exec(ua) or
            /os ([\w]+) like mac/.exec(ua) or
            /mac os(?: [a-z]*)? ([\w.]+)/.exec(ua) or
            [])[1]?.replace /_/g, "."

  detectPlatform = ->
    platform =
      touchable: false
      version: platformVersion()
    
    platform[platformName()] = true

    if platform.windows
      platform.version = suffix.windows[platform.version]
      platform.touchable = /trident[ \/][\w.]+; touch/.test ua
    else if platform.ipod or platform.iphone or platform.ipad
      platform.touchable = platform.ios = true

    return platform

  # jQuery 1.9.x 以下版本中 jQuery.browser 的实现方式
  # IE 只能检测 IE11 以下
  jQueryBrowser = ->
    browser = {}
    match = /(chrome)[ \/]([\w.]+)/.exec(ua) or
            /(webkit)[ \/]([\w.]+)/.exec(ua) or
            /(opera)(?:.*version|)[ \/]([\w.]+)/.exec(ua) or
            /(msie) ([\w.]+)/.exec(ua) or
            ua.indexOf("compatible") < 0 and /(mozilla)(?:.*? rv:([\w.]+)|)/.exec(ua) or
            []
    result =
      browser: match[1] or ""
      version: match[2] or "0"

    if result.browser
      browser[result.browser] = true
      browser.version = result.version

    if browser.chrome
      browser.webkit = true
    else if browser.webkit
      browser.safari = true

    return browser

  detectBrowser = ->
    # IE11 及以上
    match = /trident.*? rv:([\w.]+)/.exec(ua)

    if match
      browser =
        msie: true
        version: match[1]
    else
      browser = jQueryBrowser()

      if browser.mozilla
        browser.firefox = true
        match = /firefox[ \/]([\w.]+)/.exec(ua)
        browser.version = match[1] if match

    browser.language = nav.language or nav.browserLanguage

    return browser
     
  constructor: ->
    @platform = detectPlatform()
    @browser = detectBrowser()

objectTypes()

LIB = ( data, host ) ->
  return batch data?.handlers, data, host ? {}

storage.methods.each storage.methods, ( handler, name )->
  # defineProp handler, "__#{META.name.toLowerCase()}__", true

  LIB[name] = handler

  return

LIB.mixin new Environment

defineProp LIB, "__meta__", META, true

window[META.name] = LIB

storage.methods =
  # ====================
  # Core methods
  # ====================

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
    target = args[0] ? {}
    i = 1

    # 只传一个参数时，扩展自身
    if length is 1
      target = this
      i--

    while i < length
      opts = args[i]

      if typeof opts is "object"
        for name, copy of opts
          # 阻止无限循环
          if copy is target
            continue

          if copy isnt undefined
            target[name] = copy

      i++

    return target

  ###
  # 遍历
  # 
  # @method  each
  # @param   object {Object/Array/Function}
  # @param   callback {Function}
  # @return  {Mixed}
  ###
  each: ( object, callback ) ->
    type = @type object

    if type in ["object", "function"]
      break for name, value of object when callback.apply(value, [value, name, object]) is false
    else if type in ["array", "string"]
      index = 0
      
      while index < object.length
        ele = if type is "array" then object[index] else object.charAt index

        if callback.apply(object[index], [ele, index++, object]) is false
          break

    return object;

  ###
  # 获取对象类型
  # 
  # @method  type
  # @param   object {Mixed}
  # @return  {String}
  ###
  type: ( object ) ->
    return if not object? then String(object) else storage.types[toString.call(object)] || "object"

  ###
  # 切割 Array-Like Object 片段
  #
  # @method   slice
  # @param    args {Array-Like}
  # @param    index {Integer}
  # @return
  ###
  slice: ( args, index ) ->
    return if not args? then [] else [].slice.call args, (Number(index) || 0)

  ###
  # 判断某个对象是否有自己的指定属性
  #
  # @method   hasProp
  # @return   {Boolean}
  ###
  hasProp: ->
    return hasOwnProp.apply this, @slice arguments

  # ====================
  # Extension of detecting type of variables
  # ====================

  ###
  # 判断是否为 window 对象
  # 
  # @method  isWindow
  # @param   object {Mixed}
  # @return  {String}
  ###
  isWindow: ( object ) ->
    return object and @isObject(object) and "setInterval" of object

  ###
  # 判断是否为数字类型（字符串）
  # 
  # @method  isNumeric
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isNumeric: ( object ) ->
    return not isNaN(parseFloat(object)) and isFinite(object)

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
      if object.constructor and not @hasProp(object, "constructor") and not @hasProp(object.constructor.prototype, "isPrototypeOf")
        return false
    catch error
        # IE8,9 will throw exceptions on certain host objects
        return false

    key for key of object

    return key is undefined or @hasProp(object, key)

  ###
  # Determin whether a variable is considered to be empty.
  #
  # A variable is considered empty if its value is or like:
  #  - null
  #  - undefined
  #  - false
  #  - ""
  #  - []
  #  - {}
  #  - 0
  #  - 0.0
  #  - "0"
  #  - "0.0"
  #
  # @method  isEmpty
  # @param   object {Mixed}
  # @return  {Boolean}
  #
  # refer: http://www.php.net/manual/en/function.empty.php
  ###
  isEmpty: ( object ) ->
    result = false

    if not object? or not object
      result = true
    else if @isObject(object)
      result = true

      for name of object
        result = false
        break

    return result

  ###
  # 是否为类数组对象
  #
  # @method  isArrayLike
  # @param   object {Mixed}
  # @return  {Boolean}
  ###
  isArrayLike: ( object ) ->
    result = false

    if @isObject(object) and object isnt null
      if not @isWindow object
        type = @type object
        length = object.length

        result = true if object.nodeType is 1 and length or
          @isArray(type) or
          not @isFunction(type) and
          (length is 0 or @isNumber(length) and length > 0 and (length - 1) of object)

    return result

# Fill the map object-types, and add methods to detect object-type.
storage.methods.each "Boolean Number String Function Array Date RegExp Object".split(" "), ( name ) ->
  # populate the storage.types map
  storage.types["[object #{name}]"] = lc = name.toLowerCase()

  # add methods such as isNumber/isBoolean/...
  storage.methods["is#{name}"] = ( target ) ->
    return @type(target) is lc

_H = ( data, host ) ->
  return batch data?.handlers, data, host ? {}

storage.methods.each storage.methods, ( handler, name )->
  defineProp handler
  _H[name] = handler
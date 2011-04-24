module(..., package.seeall)


RootClass={
    __classname="RootClass",
}
RootClass.__index=RootClass

-- class method
function RootClass.extend(class, superclass)
    local mt=getmetatable(class)
    mt.__index=superclass
    if rawget(class, '__tostring')==RootClass.__tostring then
        class['__tostring']=function(...)
            return superclass.__tostring(...)
        end
    end
    if not rawget(class, '__eq') then
        class['__eq']=function(...)
            return superclass.__eq(...)
        end
    end
end

function RootClass.super(class)
    return getmetatable(class).__index
end

-- instance method
function RootClass:__init()
end

function RootClass:__tostring()
    return string.format("<%s>", self.__classname)
end

function RootClass:is(class)
    local current=getmetatable(self)
    while true do
        if current==class then
            return true
        end
        current=current:super()
        assert(current)
        if current==RootClass then
            break
        end
    end
end

------------------------------------------------------------------------------
local function no_wrap_constructor(class, ...)
    -- new instance
    local instance={}
    setmetatable(instance, class)
    -- constructor
    instance:__init(...)

    return instance
end

function define_class(classname)
    local class={}
    class.__classname=classname
    class.__index=class
    class.__tostring=RootClass.__tostring
    local mt={
        __index=RootClass,
        __call=no_wrap_constructor,
    }
    setmetatable(class, mt)
    return class
end


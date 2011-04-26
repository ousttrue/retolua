module(..., package.seeall)

classVariable = define_class('Variable')
classVariable:extend(classFeature)

classArgument = define_class('Argument')
classArgument:extend(classVariable)

local function get_property_methods(ptype, name)

    if ptype == "default" then -- get_name, set_name
        return "get_"..name, "set_"..name
    end

    if ptype == "qt" then -- name, setName
        return name, "set"..string.upper(string.sub(name, 1, 1))..string.sub(name, 2, -1)
    end

    if ptype == "overload" then -- name, name
        return name,name
    end

    return nil
end

function classVariable:__init(context, name, t)
    classVariable:super().__init(self, context, name)
    -- mod
    self.mod = t.mod
    assert(self.mod, 'no mod')
    if string.find(self.mod, "tolua_property%s") or 
        string.find(self.mod, "tolua_property$") then
        self.mod = string.gsub(self.mod, "tolua_property", 
        "tolua_property__"..context:get_property_type())
    end

    -- ctype
    self.ctype = t.ctype
    assert(self.ctype, 'no ctype')
    if self.ctype == '_cstring' then 
        self.ctype = 'char*'
    elseif self.ctype == '_lstate' then 
        self.ctype = 'lua_State*'
    end
    -- ptr
    self.ptr = t.ptr
    assert(self.ptr, 'no ptr')
    -- def
    self.def = t.def or ''
    -- ret
    self.ret = t.ret or ''
    -- dim
    local b,e,d=self.name:find("%[(.-)%]$")
    if b then
        self.name=self.name:sub(1, b-1)
        self.dim=d
    else
        self.dim=''
    end

    -- adjust ctype of string
    if self.ctype == 'char' and self.dim ~= '' then
        -- char[]
        self.ctype = 'char*'
    end

    -- return ctype
    local lua_type = context:isbasic(self.ctype)
    if lua_type and self.ptr~='' then
        self.ret = self.ptr
        self.ptr = ''
    end

    -- check if there is array to be returned
    if self.dim~='' and self.ret~='' then
        error('#invalid parameter: cannot return an array of values')
    end
end

function classVariable:__eq(rhs)
    return
    self.name==rhs.name and
    self.mod==rhs.mod and
    self.ctype==rhs.ctype and
    self.ptr==rhs.ptr and
    self.dim==rhs.dim and
    self.ret==rhs.ret and
    self.def==rhs.def
end

function classVariable:__tostring()
    local l={}
    if self.mod~='' then
        table.insert(l, self.mod)
    end
    local typeptr=self.ctype..
    (self.ptr=='' and '' or self.ptr)
    if typeptr~='' then
        table.insert(l, typeptr)
    end
    if self.name~='' then
        table.insert(l, self.name)
    end
    return table.concat(l, ' ')
end

function classVariable:build_enter(context)
    assert(self.parent, "no parent: "..tostring(self))
    self.ctype=context:findtype(self.ctype, self.namespace) or self.ctype
    self.ctype=context:resolve_template_types(self.ctype)
    if not context:get_enum(self.ctype) then
        local orig=self.ctype
        self.mod, self.ctype = context:apply_typedef(self.mod, self.ctype)
    end

    if self.mod ~= 'const' and
        self.dim and self.dim ~= '' and
        not context:isbasic(self.ctype) and self.ptr == '' then
        -- check if array of values are returned to Lua
        local ctype = self.ctype:gsub("%s*const%s+","")
        context:push_collection(context:findtype(ctype) or ctype)
    end

    context:add_globaltype(self.ctype)
end

function classVariable:is_readonly()
    return self.ctype:find('const') or self.mod:find('tolua_readonly') or self.mod:find('tolua_inherits')
end

function classVariable:print_enter(context)
    print(context:indent().."Variable{")
    print(context:indent().." mod  = '"..self.mod.."',")
    print(context:indent().." ctype = '"..self.ctype.."',")
    print(context:indent().." ptr  = '"..self.ptr.."',")
    print(context:indent().." name = '"..self.name.."',")
    print(context:indent().." dim = '"..self.dim.."',")
    print(context:indent().." def  = '"..self.def.."',")
    print(context:indent().." ret  = '"..self.ret.."',")
    print(context:indent().."}")
end


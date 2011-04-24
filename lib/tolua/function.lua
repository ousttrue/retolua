module(..., package.seeall)

classFunction = define_class('Function')
classFunction:extend(classFeature)

function classFunction:__init(context, name, mod, ctype, ptr, const, kind)
    assert(context:is(ParseContext))
    local parent=context[#context]
    classFunction:super().__init(self, parent, name)
    -- mod
    self.mod=mod
    assert(self.mod, 'no mod')
    if self.mod:find('static') then
        self.static= 'static'
        self.mod = self.mod:gsub('static%s+', '')
    end
    if self.mod:find("tolua_owned") then
        self.owned = true
        self.mod=self.mod:gsub("tolua_owned%s+", "")
    end
    if self.mod:find("tolua_outside") then
        self.out = true
        self.mod=self.mod:gsub("tolua_outside%s+", "")
    end
    -- ptr
    self.ptr=ptr
    assert(self.ptr, 'no ptr')
    -- ctype
    self.ctype=ctype
    assert(self.ctype, 'no ctype')
    local lua_type = context:isbasic(self.ctype)
    if lua_type=='number' and self.ptr:find("%*") then
        self.ptr = ""
        self.ctype = 'void*'
    end
    if self.ctype == '_cstring' then 
        self.ctype = 'char*'
    elseif self.ctype == '_lstate' then 
        self.ctype = 'lua_State*'
    end
    -- const
    self.const=const
    assert(self.const, 'no const')
    if self.const ~= 'const' and self.const ~= '' then
        error("#invalid 'const' specification: '"..self.const.."'")
    end
    if self.mod:find('const') then
        self.ctype = 'const '..self.ctype
        self.mod = self.mod:gsub('const','')
    end
    -- kind
    self.kind=kind or ''
    if self.kind~='' then
        self.name = "operator" .. self.kind
    end
    self.overload=context:overload(self.name)
    -- args
    self.args={}
end

function classFunction:__eq(rhs)
    return
    self.name==rhs.name and
    self.mod==rhs.mod and
    self.ctype==rhs.ctype and
    self.ptr==rhs.ptr and
    self.const==rhs.const and
    self.kind==rhs.kind
end

function classFunction:__tostring()
    local args={}
    table.foreachi(self, function(i, v)
        table.insert(args, tostring(v))
    end)

    local ret=(self.mod=='' and '' or self.mod..' ')..
    self.ctype..self.ptr
    if ret=='' then
        ret='void'
    end

    local constname={}
    if self.const~='' then
        table.insert(constname, self.const)
    end
    table.insert(constname, self.name)
    return string.format("(%s): %s => %s",
    self.namespace or '',
    table.concat(constname, ' '),
    '',
    ret
    )
end

function classFunction:build_enter(context)
    self.ctype = context:resolve_template_types(self.ctype)
    self.ctype = context:findtype(self.ctype) or self.ctype
    if self.ctype ~= '' and 
        not context:isbasic(self.ctype) and 
        self.ptr=='' then
        -- check if it returns an object by value
        local ctype = self.ctype:gsub("%s*const%s+", "")
        context:push_collection(context:findtype(ctype) or ctype)
    end

    table.foreachi(self.args, function(i, v)
        v:build_enter(context)
    end)
end

function classFunction:print_enter(context)
    print(context:indent().."Function{")
    print(context:indent().." mod  = '"..self.mod.."',")
    print(context:indent().." ctype = '"..self.ctype.."',")
    print(context:indent().." ptr  = '"..self.ptr.."',")
    print(context:indent().." name = '"..self.name.."',")
    print(context:indent().." const = '"..self.const.."',")
    print(context:indent().." args = {")
end
function classFunction:print_leave(context)
    print(context:indent().." }")
    print(context:indent().."}")
end


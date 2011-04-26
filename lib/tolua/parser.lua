module(..., package.seeall)

PATTERNS={
    Skip("^%s+", nil, 'skip white space'),
    Skip("^;", nil, 'skip null statement'),
    Skip("^$\n", nil, 'empty verbatim line'),
    Skip("^extern%s+", nil, 'extern keyword'),
    Skip("^virtual%s+", nil, 'virtual keyworkd'),

    Skip(function(s, pos)
        local b, e=s:find("^%s*%w*%s*:[^:]", pos)
        if b then
            -- preserve the [^:]
            return b, e-1
        end
    end, nil, 'label'),

    Matcher("^TOLUA_PROPERTY_TYPE%s*%(+%s*([^%)%s]*)%s*%)+%s*;?",
    function(context, code)
        self=context[#context]
        if not code or code == "" then
            self.property_type="default"
        else
            self.property_type=code
        end
    end, 'default property directive'),

    Matcher("^TOLUA_PROTECTED_DESTRUCTOR%s*;?",
    function(context, code)
        context[#context]:set_protected_destructor(true)
    end, 'protected destructor'),

    Code.matcher,
    Verbatim.matcher,
    matchers.module_matcher,
    matchers.namespace_matcher,
    classDefine.matcher,
    classEnumerate.matcher,
    matchers.operator_matcher,
    matchers.function_matcher,
    matchers.class_matcher,

    Matcher("^typedef%s+(.-)%s*;", 
    function(context, typedef)
        context:typedef(typedef)
    end, 'Typedef'),

    matchers.variable_matcher,
    matchers.array_matcher,
}

ParseContext=define_class('ParseContext')
ParseContext:extend(TraversalContext)

function ParseContext:__init(name, flags)
    ParseContext:super().__init(self)
    self.name=name
    self.flags=flags

    self._global_types={}
    self._usertype={}
    self.global_typedefs = {}
    self._global_enums = {}
    self._collect={}
    self._global_classes = {}
    self.root=classModule(self, name)

    ------------------------------------------------------------------------------
    -- basic types
    ------------------------------------------------------------------------------
    -- Basic C types and their corresponding Lua types
    -- All occurrences of "char*" will be replaced by "_cstring",
    -- and all occurrences of "void*" will be replaced by "_userdata"
    self._basic = {
        ['void'] = '',
        -- number
        ['char'] = 'number',
        ['int'] = 'number',
        ['short'] = 'number',
        ['long'] = 'number',
        ['unsigned'] = 'number',
        ['float'] = 'number',
        ['double'] = 'number',
        -- string
        ['_cstring'] = 'string',
        ['char*'] = 'string',
        -- userdata
        ['_userdata'] = 'userdata',
        ['void*'] = 'userdata',
        -- boolean
        ['bool'] = 'boolean',
        -- lua
        ['lua_Object'] = 'value',
        ['lua_Function'] = 'value',
        ['LUA_VALUE'] = 'value', -- for compatibility with tolua 4.0
        ['lua_State*'] = 'state',
        ['_lstate'] = 'state',
    }

    self._basic_ctype = {
        number = "lua_Number",
        string = "const char*",
        userdata = "void*",
        boolean = "bool",
        value = "int",
        state = "lua_State*",
    }

    -- add cppstring
    if not self.flags.S then
        self._basic['string'] = 'cppstring'
        self._basic['std::string'] = 'cppstring'
        self._basic_ctype['cppstring'] = 'const char*'
    end
end

function ParseContext:create(class, ...)
    local instance=class(self, ...)
    self:append(instance)
    return instance
end

function ParseContext:get_or_create(class, name, ...)
    for i, v in ipairs(self[#self]) do
        if v.name==name then
            return v
        end
    end
    return self:create(class, name, ...)
end

function ParseContext:append(child)
    assert(child:is(classFeature))
    table.insert(self[#self], child)
    child.parent = self[#self]
end

function ParseContext:parse(s, p)
    self:push(p or self.root)
    -- try the parser hook
    local pos=1
    while pos<=#s do
        local matched=false

        for i, v in ipairs(PATTERNS) do
            local m=v:match(s, pos)
            -- process
            if m and m.s then
                _curr_code = s:sub(m.s, m.e) -- for error message
                v:process(self, unpack(m.result))
                pos=m.e+1
                matched=true
                break
            end
        end

        if not matched then
            error("#parse error ["..s:sub(pos, pos+20).."]")
        end
    end
    self:pop()
end

function ParseContext:write(data)
    table.insert(self.text_data, data)
end

function ParseContext:to_s()
    return table.concat(self.text_data)
end

function ParseContext:append_enum(enum)
    self:add_enum(self:getnamespace()..enum.name, enum)
end
function ParseContext:add_enum(k, v)
    self._global_enums[k] = v and v or true
end

function ParseContext:overload(name)
    return self[#self]:overload(name)
end

function ParseContext:getnamespace()
    local namespace=table.mapi(table.filteri(self, 
    function(i, v)
        return v:is(classClass) or v:is(classNamespace)
    end),
    function(i,v)
        return v.name
    end)
    if #namespace==0 then
        return ''
    end
    return table.concat(namespace, '::')..'::'
end

function ParseContext:isbasic(ctype)
    local _, t = self:apply_typedef('', ctype:gsub('const%s*',''))
    local b = self._basic[t]
    if b then
        return b, self._basic_ctype[b]
    end
    return nil
end

function ParseContext:findtype(ctype)
    for i=#self, 1, -1 do
        local v=self[i]
        if v:is(classClass) then
            return v:findtype(ctype)
        end
    end
end

function ParseContext:resolve_template_types(ctype)
    if self:isbasic(ctype) then
        return ctype
    end
    local pre, body, post = ctype:match("^(.-)(%b<>)(.*)$")
    if not pre then
        return ctype
    end

    -- resolve
    local m = body:sub(2, -2):split_c_tokens(",")
    for i=1, #m do
        m[i] = string.gsub(m[i],"%s*([%*&])", "%1")
        if not self:isbasic(m[i]) then
            if not self:get_enum(m[i]) then 
                _, m[i] = self:apply_typedef("", m[i])
            end
            m[i] = self:findtype(m[i]) or m[i]
            m[i] = self:resolve_template_types(m[i])
        end
        m[i]=m[i]:strip()
    end

    -- replace
    local resolved=(pre.."<"..table.concat(m, ",")..">"..post):gsub(">>", "> >")
    return resolved
end

function ParseContext:get_property_type(context)
    for i=#self, 1, -1 do
        local v v=self[i]
        if v.property_type then
            return v.property_type
        end
    end
    return "default"
end

-- check if is a registered ctype: return full ctype or nil
function ParseContext:findtype(ctype)
    -- basic ctype
    if self._basic[ctype] then
        return ctype
    end

    -- complex ctype
    local em = ctype:match("([&*])%s*$") or ''
    ctype = ctype:gsub("%s*([&*])%s*$", "")

    local found=self:match_globaltype(ctype, '')
    if found then
        return found..em
    end

    found=self:match_globaltype(ctype, self:getnamespace())
    if found then
        return found..em
    end

    -- to dofind in base class
end

function ParseContext:add_classtype(ctype)
    self:add_globaltype(ctype)
    self:add_usertype(ctype)
end

function ParseContext:add_typedefs(k, v)
    assert(v, 'no value')
    self:add_globaltype(k)
    self.global_typedefs[k] = v
end

function ParseContext:add_globaltype(ctype, class)
    assert(not class)
    if not self._global_types[ctype] then
        self._global_types[ctype] = true
        table.insert(self._global_types, ctype)
    end
end

function ParseContext:match_globaltype(ctype, namespace)
    for i=#self._global_types, 1, -1 do 
        local v=self._global_types[i]
        if v==ctype then
            return v
        end
        local prefix = v:match('(.*)::'..ctype..'$')
        if prefix and namespace:match('^'..prefix..'::') then
            return v
        end
    end
end

function ParseContext:add_usertype(ft)
    if not self._usertype[ft] then
        self._usertype[ft] = true
        table.insert(self._usertype, ft)
    end
end

function ParseContext:apply_typedef(mod, ctype)
    while self.global_typedefs[ctype] do
        local typedef=self.global_typedefs[ctype]
        mod=mod.." "..typedef.mod
        ctype=typedef.ftype
    end
    return mod:strip(), ctype
end

function ParseContext:get_enum(ctype)
    return self._global_enums[ctype]
end

function ParseContext:add_enumvalue(ctype)
    self._global_enums[ctype]=ctype
end

function ParseContext:push_collection(ctype)
    if not self._collect[ctype] then
        self._collect[ctype]=true
        table.insert(self._collect, ctype)
    end
end

function ParseContext:get_collection(key)
    if self._collect[key] then
        return "tolua_collect_"..clean_template(key)
    end
end

function ParseContext:each_collection(f)
    table.foreachi(self._collect, function(i, v)
        f(v, "tolua_collect_"..clean_template(v))
    end)
end

function ParseContext:get_class(oname)
    return self._global_classes[oname]
end

function ParseContext:find_in_classhierarchy(t, f)
    local current=self._global_classes[t]
    while current do
        local result=f(current)
        if result then
            return result
        end
        current=self._global_classes[current.btype]
    end
end

function ParseContext:search_base(t, funcs)
    return self:find_in_classhierarchy(function(current)
        local func=funcs[current.ctype]
        if  func then
            return func
        end
    end)
end

function ParseContext:build()
    self.root:walk('build', self)
end

function ParseContext:print()
    self.root:walk('print', self)
end

function ParseContext:typedef(s)
    if s:gsub('%b<>', ''):find('[%*&]') then
        tolua_error("#invalid typedef: pointers (and references) are not supported")
    end

    local typedef={}
    local t = s:split_c_tokens("%s+")
    typedef.name = table.remove(t)
    typedef.ctype = self:resolve_template_types(table.remove(t))
    typedef.ftype = self:findtype(typedef.ctype) or typedef.ctype
    typedef.mod = table.concat(t, ' ')

    local fullname=self:getnamespace()..typedef.name
    self:add_typedefs(fullname, typedef)
    if self:get_enum(typedef.ftype) then
        self:add_enum(fullname)
    end
end

function ParseContext:warning (msg)
    if self.flags.q then
        return
    end
    io.stderr:write("\n** tolua warning: "..msg..".\n\n")
end

function parse(name, code, flags)
    local context=ParseContext(name, flags)
    context:parse(preprocess(code))
    context:build()
    return context
end

function tolua_error (s,f)
    if _curr_code then
        print("***curr code for error is "..tostring(_curr_code))
        print(debug.traceback())
    end
    if s:sub(1,1) == '#' then
        print("\n** tolua: "..string.sub(s,2)..".\n\n")
        if _curr_code then
            local _,_,s = string.find(_curr_code,"^%s*(.-\n)") -- extract first line
            if s==nil then s = _curr_code end
            s = string.gsub(s,"_userdata","void*") -- return with 'void*'
            s = string.gsub(s,"_cstring","char*")  -- return with 'char*'
            s = string.gsub(s,"_lstate","lua_State*")  -- return with 'lua_State*'
            print("Code being processed:\n"..s.."\n")
        end
    else
        if not f then f = "(f is nil)" end
        print("\n** tolua internal error: "..f..s..".\n\n")
        return
    end
end

function clean_template(t)
    return string.gsub(t, "[<>:, %*]", "_")
end


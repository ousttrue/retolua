module(..., package.seeall)

function output_error_hook(...)
    return string.format(...)
end

function clean_template(t)
    return string.gsub(t, "[<>:, %*]", "_")
end

function outchecktype(self, context, narg)
    local def=(self.def~='' and 1 or 0)
    local lua_type = context:isbasic(self.ctype)
    if self.dim ~= '' then
        return '!tolua_istable(tolua_S,'..narg..',0,&tolua_err)'
    elseif lua_type then
        return '!tolua_is'..lua_type..'(tolua_S,'..narg..','..def..',&tolua_err)'
    else
        local is_func = "tolua_isusertype"
        if self.ptr == '&' or self.ptr == '' then
            return string.format('(tolua_isvaluenil(tolua_S,%s,&tolua_err) || !%s(tolua_S,%s,"%s",%s,&tolua_err))',
            narg, is_func, narg, (
            self.mod:find("const") and "const " or '')..self.ctype, def)
        else
            return string.format('!%s(tolua_S,%s,"%s",%s,&tolua_err)', 
            is_func, narg, self.ctype, def)
        end
    end
end

------------------------------------------------------------------------------
Base=tolua.define_class('Base')

function Base:__init(node, context)
    assert(node:is(tolua.classFeature), tostring(node))
    self.node=node
    assert(context:is(tolua.ParseContext))
    self.context=context
    -- env
    self.env=self:get_env()
    self.env.self=self
    self.env.context=self.context
    self.env._=self.context:indent()
    setmetatable(self.env, {
        __index=_M,
    })
end

function Base:get_parent_class()
    return  self.context:rfind(function(n) return n:is(tolua.classClass) end)
end

function Base:is_in_container()
    local parent=self.context[#self.context]
    if parent and (parent:is(tolua.classClass) or 
        parent:is(tolua.classModule)) then
        return true
    end
end

function Base:texttemplate(template)
    return texttemplate(template, self.env)
end

function Base:get_env()
    return {}
end

function Base:preamble_enter()
    return ''
end

function Base:preamble_leave()
    return ''
end

function Base:supcode_enter()
    return ''
end

function Base:supcode_leave()
    return ''
end

function Base:register_enter()
    return ''
end

function Base:register_leave()
    return ''
end


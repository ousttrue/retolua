module(..., package.seeall)

StaticMemberFunction=tolua.define_class('StaticMemberFunction')
StaticMemberFunction:extend(Function)

function StaticMemberFunction:cfuncname(lname, overload)
    if self.node.constructor and self.node.owned then
        local elements={
            "tolua",
        }
        for i, v in ipairs(self.context) do
            local name=v.name:gsub('[:<> ,*]', '_')
            table.insert(elements, name)
        end
        table.insert(elements, string.format("new%02d_local", overload))
        return table.concat(elements, '_')
    else
        return StaticMemberFunction:super().cfuncname(self, lname, overload)
    end
end

function StaticMemberFunction:get_env()
    local env={
        self=self,
        push_func = "tolua_pushusertype",
    }
    env.lua_type, env.ctype=self.context:isbasic(self.node.ctype)

    local class=self:get_parent_class()
    assert(class)
    env.class=class
    env.is_func = "tolua_isusertype"
    if self.node.constructor or self.node.static then
        -- static member function
        env.is_func = 'tolua_isusertable'
    end
    env.class_type=class.ctype
    if self.node.const ~= '' then
        env.class_type = "const "..env.class_type
    end
    env.narg=2
    env.to_func = "tolua_tousertype"
    env.lname=self.node.name
    env.cname=self:cfuncname(env.lname, self.node.overload)
    if self.node.overload>0 then
        env.cname=self:cfuncname(env.lname, self.node.overload-1)
    end

    env.args=self:get_arg_count()
    env.nret=self:get_return_count()

    return env
end

function StaticMemberFunction:get_function_call()
    if self.node.constructor then
        return string.format("Mtolua_new((%s)(%s));",
        self.node.ctype, self:supcode_args())
    elseif self.node.out then
        return string.format("%s(%s);",
        self.node.name, self:supcode_args())
    else
        return string.format("%s::%s(%s);",
        class.ctype, self.node.name, self:supcode_args())
    end
end

function StaticMemberFunction:supcode_enter_comment()
    return string.format('/* method: %s of class  %s */',
    self.node.name, self.context[#self.context].ctype)
end

function StaticMemberFunction:supcode_enter()
    local class=self:get_parent_class()
    if class and self.node.constructor and class.flags.pure_virtual then
        -- no constructor for classes with pure virtual methods
        return ''
    end
    return StaticMemberFunction:super().supcode_enter(self)
end

function StaticMemberFunction:register_enter()
    local class=self:get_parent_class()
    if class and self.node.constructor and class.flags.pure_virtual then
        -- no constructor for classes with pure virtual methods
        return ''
    end
    if self.node.constructor and self.node.owned then
        return self:texttemplate([=[
<%_%>tolua_function(tolua_S,"new_local",<% cname:gsub("_local$", "") %>_local);
<%_%>tolua_function(tolua_S,".call",<% cname:gsub("_local$", "") %>_local);
]=])
    else
        return self:texttemplate([=[
<%_%>tolua_function(tolua_S,"<% lname %>",<% cname %>);
]=])
    end
end


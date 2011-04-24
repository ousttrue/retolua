module(..., package.seeall)

-- table to transform operator kind into the appropriate tag method name
local _TM = {
    ['+'] = 'add',
    ['-'] = 'sub',
    ['*'] = 'mul',
    ['/'] = 'div',
    ['<'] = 'lt',
    ['<='] = 'le',
    ['=='] = 'eq',
    ['[]'] = 'geti',
    ['&[]'] = 'seti',
    --['->'] = 'flechita',
}

MemberFunction=tolua.define_class('MemberFunction')
MemberFunction:extend(Function)

------------------------------------------------------------------------------
-- code generate
------------------------------------------------------------------------------
-- concatenate all parameters, following output rules
function MemberFunction:get_env()
    local env={
        self=self,
        push_func = "tolua_pushusertype",
    }
    env.lua_type, env.ctype=self.context:isbasic(self.node.ctype)

    local class=self:get_parent_class()
    assert(class)
    env.class=class
    env.is_func = "tolua_isusertype"
    env.class_type=class.ctype
    if self.node.const ~= '' then
        env.class_type = "const "..env.class_type
    end
    env.narg=2
    env.to_func = "tolua_tousertype"

    if self.node.name:find('^operator') then
        env.lname = "."..(_TM[self.node.kind] or self.node.kind)
    else
        env.lname=self.node.name
    end
    env.cname=self:cfuncname(env.lname, self.node.overload)
    if self.node.overload>0 then
        env.cname_overload=self:cfuncname(env.lname, self.node.overload-1)
    end

    env.args=self:get_arg_count()
    env.nret=self:get_return_count()

    return env
end

function MemberFunction:get_function_call()
    if self.node.name=='operator[]' then
        return string.format("self->operator[](%s);", 
        self.context.flags['1'] and self.node.args[1].name..'-1' or self.node.args[1].name)
    elseif self.node.cast_operator then
        return string.format("self->operator %s();", (self.node.mod..' '..self.node.ctype):strip())
    elseif self.node.out then
        return string.format("%s(%s);", self.node.name, self:supcode_args({'self'}))
    else
        return string.format("self->%s(%s);", self.node.name, self:supcode_args())
    end
end

function MemberFunction:supcode_enter_comment()
    return string.format('/* method: %s of class  %s */',
    self.node.name, self:get_parent_class().ctype)
end

function MemberFunction:supcode_enter_self()
    return self:texttemplate([=[
  <% (self.node.const..' '..class.ctype):strip() %>* self = (<% (self.node.const..' '..class.ctype):strip() %>*)  <% to_func %>(tolua_S,1,0);
]=])
end

function MemberFunction:supcode_enter_self_check()
    return self:texttemplate([=[
${if class and not self.node.constructor and not self.node.static }
#ifndef TOLUA_RELEASE
  if (!self) tolua_error(tolua_S,"<% output_error_hook("invalid 'self' in function '%s'", self.node.name) %>", NULL);
#endif
${/if}
]=])
end

function MemberFunction:supcode_enter_call()
    if self.node.destructor then
        return '  Mtolua_delete(self);'
    elseif self.node.name=='operator&[]' then
        return string.format('  self->operator[](%s%s) =  %s;',
        self.node.args[1].name,
        self.context.flags['1'] and '-1' or '',
        self.node.args[2].name)
    else
        return MemberFunction:super().supcode_enter_call(self)
    end
end


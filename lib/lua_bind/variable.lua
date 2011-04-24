module(..., package.seeall)

Variable=tolua.define_class('Variable')
Variable:extend(Base)

function Variable:cfuncname()
    local elements={}
    if self:is_in_container() then
        table.insert(elements, self.context[#self.context].ctype)
    end

    if self.node.mod:find("unsigned") then
        table.insert(elements, 'unsigned')
    end

    local name=(self.node.lname or self.node.name):gsub("^.*::", "")
    table.insert(elements, name)

    if self.node.ptr == "*" then
        table.insert(elements, "ptr")
    elseif self.node.ptr == "&" then
        table.insert(elements, "ref")
    end

    return clean_template(table.concat(elements, '_'))
end

function Variable:get_env()
    local cfuncname=self:cfuncname()
    local env={
        self=self,
        cgetname = "tolua_get_"..cfuncname,
        csetname = "tolua_set_"..cfuncname,
        static = self.node.mod:match('^%s*(static)'),
        mod=self.node.mod,
    }
    env.class=self:get_parent_class()
    if env.mod:find('tolua_property') then
        local ctype = self.node.mod:match("tolua_property__([^%s]*)")
        ctype = ctype or "default"
        env.prop_get, env.prop_set = get_property_methods(ctype, self.node.name)
        env.mod = env.mod:gsub("tolua_property[^%s]*", "")
    end
    if not env.class or env.static then
        env.mod = env.mod:gsub('^%s*static%s+', '')
    end
    env.lua_type, env.ctype = self.context:isbasic(self.node.ctype)
    env.push_func = "tolua_pushusertype"
    env.to_func = "tolua_tousertype"

    env.ptr=''
    if self.node.ptr~='' then
        env.ptr = '*'
    end

    env.def = 0
    if self.node.def ~= '' then
        env.def = self.node.def
    end

    return env
end

function Variable:getvalue(class, static, prop_get, suffix)
    suffix=suffix or ''
    if class and static then
        return class.ctype..'::'..(prop_get and prop_get.."()" or self.node.name)..suffix
    elseif class then
        return 'self->'..(prop_get and prop_get.."()" or self.node.name)..suffix
    else
        return (prop_get and prop_get.."()" or self.node.name)..suffix
    end
end

function Variable:setvalue(lua_type, ptr, def, to_func, prop_set, level)
    local value
    local mod_type=string.format("%s %s",self.node.mod:strip(), self.node.ctype:strip()):strip()
    to_func=to_func:strip()
    if lua_type then
        value=string.format("((%s)%stolua_to%s(tolua_S,%d,%s))",
        mod_type,
        self.context:get_enum(self.node.ctype) and ' (int)  ' or '  ',
        lua_type,
        level,
        def)
    else
        value=string.format("%s((%s*)  %s(tolua_S,%d,%s))",
        ptr=='' and '*' or '',
        mod_type,
        to_func,
        level,
        def)
    end

    if prop_set then
        return '('..value..')'
    else
        return ' = '..value
    end
end

function Variable:supcode_enter_get_comment()
    return self:texttemplate([=[
${if class }
/* get function: <% self.node.name %> of class  <% class.ctype %> */
${else}
/* get function: <% self.node.name %> */
${/if}
]=])
end

function Variable:supcode_enter_set_comment()
    return self:texttemplate([=[
${if class }
/* set function: <% self.node.name %> of class  <% class.ctype %> */
${else}
/* set function: <% self.node.name %> */
${/if}
]=])
end

function Variable:supcode_enter_self()
    return self:texttemplate([=[
${if class and static==nil }
  <% class.ctype %>* self = (<% class.ctype %>*)  <% to_func %>(tolua_S,1,0);
${/if}
]=])
end

function Variable:supcode_enter_self_check()
    return self:texttemplate([=[
${if class and static==nil }
  if (!self) tolua_error(tolua_S,"<% output_error_hook("invalid 'self' in accessing variable '%s\'", self.node.name) %>",NULL);
${/if}
]=])
end

function Variable:supcode_enter_push()
    if self.node.mod:find('tolua_inherits') then
        return self:texttemplate([=[
#ifdef __cplusplus
  <% push_func %>(tolua_S,(void*)static_cast<<% self.node.ctype %>*>(self), "<% self.node.ctype %>");
#else
  <% push_func %>(tolua_S,(void*)((<% self.node.ctype %>*)self), "<% self.node.ctype %>");
#endif
]=])
    elseif self.env.lua_type then
        return self:texttemplate([=[
  tolua_push<% lua_type %>(tolua_S,(<% ctype %>)<% self:getvalue(class,static,prop_get) %>);
]=])
    elseif self.node.ptr == '&' or self.node.ptr == '' then
        return self:texttemplate([=[
   <% push_func %>(tolua_S,(void*)&<% self:getvalue(class,static,prop_get) %>,"<% self.node.ctype %>");
]=])
    else
        return self:texttemplate([=[
   <% push_func %>(tolua_S,(void*)<% self:getvalue(class,static,prop_get) %>,"<% self.node.ctype %>");
]=])
    end
end

function Variable:supcode_enter_get()
    return self:texttemplate([=[
<% self:supcode_enter_get_comment(context) %>
#ifndef TOLUA_DISABLE_<% cgetname %>
static int <% cgetname %>(lua_State* tolua_S)
{
<% self:supcode_enter_self(context) %>
${if class and static==nil }
#ifndef TOLUA_RELEASE
<% self:supcode_enter_self_check(context) %>
#endif
${/if}
<% self:supcode_enter_push(context) %>
 return 1;
}
#endif //#ifndef TOLUA_DISABLE
]=])
end

function Variable:supcode_enter_set()
    return self:texttemplate([=[
<% self:supcode_enter_set_comment(context) %>
#ifndef TOLUA_DISABLE_<% csetname %>
static int <% csetname %>(lua_State* tolua_S)
{
<% self:supcode_enter_self(context) %>
#ifndef TOLUA_RELEASE
  tolua_Error tolua_err;
<% self:supcode_enter_self_check(context) %>
  if (<% outchecktype(self.node, context, 2) %>)
   tolua_error(tolua_S,"#vinvalid type in variable assignment.",&tolua_err);
#endif
${if self.node.ctype == 'char*' and self.node.dim ~= '' }
 strncpy((char*)
<% self:getvalue(class, static) %>,(const char*)tolua_tostring(tolua_S,2,<% def %>),<% self.node.dim %>-1);
${else}
  <% self:getvalue(class, static, prop_set) %><% self:setvalue(lua_type, ptr, def, to_func, prop_set, 2) %>
;
${/if}
 return 0;
}
#endif //#ifndef TOLUA_DISABLE
]=])
end

function Variable:supcode_enter()
    return self:texttemplate([=[

<% self:supcode_enter_get() %>
${if not self.node:is_readonly() }

<% self:supcode_enter_set() %>
${/if}
]=])
end

function Variable:register_enter()
    if #self.context==1 then
        if Variable._warning==nil then
            warning("Mapping variable to global may degrade performance")
            Variable._warning = 1
        end
    end

    return self:texttemplate([=[
<%_%>tolua_variable(tolua_S,"<% self.node.lname %>",<% cgetname %>,<% csetname and csetname or 'NULL' %>);
]=])
end


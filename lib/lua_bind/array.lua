module(..., package.seeall)

Array = tolua.define_class('Array')
Array:extend(Variable)

function Array:cfuncname()
    local elements={}
    for i, v in ipairs(self.context) do
        table.insert(elements, v.lname or v.name)
    end
    local name=self.node.name:gsub('%.', '_')
    table.insert(elements, name)
    return table.concat(elements, '_')
end

function Array:supcode_enter()
    return self:get_function()..(
    self.node:is_readonly() and '' or self:set_function()
    )
end

function Array:get_function()
    return self:texttemplate([=[
${if class}
/* get function: <% self.node.name %> of class  <% class.ctype %> */
${else}
/* get function: <% self.node.name %> */
${/if}
#ifndef TOLUA_DISABLE_<% cgetname %>
static int <% cgetname %>(lua_State* tolua_S)
{
 int tolua_index;
${if class and not static}
  <% class.ctype %>* self;
 lua_pushstring(tolua_S,".self");
 lua_rawget(tolua_S,1);
 self = (<% class.ctype %>*)  lua_touserdata(tolua_S,-1);
${/if}
#ifndef TOLUA_RELEASE
 {
  tolua_Error tolua_err;
  if (!tolua_isnumber(tolua_S,2,0,&tolua_err))
   tolua_error(tolua_S,"#vinvalid type in array indexing.",&tolua_err);
 }
#endif
${if self.context.flags['1'] }
 tolua_index = (int)tolua_tonumber(tolua_S,2,0)-1;
${else}
 tolua_index = (int)tolua_tonumber(tolua_S,2,0);
${/if}
#ifndef TOLUA_RELEASE
${if self.node.dim and self.node.dim ~= ''}
 if (tolua_index<0 || tolua_index>=<% self.node.dim %>)
${else}
 if (tolua_index<0)
${/if}
  tolua_error(tolua_S,"array indexing out of range.",NULL);
#endif
${if lua_type}
 tolua_push<% lua_type %>(tolua_S,(<% ctype %>)<% self:getvalue(class,static,nil,'[tolua_index]') %>);
${else}
${if self.node.ptr == '&' or self.node.ptr == '' }
  <% push_func %>(tolua_S,(void*)&<% self:getvalue(class,static,nil,'[tolua_index]') %>,"<% self.node.ctype %>");
${else}
  <% push_func %>(tolua_S,(void*)<% self:getvalue(class,static,nil,'[tolua_index]') %>,"<% self.node.ctype %>");
${/if}
${/if}
 return 1;
}
#endif //#ifndef TOLUA_DISABLE

]=])
end

function Array:set_function()
    return self:texttemplate([=[

${if class }
/* set function: <% self.node.name %> of class  <% class.ctype %> */
${else}
/* set function: <% self.node.name %> */
${/if}
#ifndef TOLUA_DISABLE_<% csetname %>
static int <% csetname %>(lua_State* tolua_S)
{
 int tolua_index;
${if class and static==nil }
  <% class.ctype %>* self;
 lua_pushstring(tolua_S,".self");
 lua_rawget(tolua_S,1);
 self = (<% class.ctype %>*)  lua_touserdata(tolua_S,-1);
${/if}
#ifndef TOLUA_RELEASE
 {
  tolua_Error tolua_err;
  if (!tolua_isnumber(tolua_S,2,0,&tolua_err))
   tolua_error(tolua_S,"#vinvalid type in array indexing.",&tolua_err);
 }
#endif
${if self.context.flags['1'] }
 tolua_index = (int)tolua_tonumber(tolua_S,2,0)-1;
${else}
 tolua_index = (int)tolua_tonumber(tolua_S,2,0);
${/if}
#ifndef TOLUA_RELEASE
${if self.node.dim and self.node.dim ~= '' }
 if (tolua_index<0 || tolua_index>=<% self.node.dim %>)
${else}
 if (tolua_index<0)
${/if}
  tolua_error(tolua_S,"array indexing out of range.",NULL);
#endif
  <% self:getvalue(class,static,nil,'[tolua_index]') %><% self:setvalue(lua_type, ptr, def, to_func, nil, 3) %>;
 return 0;
}
#endif //#ifndef TOLUA_DISABLE

]=])
end

function Array:register_enter()
    return self:texttemplate([=[
${if csetname }
<%_%>tolua_array(tolua_S,"<% self.node.lname %>",<% cgetname %>,<% csetname %>);
${else}
<%_%>tolua_array(tolua_S,"<% self.node.lname %>",<% cgetname %>,NULL);
${/if}
]=])
end


module(..., package.seeall)

StlIterator=tolua.define_class('StlIterator')
StlIterator:extend(MemberFunction)

function StlIterator:__init(context, class_type)
    self.context=context
    self.class_type=class_type
    self.template_arg=self.class_type:match("%b<>"):sub(2, -2)
    self.node=tolua.create_functions(context, self.template_arg..'& foreachi', '', '')
    self.iterator_type=string.format("std::pair<%s::iterator, %s::iterator>",
    self.class_type, self.class_type)
    context:add_usertype(self.iterator_type)
    -- env
    self.env=self:get_env()
    self.env.self=self
    self.env.context=self.context
    self.env._=self.context:indent()
    self.env.lua_type, self.env.ctype = self.context:isbasic(self.node.ctype)
    self.env.push_func = "tolua_pushusertype",
    setmetatable(self.env, {
        __index=_M,
    })
end

function StlIterator:get_env()
    local env={
        class_type=self.class_type,
        iterator_type=self.iterator_type,
        cname="tolua_"..self.context.name..'_'..self.class_type:gsub("[:<>,* ]", "_").."_iterator",
        lname="foreachi",
        template_arg=self.template_arg,
    }
    return env
end

function StlIterator:supcode_enter()
    return self:texttemplate([=[

/* stl foreachi: class  <% class_type %> */
#ifndef TOLUA_DISABLE_<% cname %>
static int <% cname %>_gc(lua_State* tolua_S)
{
    //printf("<% cname %>_gc\n");
    <% iterator_type %> *range=(<% iterator_type %>*)lua_touserdata(tolua_S, 1);
    range->~<% iterator_type:sub(6) %>();
    return 0;
}

static int <% cname %>_internal(lua_State* tolua_S)
{
  <% iterator_type %> *range=(<% iterator_type %>*)lua_touserdata(tolua_S, lua_upvalueindex(1));
  if(range->first==range->second){
      return 0;
  }
  int index=lua_tonumber(tolua_S, lua_upvalueindex(2));
  tolua_pushnumber(tolua_S, index);
  // update index
  tolua_pushnumber(tolua_S, index+1);
  lua_replace(tolua_S, lua_upvalueindex(2));

  //tolua_pushusertype(tolua_S, &(*range->first++), "<% template_arg %>");
<% self:get_return_type() %> *range->first++;
<% self:push_return_value() %>

  return 2;
}

static int <% cname %>(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
     !tolua_isusertype(tolua_S,1,"<% class_type %>",0,&tolua_err) ||
     !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
  goto tolua_lerror;
 else
#endif
 {
  <% class_type %>* self = (<% class_type %>*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
  if (!self) tolua_error(tolua_S,"invalid 'self' in function 'foreachi'", NULL);
#endif
  {
    <% iterator_type %>* range=(<% iterator_type %>*)lua_newuserdata(tolua_S, sizeof(<% iterator_type %>));
    *range=std::make_pair(self->begin(), self->end());
    luaL_getmetatable(tolua_S, "<% iterator_type %>");
    lua_setmetatable(tolua_S, -2);
    lua_pushnumber(tolua_S, 0);
    // gc
    lua_pushcclosure(tolua_S, <% cname %>_internal, 2);
  }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'foreachi'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

]=])
end

function StlIterator:register_enter()
    return self:texttemplate([=[
<%_%>luaL_getmetatable(tolua_S, "<% iterator_type %>");
<%_%>lua_pushstring(tolua_S, "__gc");
<%_%>lua_pushcfunction(tolua_S, <% cname %>_gc);
<%_%>lua_settable(tolua_S, -3);
<%_%>lua_pop(tolua_S, 1);
<%_%>tolua_function(tolua_S,"<% lname %>",<% cname %>);
]=])
end


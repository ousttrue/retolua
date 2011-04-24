module(..., package.seeall)

Function=tolua.define_class('Function')
Function:extend(Base)

function Function:get_env()
    local env={
        self=self,
        push_func = "tolua_pushusertype",
    }
    env.lua_type, env.ctype = self.context:isbasic(self.node.ctype)
    env.narg=1
    env.lname=self.node.name
    env.cname=self:cfuncname(env.lname, self.node.overload)
    if self.node.overload>0 then
        env.cname_overload=self:cfuncname(env.lname, self.node.overload-1)
    end
    env.args=self:get_arg_count()
    env.nret=self:get_return_count()

    return env
end

function Function:cfuncname(lname, overload)
    local elements={
        "tolua",
    }
    for i, v in ipairs(self.context) do
        local name=v.name:gsub('[:<> ,]', '_')
        table.insert(elements, name)
    end
    table.insert(elements, 
    lname:gsub("%.", "_")..string.format("%02d", overload))
    return table.concat(elements, '_')
end

function Function:get_arg_count()
    if #self.node.args>0 and self.node.args[1].ctype ~= 'void' then
        return #self.node.args
    else
        return 0
    end
end

function Function:get_return_count()
    local nret=0
    if self.node.name == 'operator&[]' then
    else
        if self.node.ctype ~= '' and self.node.ctype ~= 'void' then
            nret = 1
        end
        for i, v in ipairs(self.node.args) do
            if v.ret~='' then
                nret = nret + (v.ret=='' and 0 or 1)
            end
        end
    end
    return nret
end

function Function:supcode_args(args)
    args=args or {}
    if #self.node.args>0 and self.node.args[1].ctype~='void' then
        for i, v in ipairs(self.node.args) do
            if v.ptr=='&' and not self.context:isbasic(v.ctype) then
                table.insert(args, '*'..v.name)
            elseif v.ret=='*' then
                table.insert(args, '&'..v.name)
            else
                table.insert(args, v.name)
            end
        end
    end
    return table.concat(args, ',')
end

function Function:get_function_call()
    return string.format("%s(%s);", self.node.name, self:supcode_args())
end

function Function:supcode_enter_comment()
    return string.format('/* function: %s */', self.node.name)
end

function Function:supcode_enter_check()
    return self:texttemplate([=[
${if self.node.overload==0 }
#ifndef TOLUA_RELEASE
${/if}
 tolua_Error tolua_err;
 if (
${if class }
     !<% is_func %>(tolua_S,1,"<% class_type %>",0,&tolua_err) ||
${/if}
${if args>0 }${eachi self.node.args, i, v}
${if self.context:isbasic(v.ctype) ~= 'value'  }
     <% outchecktype(v, self.context, narg+i-1) %> ||
${/if}
${/eachi}
${/if}
     !tolua_isnoobj(tolua_S,<% narg+args %>,&tolua_err)
 )
  goto tolua_lerror;
 else
${if self.node.overload==0 }
#endif
${/if}
]=])
end

function Function:supcode_enter_self()
    return ''
end

function Function:supcode_enter_self_check()
    return ''
end

function Function:supcode_enter_setup_args()
    return self:texttemplate([=[
${if args>0 }
${eachi self.node.args, i, v}
${if v.dim ~= '' and tonumber(v.dim)==nil }
#ifdef __cplusplus
  <% builddeclaration(v, self.context, narg+i,true):strip() %>
#else
  <% builddeclaration(v, self.context, narg+i,false):strip() %>
#endif
${else}
  <% builddeclaration(v, self.context, narg+i-1,false):strip() %>
${/if}
${/eachi}
${/if}
<% self:supcode_enter_self_check() %>
${if args>0 }${eachi self.node.args, i, v}
${if v.dim ~= '' }
<% getarray(v, self.context, narg+1) %>
${/if}
${/eachi}${/if}
]=])
end

function Function:push_return_value()
    return self:texttemplate([=[
${if self.node.ctype ~= '' and self.node.ctype ~= 'void' }
${if lua_type and self.node.name ~= "new" }
   tolua_push<% lua_type %>(tolua_S,(<% ctype %>)tolua_ret);
${else}
${if self.node.ptr == '' }
   {
#ifdef __cplusplus
    void* tolua_obj = Mtolua_new((<% self.node.ctype:gsub("const%s+", "") %>)(tolua_ret));
     <% push_func %>(tolua_S,tolua_obj,"<% self.node.ctype %>");
    tolua_register_gc(tolua_S,lua_gettop(tolua_S));
#else
    void* tolua_obj = tolua_copy(tolua_S,(void*)&tolua_ret,sizeof(<% self.node.ctype %>));
     <% push_func %>(tolua_S,tolua_obj,"<% self.node.ctype %>");
    tolua_register_gc(tolua_S,lua_gettop(tolua_S));
#endif
   }
${elseif self.node.ptr == '&' }
    <% push_func %>(tolua_S,(void*)&tolua_ret,"<% self.node.ctype %>");
${else}
    <% push_func %>(tolua_S,(void*)tolua_ret,"<% self.node.ctype %>");
${if self.node.owned }
    tolua_register_gc(tolua_S,lua_gettop(tolua_S));
${/if}
${/if}
${/if}
${/if}
${eachi self.node.args, i, v}
<% retvalue(v, self.context) %>
${/eachi}
]=])
end

function Function:push_return_arg()
    return self:texttemplate([=[
${if args>0 }
${eachi self.node.args, i, v}
${if not self.node.ctype:find('const') and v.dim ~= '' }
  {
   int i;
   for(i=0; i<<% v.dim %>;i++)
${if lua_type }
    tolua_pushfield<% lua_type %>(tolua_S,<% narg+i %>,i+1,(<% ctype %>)<% v.name %>[i]);
${else}
${if v.ptr == '' }
   {
#ifdef __cplusplus
    void* tolua_obj = Mtolua_new((<% class_type %>)(<% v.name %>[i]));
    tolua_pushfieldusertype_and_takeownership(tolua_S,<% narg+i %>,i+1,tolua_obj,"<% class_type %>");
#else
    void* tolua_obj = tolua_copy(tolua_S,(void*)&<% v.name %>[i],sizeof(<% class_type %>));
    tolua_pushfieldusertype(tolua_S,<% narg+i %>,i+1,tolua_obj,"<% class_type %>");
#endif
   }
${else}
   tolua_pushfieldusertype(tolua_S,<% narg+i %>,i+1,(void*)<% v.name %>[i],"<% class_type %>");
${/if}
${/if}
  }
${/if}
${/eachi}
${eachi self.node.args, i, v}
${if v.dim ~= '' and tonumber(v.dim)==nil }
#ifdef __cplusplus
  Mtolua_delete_dim(<% v.name %>);
#else
  free(<% v.name %>);
#endif
${/if}
${/eachi}
${/if}
]=])
end

function Function:get_return_type()
    if self.node.ctype ~= '' and self.node.ctype ~= 'void' then
        local return_type=(self.node.mod..' '..self.node.ctype..self.node.ptr):strip()
        return string.format('   %s tolua_ret = (%s)',
        return_type, 
        return_type)
    else
        return ' '
    end
end

function Function:supcode_enter_call()
    return self:texttemplate([=[
  {
<% self:get_return_type() %>  <% self:get_function_call() %>
<% self:push_return_value() %>
  }
<% self:push_return_arg() %>
]=])
end

function Function:supcode_enter_overload()
    return self:texttemplate([=[
${if self.node.overload==0 }
#ifndef TOLUA_RELEASE
 tolua_lerror:
${if self.node.constructor and self.node.owned }
 tolua_error(tolua_S,"<% output_error_hook("#ferror in function 'new'.") %>",&tolua_err);
${else}
 tolua_error(tolua_S,"<% output_error_hook("#ferror in function '%s'.", lname) %>",&tolua_err);
${/if}
 return 0;
#endif
${else}
tolua_lerror:
 return <% cname_overload %>(tolua_S);
${/if}
]=])
end

function Function:supcode_enter()
    return self:texttemplate([=[

<% self:supcode_enter_comment() %>
#ifndef TOLUA_DISABLE_<% cname %>
static int <% cname %>(lua_State* tolua_S)
{
<% self:supcode_enter_check() %>
 {
<% self:supcode_enter_self() %>
<% self:supcode_enter_setup_args() %>
<% self:supcode_enter_call() %>
 }
 return <% nret %>;
<% self:supcode_enter_overload() %>
}
#endif //#ifndef TOLUA_DISABLE
]=])
end

function Function:register_enter()
    return self:texttemplate([=[
<%_%>tolua_function(tolua_S,"<% lname %>",<% cname %>);
]=])
end


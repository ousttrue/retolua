module(..., package.seeall)

-- concatenate all parameters, following output rules
local function concatparam (line, ...)
    local i=1
    while i<=#arg do
        if _cont and not string.find(_cont,'[%(,"]') and
            string.find(arg[i],"^[%a_~]") then
            line = line .. ' '
        end
        line = line .. arg[i]
        if arg[i] ~= '' then
            _cont = string.sub(arg[i],-1,-1)
        end
        i = i+1
    end
    if string.find(arg[#arg],"[%/%)%;%{%}]$") then
        _cont=nil line = line .. '\n'
    end
    return line
end

function builddeclaration(arg, context, narg, cplusplus)
    local ctype = arg.ctype
    if arg.dim ~= '' then
        -- eliminates const modifier for arrays
        ctype = string.gsub(arg.ctype,'const%s+','')  
    end
    local ptr = ''
    if arg.ptr~='' and not context:isbasic(ctype) then 
        ptr = '*' 
    end
    local line = concatparam(""," ",arg.mod,ctype,ptr)
    if arg.dim ~= '' and tonumber(arg.dim)==nil then
        line = concatparam(line,'*')
    end
    line = concatparam(line,arg.name)
    if arg.dim ~= '' then
        if tonumber(arg.dim)~=nil then
            line = concatparam(line,'[',arg.dim,'];')
        else
            if cplusplus then
                line = concatparam(line,' = Mtolua_new_dim(',ctype,ptr,', '..arg.dim..');')
            else
                line = concatparam(line,' = (',ctype,ptr,'*)',
                'malloc((',arg.dim,')*sizeof(',ctype,ptr,'));')
            end
        end
    else
        local t = context:isbasic(ctype)
        line = concatparam(line,' = ')
        if t == 'state' then
            line = concatparam(line, 'tolua_S;')
        else
            if t == 'number' and string.find(arg.ptr, "%*") then
                t = 'userdata'
            end
            if not t and ptr=='' then line = concatparam(line,'*') end
            line = concatparam(line,'((',arg.mod,ctype)
            if not t then
                line = concatparam(line,'*')
            end
            line = concatparam(line,') ')
            local nctype=arg.ctype:gsub('const%s+','')
            if context:get_enum(nctype) then
                line = concatparam(line,'(int) ')
            end
            local def = 0
            if arg.def ~= '' then
                def = arg.def
                if (ptr == '' or arg.ptr == '&') and not t then
                    def = "(void*)&(const "..ctype..")"..def
                end
            end
            if t then
                line = concatparam(line,'tolua_to'..t,'(tolua_S,',narg,',',def,'));')
            else
                line = concatparam(line,'tolua_tousertype(tolua_S,',narg,',',def,'));')
            end
        end
    end
    return line
end

function retvalue(arg, context)
    if arg.ret == '' then
        return ''
    end
    local lua_type, ctype = context:isbasic(arg.ctype)
    if lua_type and lua_type~='' then
        return '   tolua_push'..lua_type..'(tolua_S,('..ctype..')'..arg.name..');'
    else
        return '   tolua_pushusertype(tolua_S,(void*)'..arg.name..',"'..arg.ctype..'");'
    end
end

function getarray(arg, context, narg)
    local env={
        ctype=arg.ctype:gsub('const ',''),
    }
    env.lua_type=context:isbasic(env.class_type)
    if arg.ptr~='' then 
        env.ptr = '*' 
    end

    return texttemplate([=[
  {
#ifndef TOLUA_RELEASE
${if (lua_type) }
   if (!tolua_is<% lua_type %>array(tolua_S,<% narg %>,<% arg.dim %>,<% arg.def~='' and 1 or 0 %>,&tolua_err))
${else}
   if (!tolua_isusertypearray(tolua_S,<% narg %>,"<% ctype %>",%< arg.dim %>,<% arg.def~='' and 1 or 0 %>,&tolua_err))
${/if}
    goto tolua_lerror;
   else
#endif
   {
    int i;
    for(i=0; i<<% arg.dim %>;i++)
   <% arg.name %>[i] = ${if not lua_type and ptr=='' }*${/if}(<% ctype %>${if not lua_type }*${/if})
${if lua_type }
tolua_tofield<% lua_type %>(tolua_S,<% narg %>,i+1,<% arg.def ~= '' and arg.def or 0 %>));
${else}
tolua_tofieldusertype(tolua_S,<% narg %>,i+1,<% arg.def ~= '' and arg.def or 0 %>));
${/if}
   }
  }
    ]=], env)
end


module(..., package.seeall)

Generator=tolua.define_class('Generator')

function Generator:__init(context)
    self.context=context
    -- do return end

    -- preprocess global type

    -- add std::vector
    context:push(context.root)
    table.foreachi(context._global_types, function(i, v)
        local container, typename=v:match("std::(vector)(%b<>)")
        if container then
            typename=typename:sub(2, -2)
            context:push(context:get_or_create(tolua.classNamespace, "std"))
            do
                local class=context:create(tolua.classClass, 
                "vector<"..typename..">", '')
                context:push(class)

                -- methods
                tolua.Function(context, "unsigned int size", {}, "const")
                tolua.Function(context, "void push_back", {"const "..typename.." &value"}, "")
                tolua.Function(context, typename.."& operator", {"int index"}, "", "[]")
                tolua.Function(context, typename.." operator", {"int index"}, "", "&[]")
                table.insert(class, StlIterator(context, class.ctype))

                -- build
                class:walk("build", context)

                context:pop()
            end
            context:pop()
        end
    end)
    context:pop()

    -- preprocess tree
    table.walk(context.root, function(stack, node, temp)
    end, self.context)
end

function Generator:get_binder(node, context)
    if node:is(StlIterator) then
        return node
    end
    
    if node:is(tolua.classFunction) then
        -- function
        if context[#context]:is(tolua.classClass) then
            if node.mod:find('static') or node.constructor then
                return StaticMemberFunction(node, context)
            else
                return MemberFunction(node, context)
            end
        else
            return Function(node, context)
        end
    end

    if node:is(tolua.classVariable) then
        -- variable
        if node.dim and node.dim~='' then
            if node.ctype=='char*' then
                return Variable(node, context)
            else
                return Array(node, context)
            end
        else
            return Variable(node, context)
        end
    end

    if node:is(tolua.classClass) then
        -- class
        return Class(node, context)
    end

    if node:is(tolua.classModule) then
        -- module/namespace
        if #context==0 then
            return RootModule(node, context)
        else
            return Module(node, context)
        end
    end

    if node:is(tolua.classEnumerate) then
        -- enum
        return Enum(node, context)
    end

    if node:is(tolua.Verbatim) then
        -- verbatim(embeded c code)
        return Verbatim(node, context)
    end

    error(tostring('unknown node: '..tostring(node)))
end

function Generator:method_walk(context, method)
    local result=table.walk(context.root, function(stack, node, temp)
        local binder=self:get_binder(node, stack)
        table.insert(temp, binder[method..'_enter'](binder))
        coroutine.yield()
        table.insert(temp, binder[method..'_leave'](binder))
    end, context)
    return table.concat(result)
end

function Generator:source()
    local env={
        os=os,
        clean_template=clean_template,
        tolua=tolua,
        self=self,
        context=self.context,
    }

    return texttemplate([=[
/*
** Lua binding: <% context.name %>
** Generated automatically by <% tolua.TOLUA_VERSION %> on <% os.date() %>
*/

#ifndef __cplusplus
#include "stdlib.h"
#endif
#include "string.h"

#include "tolua++.h"

${if not context.flags.h}
/* Exported function */
TOLUA_API int  tolua_<% context.name %>_open (lua_State* tolua_S);
${/if}

<% self:method_walk(context, 'preamble') %>

/* function to release collected object via destructor */
#ifdef __cplusplus
${eachi context._collect, i, v}

static int tolua_collect_<% clean_template(v) %> (lua_State* tolua_S)
{
 <% v %>* self = (<% v %>*) tolua_tousertype(tolua_S,1,0);
	Mtolua_delete(self);
	return 0;
}
${/eachi}
#endif


/* function to register type */
static void tolua_reg_types (lua_State* tolua_S)
{
${if context.flags.t}
 #ifndef Mtolua_typeid
 #define Mtolua_typeid(L,TI,T)
 #endif
${/if}
${eachi context._usertype, i, v}
 tolua_usertype(tolua_S,"<% v %>");
${if context.flags.t }
 Mtolua_typeid(tolua_S,typeid(<% v %>), "<% v %>");
${/if}
${/eachi}
}
<% self:method_walk(context, 'supcode') %>

/* Open function */
TOLUA_API int tolua_<% context.name %>_open (lua_State* tolua_S)
{
 tolua_open(tolua_S);
 tolua_reg_types(tolua_S);
<% self:method_walk(context, 'register') %>
 return 1;
}

#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 501
#ifdef __cplusplus
extern "C" {
#endif

 TOLUA_API int luaopen_<% context.name %> (lua_State* tolua_S) {
 return tolua_<% context.name %>_open(tolua_S);
};

#ifdef __cplusplus
}
#endif
#endif

]=], env)
end

function Generator:header()
    return texttemplate([=[
/*
** Lua binding: <% context.name %>
** Generated automatically by <% tolua.TOLUA_VERSION %> on <% date %>.
*/

/* Exported function */
TOLUA_API int  tolua_<% context.name %>_open(lua_State* tolua_S);

]=], {
    context=self.context,
    date=os.date(),
    tolua=tolua,
})
end


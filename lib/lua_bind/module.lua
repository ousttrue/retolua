module(..., package.seeall)

Module=tolua.define_class('Module')
Module:extend(Base)

function Module:get_env()
    local env={
        self=self,
    }
    return env
end

function Module:register_enter()
    return self:texttemplate([=[
<%_%>tolua_module(tolua_S,"<% self.node.name %>",<% self.node:get_variable_count() %>);
<%_%>tolua_beginmodule(tolua_S,"<% self.node.name %>");
]=])
end

function Module:register_leave()
    return self:texttemplate([=[
<%_%>tolua_endmodule(tolua_S);
]=])
end


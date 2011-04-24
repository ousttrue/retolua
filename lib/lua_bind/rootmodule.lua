module(..., package.seeall)

RootModule = tolua.define_class('RootModule')
RootModule:extend(Module)

function RootModule:register_enter()
    return self:texttemplate([=[
<%_%>tolua_module(tolua_S,NULL,<% self.node:get_variable_count() %>);
<%_%>tolua_beginmodule(tolua_S,NULL);
]=])
end


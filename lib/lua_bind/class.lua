module(..., package.seeall)

Class=tolua.define_class('Class')
Class:extend(Module)

function Class:get_env()
    local env={
        self=self,
        gc=self.context:get_collection(self.node.ctype),
    }
    return env
end

function Class:register_enter()
    return self:texttemplate([=[
${if gc}
<%_%>#ifdef __cplusplus
<%_%>tolua_cclass(tolua_S,"<% self.node.lname %>","<% self.node.ctype %>","<% self.node.btype %>",<% gc %>);
<%_%>#else
<%_%>tolua_cclass(tolua_S,"<% self.node.lname %>","<% self.node.ctype %>","<% self.node.btype %>",NULL);
<%_%>#endif
${else}
<%_%>tolua_cclass(tolua_S,"<% self.node.lname %>","<% self.node.ctype %>","<% self.node.btype %>",NULL);
${/if}
<%_%>tolua_beginmodule(tolua_S,"<% self.node.lname %>");
]=])
end


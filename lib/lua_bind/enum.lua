module(..., package.seeall)

Enum=tolua.define_class('Enum')
Enum:extend(Base)

function Enum:register_enter()
    return self:texttemplate([=[
${eachi self.node.names, i, v}
${if self.node.enums[i] and self.node.enums[i] ~= "" }
<%_%>tolua_constant(tolua_S,"<% self.node.enums[i] %>",<% self.node.namespace..v %>);
${/if}
${/eachi}
]=])
end


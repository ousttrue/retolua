function classDefine:register_enter(context)
    return context:texttemplate([=[
<%_%>tolua_constant(tolua_S,"<% self.lname %>",<% self.name %>);
]=])
end



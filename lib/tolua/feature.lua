module(..., package.seeall)

classFeature = define_class('Feature')
classFeature:extend(Node)

function classFeature:__init(parent_context, name)
    if self:is(classPackage) then
    else
        if parent_context and parent_context:is(ParseContext) then
            self.namespace=parent_context:getnamespace()
            self.parent=parent_context[#parent_context]
        else
            assert(parent_context, 'no parent: '..self.__classname)
            self.parent=parent_context
        end
    end
    assert(name, 'no name: '..self.__classname)
    self.name=name
    if self.name~='' then
        -- alias
        local n = self.name:split('@')
        self.name = n[1]
        self.name = string.gsub(self.name, ":%d*$", "")
        self.lname = n[2] or string.gsub(n[1],"%[.-%]","")
        self.lname = string.gsub(self.lname, ":%d*$", "")
        self.lname = clean_template(self.lname)
    end
end

function classFeature:__tostring()
    return string.format("<%s:%s>", 
    tostring(self.__classname), tostring(self.name))
end

function classFeature:print()
    local context=ParseContext()
    self:walk('print', context)
    print(context:to_s())
end


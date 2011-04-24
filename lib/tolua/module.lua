module(..., package.seeall)

classModule = define_class('Module')
classModule:extend(classFeature)

function classModule:__init(context, name)
    classModule:super().__init(self, context, name)
    self.overload_count = {}
end

function classModule:get_variable_count()
    return table.foldi(self, 0, function(acc, i, v)
        if v:is(classVariable) then
            return acc+1
        else
            return acc
        end
    end)
end

function classModule:overload(name)
    if self.overload_count[name] then
        self.overload_count[name] = self.overload_count[name] + 1
    else
        self.overload_count[name] = 0
    end
    return self.overload_count[name]
end

function classModule:print_enter(context)
    print(context:indent().."Module{")
    print(context:indent().." name = '"..self.name.."';")
end
function classModule:print_leave(context)
    print(context:indent().."}")
end


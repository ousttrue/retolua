module(..., package.seeall)

classNamespace = define_class('NameSpace')
classNamespace:extend(classModule)

function classNamespace:print_enter(context)
    print(context:indent().."Namespace{")
    print(context:indent().." name = '"..self.name.."',")
end
function classNamespace:print_leave(context)
    print(context:indent().."}")
end


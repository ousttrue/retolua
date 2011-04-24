module(..., package.seeall)

classDefine = define_class('Define')
classDefine:extend(classFeature)

classDefine.matcher=Matcher("^#define%s+([^%s]*)[^\n]*\n",
function(context, name)
    context[#context]:create(Define, name)
end)

function classDefine:__init(parent, name)
    self.parent=parent
    self.name=assert(name, "#invalid define")
    self:buildnames()
end

function classDefine:print_enter(context)
    print(context:indent().."Define{")
    print(context:indent().." name = '"..self.name.."',")
    print(context:indent().." lname = '"..self.lname.."',")
    print(context:indent().."}")
end


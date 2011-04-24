module(..., package.seeall)

classEnumerate = define_class('Enumerate')
classEnumerate:extend(classFeature)

classEnumerate.matcher=MultiMatcher(
    -- try enumerates
    {"^enum%s+(%S*)%s*(%b{})%s*([^%s;]*)%s*;?",
    function(context, name, body, varname)
        context:create(classEnumerate, name, body:sub(2, -2))
        if name and name ~= "" then
            context:typedef("int "..name)
        end
        if varname ~= "" then
            if name ~= "" then
                context:create(Variable, name.." "..varname)
            else
                local ns = context:getnamespace()
                warning(string.format(
                "Variable %s of ctype <anonymous enum> is declared as read-only",
                ns..varname))
                context:create(Variable, "tolua_readonly int "..varname)
            end
        end
    end},
    -- try enumerate
    {"^typedef%s+enum%s*(%b{})%s*(%S+)%s*;",
    function(context, body, name)
        context:create(classEnumerate, name, body:sub(2, -2))
        if name and name ~= "" then
            context:typedef("int "..name)
        end
    end},
    -- try enumerate
    {"^typedef%s+enum%s+(%S+)%s*(%b{})%s*(%S+)%s*;",
    function(context, tag, body, name)
        context:create(classEnumerate, name, body:sub(2, -2))
        if name and name ~= "" then
            context:typedef("int "..name)
        end
    end}
)
classEnumerate.matcher.name='Enum'

function classEnumerate:__init(context, name, body)
    classEnumerate:super().__init(self, context, name)
    self.names={}
    self.enums={}
    if body then
        table.foreachi(body:split(','), function(i, v)
            local name_initial = v:split('=')
            local names=name_initial[1]:split('@')
            table.insert(self.names, names[1])
            table.insert(self.enums, names[2] or names[1])
            context:add_enumvalue(self.name..names[1])
        end)
    end
    context:append_enum(self)
end

function classEnumerate:__eq(rhs)
    if #self.names~=#rhs.names then
        return false
    end
    for i=1, #self.names do
        if self.names[i]~=rhs.names[i] then
            return false
        end
    end
    return self.name==rhs.name
end

function classEnumerate:__tostring()
    local args={}
    table.foreachi(self.names, function(i, v)
        table.insert(args, v)
    end)
    return string.format(
    "%s{%s}",
    self.name,
    table.concat(args, ', ')
    )
end

function classEnumerate:print_enter(context)
    print(context:indent().."Enumerate{")
    print(context:indent().." name = "..self.name)
    table.foreachi(self.names, function(i, v)
        print(context:indent().." '"..v.."'("..self.enums[i].."),")
    end)
    print(context:indent().."}")
end


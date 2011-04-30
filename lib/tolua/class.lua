module(..., package.seeall)

classClass = define_class('Class')
classClass:extend(classModule)

function classClass:__init(context, name, base, extra_bases)
    classClass:super().__init(self, context, name)

    self.flags={}
    self.base=base

    self.ctype = self.namespace..self.name

    self.btype = context:findtype(self.base) or self.base
    if extra_bases then
        self.extra_bases=table.mapi(extra_bases, function(i, v)
            self.extra_bases[i] = context:findtype(v) or v
        end)
    end
    assert(self.base, "no base")
end

function classClass:__eq(rhs)
    return 
    self.name==rhs.name and
    self.ctype==rhs.ctype and
    self.base==rhs.base
end

function classClass:__tostring()
    local members={}
    table.foreachi(self, function(i, v)
        table.insert(members, '  '..tostring(v)..'\n')
    end)
    return string.format(
    "\nclass %s%s{\n%s}\n",
    self.name,
    (self.base=='' and '' or ': '..self.base),
    table.concat(members, '')
    )
end

function classClass:build_enter(context)
    if self.flags.protected_destructor then
        return
    end

    for i, v in ipairs(self) do
        if v:is(classFunction) and
            v.destructor or
            (v.constructor and not context.flags.D) then
            context:push_collection(self.ctype)
            break
        end
    end
end

function classClass:set_protected_destructor(p)
    self.flags.protected_destructor = self.flags.protected_destructor or p
end

function classClass:print_enter(context)
    print(context:indent().."Class{")
    print(context:indent().." name = '"..self.name.."',")
    print(context:indent().." base = '"..self.base.."';")
    print(context:indent().." lname = '"..self.lname.."',")
    print(context:indent().." ctype = '"..self.ctype.."',")
    print(context:indent().." btype = '"..self.btype.."',")
end
function classClass:print_leave(context)
    print(context:indent().."}")
end


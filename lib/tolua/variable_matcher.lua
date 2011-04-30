module(..., package.seeall)

function Declaration(context, declaration)
    assert(context:is(ParseContext))
    declaration = declaration:gsub("%s*=%s*","="):gsub("%s*<", "<")

    local declarator, definition=declaration:match("^(.-)%s*=%s*(.*)$")
    if not definition then
        declarator=declaration
        definition = ''
    end

    -- check the form: void
    if declarator == '' or declarator == 'void' then
        return classVariable(
        context, '',
        {
            mod='',
            ctype='void',
            ptr='',
        })
    end

    -- check the form: mod ctype*& name
    do
        local t = declarator:split_c_tokens('%*%s*&')
        if #t == 2 then
            -- ?
            local m = t[1]:split_c_tokens('%s+')
            return classVariable(
            context, t[2],
            {
                mod = table.concat(table.splice(m,1,#m-1), ' '),
                ctype = m[#m],
                ptr = '*',
                def=definition,
                ret = '&',
            })
        end
    end

    -- check the form: mod ctype** name
    do
        local t = declarator:split_c_tokens('%*%s*%*')
        if #t == 2 then
            local m = t[1]:split_c_tokens('%s+')
            return classVariable(
            context, t[2],
            {
                mod = table.concat(table.splice(m,1,#m-1), ' '),
                ctype = m[#m],
                ptr = '*',
                ret = '*',
                def=definition,
            })
        end
    end

    -- check the form: mod ctype& name
    do
        local t = declarator:split_c_tokens('&')
        if #t == 2 then
            local m = t[1]:split_c_tokens('%s+')
            return classVariable(
            context, t[2],
            {
                mod = table.concat(table.splice(m,1,#m-1), ' '),
                ctype = m[#m],
                ptr = '&',
                def=definition,
            })
        end
    end

    -- check the form: mod ctype* name
    do
        local s1 = declarator:gsub("(%b\[\])", function (n) 
            return n:gsub('%*','\1') 
        end)
        local t = s1:split_c_tokens('%*')
        if #t == 2 then
            -- restore * in dimension expression
            t[2] = t[2]:gsub('\1','%*')
            local m = t[1]:split_c_tokens('%s+')
            return classVariable(
            context, t[2],
            {
                mod = table.concat(table.splice(m,1,#m-1), ' '),
                ctype = m[#m],
                ptr = '*',
                def=definition,
            })
        end
    end

    do
        -- check the form: mod ctype name
        local t = declarator:split_c_tokens('%s+')
        local name = table.remove(t)
        return classVariable(
        context, name,
        {
            mod = table.concat(table.splice(t, 1, #t-1), ' '),
            ctype = t[#t],
            ptr='',
            def=definition,
        })
    end
end

function Variable (context, declaration)
    local d=Declaration(context, declaration)
    setmetatable(d, classVariable)
    return d
end

matchers.variable_matcher=MultiMatcher(
    -- try variable
    {"^([_%w][_@%s%w%d%*&:<>,]*[_%w%d])%s*;", 
    function(context, decl)
        local list = decl:split_c_tokens(",")
        context:create(Variable, list[1])
        if #list > 1 then
            local _, _, ctype = list[1]:find("(.-)%s+([^%s]*)$")
            local i =2;
            while list[i] do
                context:create(Variable, ctype.." "..list[i])
                i=i+1
            end
        end
    end},
    -- try string
    {"^([_%w]?[_%s%w%d]-char%s+[_@%w%d]*%s*%[%s*%S+%s*%])%s*;", 
    function(context, decl)
        context:create(Variable, decl)
    end}
)

matchers.array_matcher=Matcher("^([_%w][][_@%s%w%d%*&:<>]*[]_%w%d])%s*;", 
function(context, decl)
    context:create(Variable, decl)
end)


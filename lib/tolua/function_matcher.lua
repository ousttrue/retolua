module(..., package.seeall)

-- table to transform operator kind into the appropriate tag method name
local _TM = {
    ['+'] = 'add',
    ['-'] = 'sub',
    ['*'] = 'mul',
    ['/'] = 'div',
    ['<'] = 'lt',
    ['<='] = 'le',
    ['=='] = 'eq',
    ['[]'] = 'geti',
    ['&[]'] = 'seti',
    --['->'] = 'flechita',
}

function create_functions(context, declarator, const, kind)
    declarator = declarator:gsub("%s*=%s*","="):gsub("%s*<", "<")

    -- check the form: mod ctype& name
    do
        local t = declarator:split_c_tokens('&')
        if #t == 2 then
            local name=t[#t]
            local m = t[1]:split_c_tokens('%s+')
            return classFunction(
            context, name,
            table.concat(table.splice(m, 1, #m-1), ' '), m[#m], '&', 
            const, kind)
        end
    end

    -- check the form: mod ctype* name
    do
        local s1 = declarator:gsub("(%b\[\])", function (n)
            return n:gsub('%*','\1')
        end)
        local t = s1:split_c_tokens('%*')
        if #t == 2 then
            local name=t[#t]
            -- restore * in dimension expression
            t[2] = t[2]:gsub('\1','%*')
            local m = t[1]:split_c_tokens('%s+')
            return classFunction(
            context, name,
            table.concat(table.splice(m, 1, #m-1), ' '), m[#m], '*', 
            const, kind)
        end
    end

    -- check the form: mod ctype name
    do
        local t = declarator:split_c_tokens('%s+')
        if #t==0 then
            error("invalid declarator!:"..declarator)
        elseif #t==1 then
            assert(context[#context]:is(classClass))
            local name=t[#t]
            local plain_name=name:gsub("%b<>", "")
            local parent_name=context[#context].name:gsub("%b<>", ""):gsub(".*::", "")

            if  plain_name==parent_name then
                local f=classFunction(
                context, 'new',
                table.concat(table.splice(t, 1, #t-2), ' '), context[#context].name, '*', 
                const, kind)
                f.constructor=true

                local f_local=classFunction(
                context, 'new_local',
                table.concat(table.splice(t, 1, #t-2), ' '), context[#context].name, '*', 
                const, kind)
                f_local.constructor=true
                f_local.owned=true

                return f, f_local

            elseif plain_name == '~'..parent_name then
                local f=classFunction(
                context, 'delete',
                table.concat(table.splice(t, 1, #t-2), ' '), '', '', 
                const, kind)
                f.destructor=true

                return f
            end
        else
            return classFunction(
            context, t[#t],
            table.concat(table.splice(t, 1, #t-2), ' '), t[#t-1], '', 
            const, kind)
        end
    end
end

-- returns true if the parameter has an object as its default value
local function has_default_value(par)
    if not string.find(par, '=') then
        return false
    end
    if string.find(par, "|") then
        -- a list of flags
        return true
    end
    if string.find(par, "%*") then
        -- it's a pointer with a default value
        if string.find(par, '=%s*new') or
            string.find(par, "%(") then
            -- it's a pointer with an instance as default parameter..
            -- is that valid?
            return true
        end
        -- default value is 'NULL' or something
        return false
    end
    if string.find(par, "[%(&]") then
        -- default value is a constructor call
        -- (most likely for a const reference)
        return true
    end
    -- ?
    return false
end

local function _Function(context, declarator, args, const, kind)
    assert(context, 'no context')
    assert(const, 'no const')
    for i, arg in ipairs(args) do
        if arg=='...' then
            error("Functions with variable arguments (`...') are not supported. Ignoring "..declarator)
        end
    end

    do
        -- find default values
        local strip=0
        for i, v in ipairs(args) do
            if has_default_value(v) then
                strip=i
                break
            end
        end

        if strip>0 then
            assert(false)
            -- add defualt argument function
            Function(context, declarator, table.splice(args, 1, strip-1), 
            const, kind)

            -- remove default values
            for i=strip, #args do
                args[i] = args[i]:gsub("=.*$", "")
            end
        end
    end

    local functions={create_functions(context, declarator, const, kind)}
    for i, f in ipairs(functions) do
        -- args
        for j, arg in ipairs(args) do
            local d=Declaration(context, arg)
            setmetatable(d, classArgument)
            table.insert(f.args, d)
        end
        if kind=='[]' then
            assert(#f.args==1 and context:isbasic(f.args[1].ctype)=='number',
            'operator[] can only be defined for numeric index.')
        end
        context:append(f)
    end

    return unpack(functions)
end

function Function(context, declarator, args, const, kind, cast)
    local f=_Function(context, declarator, args, const, kind)
    if cast then
        f.cast_operator = cast
    end
    if kind=='&[]' then
        -- ?
        local d=Declaration(context, declarator)
        setmetatable(d, classArgument)
        d.name='tolua_value'
        table.insert(f.args, d)
    end
    return f
end

matchers.operator_matcher=MultiMatcher(
    -- try operator
    {"^([_%w][_%w%s%*&:<>,]-%s+operator)%s*([^%s][^%s]*)%s*(%b())%s*(c?o?n?s?t?)%s*;",
    function(context, decl, kind, args, const)
        local self=context[#context]
        if _TM[kind] then
            -- operator
            if kind == '[]' then
                if decl:find('&') and const~='const' then
                    -- create correspoding set operator
                    Function(context,
                    decl:gsub('&', ''), args:sub(2, -2):split_c_tokens(','),
                    const, '&[]')
                end
                Function(context,
                decl:gsub('&', ''), args:sub(2, -2):split_c_tokens(','),
                const, '[]')
            else
                Function(context,
                decl, args:sub(2, -2):split_c_tokens(','), 
                const, kind)
            end
        else
            if context.flags.W then
                error("tolua: no support for operator" .. kind)
            else
                warning("No support for operator "..kind..", ignoring")
            end
        end
    end},
    -- try conversion operator
    {function(s, pos)
        local b,e,decl,kind,args,const = s:find("^%s*(operator)%s+([%w_:%d<>%*%&%s]+)%s*(%b())%s*(c?o?n?s?t?)", pos)
        if b then
            local _,ie = string.find(s, "^%s*%b{}", e+1)
            if ie then
                e = ie
            end
            return b, e, decl, kind, args, const
        end
    end,
    function(context, decl, kind, args, const)
        assert(kind~='')
        Function(context, kind.." operator", args:sub(2, -2):split_c_tokens(','), 
        const, kind, true)
    end}
)
matchers.operator_matcher.name='OperatorMatcher'

matchers.function_matcher=MultiMatcher(
    -- try function
    {"^([^%(\n]+)%s*(%b())%s*(c?o?n?s?t?)%s*(=?%s*0?)%s*;",
    function(context, declarator, args, const, virt)
        local self=context[#context]
        if virt and virt:find("[=0]") then
            if self.flags then
                self.flags.pure_virtual = true
            end
        end
        Function(context,
        declarator, args:sub(2, -2):split_c_tokens(','), const)
    end},
    -- try function with template
    {"^([~_%w][_@%w%s%*&:<>]*[_%w]%b<>)%s*(%b())%s*(c?o?n?s?t?)%s*=?%s*0?%s*;",
    function(context, declarator, args, const)
        Function(context,
        declarator, args:sub(2, -2):split_c_tokens(','), const)
    end},
    -- try a single letter function name
    {"^([_%w])%s*(%b())%s*(c?o?n?s?t?)%s*;",
    function(context, declarator, args, const)
        Function(context,
        declarator, args:sub(2, -2):split_c_tokens(','), const)
    end},
    -- try function pointer
    {"^([^%(;\n]+%b())%s*(%b())%s*;",
    function(context, declarator, args, const)
        Function(context,
        declarator:gsub("%(%s*%*([^%)]*)%s*%)", " %1 "), args:sub(2, -2):split_c_tokens(','), const)
    end},
    -- try inline function
    {"^([^%(\n]+)%s*(%b())%s*(c?o?n?s?t?)[^;{]*%b{}%s*;?",
    function(context, declarator, args, const)
        Function(context,
        declarator, args:sub(2, -2):split_c_tokens(','), const)
    end},
    -- try a single letter function name
    {"^([_%w])%s*(%b())%s*(c?o?n?s?t?).-%b{}%s*;?",
    function(context, declarator, args, const)
        Function(context,
        declarator, args:sub(2, -2):split_c_tokens(','), const)
    end}
)
matchers.function_matcher.name='FunctionMatcher'


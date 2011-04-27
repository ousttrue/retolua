module(..., package.seeall)

-- Constructor
-- Expects the name, the base (array) and the body of the class.
local function Class(context, n, p)
    local mbase
    if p then
        -- first base class
        mbase = table.remove(p, 1)
        if not p[1] then 
            p = nil 
        end
        if mbase then
            mbase = context:resolve_template_types(mbase)
        end
    end

    local oname = context:getnamespace()..n:gsub("@.*$", "")
    local c=context:get_class(oname)
    if c then
        -- found
        if mbase and ((not c.base) or c.base == "") then
            c.base = mbase
        end
        return c
    end

    -- new class
    return classClass(context, n, mbase or '', p)
end

matchers.class_matcher=Matcher(
function(s, pos)
    local b, e, name, body, base
    -- class(forward declaration)
    b, e, name = s:find("^class%s*([_%w][_%w@]*)%s*;", pos)
    if b then
        return b, e, name
    end
    -- struct(forward declaration)
    b, e, name = s:find("^struct%s*([_%w][_%w@]*)%s*;", pos)
    if b then
        return b, e, name
    end
    -- typedef struct
    b, e, body, name = s:find("^typedef%s+struct%s+[_%w]*%s*(%b{})%s*([_%w][_%w@]*)%s*;", pos)
    if b then
        return b, e, name, body
    end
    -- class
    b, e, name, base, body = s:find("^class%s*([_%w][_%w@]*)%s*([^{]-)%s*(%b{})", pos)
    -- struct(c++ style)
    if not b then
        b, e, name, base, body = s:find("^struct%s+([_%w][_%w@]*)%s*([^{]-)%s*(%b{})", pos)
    end
    -- union
    if not b then
        b, e, name, base, body = s:find("^union%s*([_%w][_%w@]*)%s*([^{]-)%s*(%b{})", pos)
    end
    -- following variable
    if b then
        varb, vare, varname = s:find("^([_%w]+)%s*;", e+1)
        if varb then
            return b, vare, name, body, base, varname
        else
            return b, e, name, body, base
        end
    end
end,
function(context, name, body, base, varname)
    if base and base ~= '' then
        -- super class
        base = base:gsub("^%s*:%s*", "")
        base = base:gsub("%s*public%s*", "")
        base = base:split(",")

        body = body:sub(1, -2)
        for i=2, #base do
            body = body.."\n tolua_inherits "..base[i].." __"..base[i].."__;\n"
        end
        body = body.."\n}"
    else
        base = {}
    end

    -- check for template
    local template_arg, template_body=body:match('^{%s*TOLUA_TEMPLATE_BIND%s*(%b())(.*)}$')
    if not template_arg then
        ------------------------------------------------------------
        -- no template class
        ------------------------------------------------------------
        local c=Class(context, name, base)
        if varname then
            context:append(Variable(context, name.." "..varname))
        end
        context:append(c)
        -- eliminate braces
        context:parse(body:sub(2, -2), c)
    else
        ------------------------------------------------------------
        -- template class
        ------------------------------------------------------------
        local template_args
        local template_params
        if template_arg:find('^%s*"') then
            -- quoted(not implemented)
        else
            template_params=template_arg:sub(2, -2):split_c_tokens(",")
            template_args={table.remove(template_params, 1)}
        end

        local iter, t, i=ipairs(template_params)
        while true do
            local params={}
            local _break=false
            for j, v in ipairs(template_args) do
                local param
                i, param=iter(t, i)
                if j==1 and not param then
                    _break=true
                    break
                end
                assert(param, "#invalid parameter count")
                table.insert(params, param)
            end
            if _break then
                break
            end

            -- replace template args
            local body = template_body
            for j, arg in ipairs(template_args) do
                body = body:gsub("([^_%w])"..arg.."([^_%w])", "%1"..params[j].."%2")
            end

            local template = "<"..table.concat(params, ",")..">"

            -- clean up
            template = template:gsub("%s*,%s*", ","):gsub(">>", "> >")
            body = body:gsub(">>", "> >")

            local c=Class(context, name..template, {})
            context:append(c)
            context:parse(body, c)
        end
    end
end)
matchers.class_matcher.name='Class'

matchers.module_matcher=Matcher("^module%s+([_%w][_%w]*)%s*(%b{})",
function(context, name, body)
    local m=context:create(classModule, name)
    context:parse(body:sub(2, -2), m)
end, 'Module')

matchers.namespace_matcher=Matcher("^namespace%s+([_%w]+)%s*(%b{})",
function(context, name, body)
    local n=context:create(classNamespace, name)
    context:parse(body:sub(2, -2), n)
end, 'Namespace')


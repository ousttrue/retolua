module(..., package.seeall)

------------------------------------------------------------------------------
-- string
------------------------------------------------------------------------------
function string:strip()
    local result=self:gsub('^%s+', '')
    result=result:gsub('%s+$', '')
    return result
end

function string:split(delemeter)
    local pos=1
    local splited={}
    local p="(.-)"..delemeter
    while pos<=#self do
        local b, e, t=self:find(p, pos)
        if not b then
            local last=self:sub(pos):strip()
            if last~='' then
                table.insert(splited, last)
            end
            break
        end
        table.insert(splited, t:strip())
        pos=e+1
    end
    return splited
end

-- splits a string using a pattern, considering the spacial cases of C code (templates, function parameters, etc)
-- pattern can't contain the '^' (as used to identify the begining of the line)
-- also strips whitespace
function string:split_c_tokens(pat)
    local tokens = {}
    local ofs = 1
    local token_begin = 1
    while ofs <= #self do
        local b, e = self:find("^"..pat, ofs)
        if b then
            table.insert(tokens, self:sub(token_begin, b-1):strip())
            token_begin = e+1
            ofs = e+1
        else
            local char = self:match("^[(<]", ofs)
            if char then
                local b, e
                if char == "(" then 
                    b, e = self:find("^%b()", ofs)
                elseif char == "<" then 
                    b, e = self:find("^%b<>", ofs)
                else
                    error("invalid char: "..char)
                end
                if not b then
                    -- unterminated block?
                    ofs = ofs+1
                else
                    ofs = e+1
                end
            else
                ofs = ofs+1
            end
        end
    end
    if token_begin<=#self then
        table.insert(tokens, self:sub(token_begin):strip())
    end
    return tokens
end


------------------------------------------------------------------------------
-- table
------------------------------------------------------------------------------
function table.map(t, f)
    local ret={}
    for k, v in pairs(t) do
        ret[k]=f(k, v)
    end
    return ret
end

function table.filteri(t, f)
    local ret={}
    for i, v in ipairs(t) do
        if f(i, v) then
            table.insert(ret, v)
        end
    end
    return ret
end

function table.mapi(t, f)
    local ret={}
    for i, v in ipairs(t) do
        table.insert(ret, f(i, v))
    end
    return ret
end

function table.any(t, f)
    for k, v in pairs(t) do
        if f(k, v) then
            return true
        end
    end
end

function table.anyi(t, f)
    for i, v in ipairs(t) do
        if f(i, v) then
            return true
        end
    end
end

function table.walk(node, f, stack, result)
    result=result or {}
    stack=stack or {}
    local co=coroutine.create(f)
    do
        local success, msg=coroutine.resume(co, stack, node, result)
        if not success then
            print(node, msg)
            error(debug.traceback(co))
        end
    end
    local status=coroutine.status(co)
    table.insert(stack, node)
    table.foreachi(node, function(i, v)
        table.walk(v, f, stack, result)
    end)
    table.remove(stack)
    if coroutine.status(co)=='suspended' then
        local success, msg=coroutine.resume(co, stack, node, result)
        if not success then
            print(node, msg)
            error(debug.traceback(co))
        end
    end
    return result
end

function table.foldi(t, acc, f)
    for i, v in ipairs(t) do
        acc=f(acc, i, v)
    end
    return acc
end

function table.join(t, sep, first, last)
    first = first or 1
    last = last or #t
    if first>last then
        return ""
    end
    local ret = ""
    for i = first, last do
        ret = ret..(i==first and "" or sep)..t[i]
    end
    return ret
end

function table.splice(t, s, e)
    local ret={}
    for i=s, e do
        local v=t[i]
        if not v then
            break
        end
        table.insert(ret, v)
    end
    return ret
end


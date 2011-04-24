------------------------------------------------------------------------------
-- texttemplate
------------------------------------------------------------------------------
local function eval_with_env(body, env, is_boolean)
    if is_boolean then
        body='( '..body..' ) and true or false'
    end
    local chunk=assert(loadstring('return '..body))
    setfenv(chunk, env)
    return chunk()
end

local function texttemplate_variable(template, env)
    template=template:gsub("<%%", "\1")
    template=template:gsub("%%>", "\2")
    local result=template:gsub("(%b\1\2)(\n?)", function(m, nl)
        local evaled=eval_with_env(m:sub(2, -2), env)
        if evaled then
            evaled=tostring(evaled):gsub("\n$", "")
            if evaled~='\n' then
                return evaled..(nl=='\n' and '\n' or '')
            end
        end
        return ''
    end)
    return result
end

function texttemplate(_template, env, level)
--print(_template)
    level=level or 0
    local g1, g2, g3, g4
    template, g1=_template:gsub("%${eachi", "\1")
    template, g2=template:gsub("%${/eachi}%s-\n?", "\2")
    template, g3=template:gsub("%${if", "\3")
    template, g4=template:gsub("%${elseif", "\4")
    template, g5=template:gsub("%${else}%s-\n?", "\5")
    template, g6=template:gsub("%${/if}%s-\n?", "\6")
--print(g1, g2)
    assert(g1==g2, _template)
    assert(g3==g6, _template)

    local result={}
    local pos=1
    while pos<=#template do
        local s, _, begin=template:find("([\1\3])", pos)
        if s then
            if s>pos then
                table.insert(result, template:sub(pos, s-1))
            end
            if begin=='\1' then
                local _, e, m=assert(template:find("^(%b\1\2)", s))
                local l, i, v, body=assert(m:match(
                "^\1%s*(%S+)%s*,%s*(%S+)%s*,%s*(%S)%s*}%s-\n?(.*)\2$"))
                table.insert(result, {'eachi', l, i, v, body})
                pos=e+1
            elseif begin=='\3' then
                local _, e, m=assert(template:find("^(%b\3\6)", s))

                -- stash nested if
                local backup={}
                m=m:sub(2, -2):gsub("(%b\3\6)", function(m)
                    table.insert(backup, m)
                    return '\7'
                end)..'\6'

                -- if block
                local blocks={}
                block_type='\3'
                for mm, next_block_type in m:gmatch("([^\4\5\6]+)([\4\5\6])") do
                    if block_type=='\3' or block_type=='\4' then
                        -- if or elseif
                        local cond, body=assert(mm:match("^([^}]+)}%s-\n?(.-)$"))
                        table.insert(blocks, {
                            cond=cond,
                            body=body
                        })
                    elseif block_type=='\5' then
                        assert(next_block_type=='\6')
                        -- else
                        local body=assert(mm:match("^(.*)$"))
                        table.insert(blocks, {
                            body=body
                        })
                    else
                        assert(false, 'not reach here')
                    end
                    block_type=next_block_type
                end
                assert(#blocks>0)

                -- restore stash
                for i, block in ipairs(blocks) do
                    block.body=block.body:gsub("\7", function()
                        return table.remove(backup, 1)
                    end)
                end
                assert(#backup==0, string.format('remain backup: %d', #backup))

                -- resutl
                table.insert(result, {'if', blocks})

                pos=e+1
            else
                assert(false, 'not reach here')
            end
        else
            table.insert(result, template:sub(pos, #template))
            pos=#template+1
        end
    end

    return table.concat(table.mapi(result, function(i, v)
        if type(v)=='string' then
            return texttemplate_variable(v, env)
        elseif v[1]=='if' then
            local blocks=v[2]
            local if_block=table.remove(blocks, 1)
            if eval_with_env(if_block.cond, env, true) then
                return texttemplate(if_block.body, env, level+1)
            end
            for i, block in ipairs(blocks) do
                if not block.cond or eval_with_env(block.cond, env, true) then
                    return texttemplate(block.body, env, level+1)
                end
            end
            return ''
        elseif v[1]=='eachi' then
            return table.concat(table.mapi(eval_with_env(v[2], env), 
            function(j, w)
                local new_env={}
                setmetatable(new_env, getmetatable(env))
                table.foreach(env, function(k, x) new_env[k]=x end)
                new_env[v[3]]=j
                new_env[v[4]]=w
                return texttemplate(v[5], new_env, level+1)
            end))
        else
            assert(false, 'not reach here')
        end
    end))
end



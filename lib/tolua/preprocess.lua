local function prep(st, _extra_parameters)
    local chunk = {'local __ret = {"\\n"}\n'}
    for line in st:lines() do
        if string.find(line, "^##") then
            table.insert(chunk, string.sub(line, 3) .. "\n")
        else
            local last = 1
            for text, expr, index in string.gfind(line, "(.-)$(%b())()") do 
                last = index
                if text ~= "" then
                    table.insert(chunk, string.format('table.insert(__ret, %q )', text))
                end
                table.insert(chunk, string.format('table.insert(__ret, %s )', expr))
            end
            table.insert(chunk, string.format('table.insert(__ret, %q)\n',
            string.sub(line, last).."\n"))
        end
    end
    table.insert(chunk, '\nreturn table.concat(__ret)\n')
    local f, e = loadstring(table.concat(chunk))
    if e then
        error("#"..e)
    end
    setmetatable(_extra_parameters, { __index = _G })
    setfenv(f, _extra_parameters)
    return f()
end

-- Parse C header file with tolua directives
-- *** Thanks to Ariel Manzur for fixing bugs in nested directives ***
local function extract_code(code, fn)
    local code = '\n$#include "'..fn..'"\n'
    code= "\n" .. code .. "\n" -- add blank lines as sentinels
    local _,e,c,t = code:find("\n([^\n]-)[Tt][Oo][Ll][Uu][Aa]_([^%s]*)[^\n]*\n")
    while e do
        t = strlower(t)
        if t == "begin" then
            _,e,c = code:find("(.-)\n[^\n]*[Tt][Oo][Ll][Uu][Aa]_[Ee][Nn][Dd][^\n]*\n", e)
            if not e then
                tolua_error("Unbalanced 'tolua_begin' directive in header file")
            end
        end
        code = code .. c .. "\n"
        _,e,c,t = code:find("\n([^\n]-)[Tt][Oo][Ll][Uu][Aa]_([^%s]*)[^\n]*\n", e)
    end
    return code
end

function get_code(fn, _extra_parameters)
    local st=io.stdin
    local ext = "pkg"
    if fn then
        st=assert(io.open(fn, "rb"))
        local _, _, ext = string.find(fn,".*%.(.*)$")
    end

    local code
    if ext == 'pkg' then
        code=prep(st, _extra_parameters)
    else
        code="\n" .. st:read('*a')
        if ext == 'h' or ext == 'hpp' then
            code=extract_code(code, fn)
        end
    end

    -- deal with include directive
    local nsubst
    repeat
        code, nsubst = string.gsub(code,'\n%s*%$(.)file%s*"(.-)"([^\n]*)\n',
        function (kind, fn, extra)
            -- $?file directive
            local _, _, ext = string.find(fn,".*%.(.*)$")
            local fp = assert(io.open(fn,'r'))
            if kind == 'p' then
                local s = prep(fp, _extra_parameters)
                fp:close()
                return s
            end
            local s = read(fp,'*a')
            fp:close(fp)
            if kind == 'c' or kind == 'h' then
                return extract_code(fn,s)
            elseif kind == 'l' then
                return "\n$[--##"..fn.."\n" .. s .. "\n$]\n"
            elseif kind == 'i' then
                local t = {code=s}
                extra = string.gsub(extra, "^%s*,%s*", "")
                local pars = extra:split_c_tokens(",")
                include_file_hook(t, fn, unpack(pars))
                return "\n\n" .. t.code
            else
                error('#Invalid include directive (use $cfile, $pfile, $lfile or $ifile)')
            end
        end)
    until nsubst==0

    -- deal with renaming directive
    repeat
        -- I don't know why this is necesary
        code,nsubst = string.gsub(code,'\n%s*%$renaming%s*(.-)%s*\n', function (r)
            appendrenaming(r)
            return "\n"
        end)
    until nsubst == 0

    return code
end

function preprocess(code)
    code='\n'..code

    -- avoid preprocessing embedded Lua code
    local L = {}
    code = string.gsub(code, "\n%s*%$%[","\1") -- deal with embedded lua code
    code = string.gsub(code, "\n%s*%$%]","\2")
    code = string.gsub(code, "(%b\1\2)", function(c)
        table.insert(L,c)
        return "\n#["..#L.."]#"
    end)
    -- avoid preprocessing embedded C code
    local C = {}
    code = string.gsub(code, "\n%s*%$%<","\3") -- deal with embedded C code
    code = string.gsub(code, "\n%s*%$%>","\4")
    code = string.gsub(code, "(%b\3\4)", function(c)
        table.insert(C,c)
        return "\n#<"..#C..">#"
    end)
    -- avoid preprocessing embedded C code
    code = string.gsub(code, "\n%s*%$%{","\5") -- deal with embedded C code
    code = string.gsub(code, "\n%s*%$%}","\6")
    code = string.gsub(code, "(%b\5\6)", function(c)
        table.insert(C,c)
        return "\n#<"..#C..">#"
    end)

    -- eliminate preprocessor directives that don't start with 'd'
    code = string.gsub(code, "\n[ \t]*#[ \t]*[^d%<%[]", "\n//")

    -- avoid preprocessing verbatim lines
    local V = {}
    code = string.gsub(code, "\n(%s*%$[^%[%]][^\n]*)", function(v)
        table.insert(V, v)
        return "\n#"..#V.."#"
    end)

    -- perform global substitution

    -- eliminate C++ comments //...
    code = string.gsub(code,"(//[^\n]*)","")
    -- eliminate C comments /*...*/
    code = string.gsub(code,"/%*","\1")
    code = string.gsub(code,"%*/","\2")
    code = string.gsub(code,"%b\1\2","")
    code = string.gsub(code,"\1","/%*")
    code = string.gsub(code,"\2","%*/")
    -- eliminate spaces beside @
    code = string.gsub(code,"%s*@%s*","@")
    -- eliminate 'inline' keyword
    code = string.gsub(code,"%s?inline(%s)","%1")
    -- eliminate 'extern' keyword
    --code = string.gsub(code,"%s?extern(%s)","%1")
    -- eliminate 'virtual' keyword
    --code = string.gsub(code,"%s?virtual(%s)","%1")
    -- eliminate 'public:' keyword
    --code = string.gsub(code,"public:","")
    -- substitute 'void*'
    code = string.gsub(code,"([^%w_])void%s*%*","%1_userdata ")
    -- substitute 'void*'
    code = string.gsub(code,"([^%w_])void%s*%*","%1_userdata ")
    -- substitute 'char*'
    code = string.gsub(code,"([^%w_])char%s*%*","%1_cstring ")
    -- substitute 'lua_State*'
    code = string.gsub(code,"([^%w_])lua_State%s*%*","%1_lstate ")

    -- restore embedded Lua code
    code = string.gsub(code,"%#%[(%d+)%]%#",function (n)
        return L[tonumber(n)]
    end)
    -- restore embedded C code
    code = string.gsub(code,"%#%<(%d+)%>%#",function (n)
        return C[tonumber(n)]
    end)
    -- restore verbatim lines
    code = string.gsub(code,"%#(%d+)%#",function (n)
        return V[tonumber(n)]
    end)

    return code
end


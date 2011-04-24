------------------------------------------------------------------------------
-- register code
------------------------------------------------------------------------------
local code_n = 1

function Code:register_enter(context)
    local env={
        code_n=code_n,
    }
    code_n = code_n +1

    -- clean Lua code
    local s=self.text
    if not context.flags['C'] then
        s = clean(self.text)
    end
    if not s then
        --print(self.text)
        error("parser error in embedded code")
    end

    -- get first line
    env.first_line=self.text:match("^([^\n\r]*)")
    if string.find(first_line, "^%s*%-%-") then
        if string.find(first_line, "^%-%-##") then
            first_line = string.gsub(first_line, "^%-%-##", "")
            if context.flags['C'] then
                s = string.gsub(s, "^%-%-##[^\n\r]*\n", "")
            end
        end
    else
        env.first_line = ""
    end

    -- pad to 16 bytes
    local npad = 16 - (#s % 16)
    local spad = ""
    for i=1,npad do
        spad = spad .. "-"
    end
    s = s..spad

    -- convert to C
    local t={n=0}
    env.b = string.gsub(s,'(.)',function (c)
        local e = ''
        t.n=t.n+1 if t.n==15 then t.n=0 e='\n'..pre..'  ' end
        return string.format('%3u,%s',string.byte(c),e)
    end
    )

    return context:texttemplate([=[

<%_%>{ /* begin embedded lua code */
<%_%> int top = lua_gettop(tolua_S);
<%_%> static const unsigned char B[] = {
<% b..string.byte(" ") %>
<%_%> };
${ if first_line and first_line ~= "" }
<%_%> tolua_dobuffer(tolua_S,(char*)B,sizeof(B),"tolua embedded: <% first_line %>");
${else}
<%_%> tolua_dobuffer(tolua_S,(char*)B,sizeof(B),"tolua: embedded Lua code <% code_n %>");
${/if}
<%_%> lua_settop(tolua_S, top);
<%_%>} /* end of embedded lua code */

]=], env)
end


local function require_with_env(name, env)
    local chunk, msg
    local replace=name:gsub("%.", "/")
    for m in package.path:gmatch("[^;]+") do
        local path=m:gsub("%?", replace)
        chunk, msg=loadfile(path)
        if chunk then
            break
        else
            print(msg)
        end
    end
    if not chunk then
        assert(false, "not found: "..name.." in "..package.path)
        return
    end
    package.loaded[name]=env
    chunk(name)
end

module(..., package.seeall)

require_with_env("lua_bind.texttemplate", _M)
require_with_env("lua_bind.generator", _M)
require_with_env("lua_bind.base", _M)
require_with_env("lua_bind.functionarg", _M)
require_with_env("lua_bind.function", _M)
require_with_env("lua_bind.staticmemberfunction", _M)
require_with_env("lua_bind.memberfunction", _M)
require_with_env("lua_bind.variable", _M)
require_with_env("lua_bind.array", _M)
require_with_env("lua_bind.module", _M)
require_with_env("lua_bind.rootmodule", _M)
require_with_env("lua_bind.class", _M)
require_with_env("lua_bind.enum", _M)
require_with_env("lua_bind.verbatim", _M)

require_with_env("lua_bind.stliterator", _M)


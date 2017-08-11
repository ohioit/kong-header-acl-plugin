local pluginName = "header-acl"

package = "kong-plugin-" .. pluginName
version = "0.0.1-1"
supported_platforms = {"linux", "macosx"}
source = {
    url = "git@github.com:ohioit/kong-" .. pluginName .. "-plugin.git"
}
description = {
    summary = "Kong Header ACL Plugin",
    detailed = [[
        Allow controlling access to a backend API by comparing request
        header values. This plugin is designed to run _after_ most kong
        access plugins before header transformations begin. This means
        it can perform ACLs on headers set _by Kong_, like
        `x-authenticated-userid` or `x-userinfo-` headers in the
        Kong UserInfo Plugin.
    ]]
}
dependencies  = {}
build = {
    type = "builtin",
    modules = {
        ["kong.plugins."..pluginName..".access"] = "kong/plugins/"..pluginName.."/access.lua",
        ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
        ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua"
    }
}

local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.header-acl.access"

local HeaderACLPlugin =  BasePlugin:extend()

function HeaderACLPlugin:new()
    HeaderACLPlugin.super.new(self, "userinfo")
end

function HeaderACLPlugin:access(conf)
    HeaderACLPlugin.super.access(self)
    access.execute(conf)
end

HeaderACLPlugin.PRIORITY = 700

return HeaderACLPlugin

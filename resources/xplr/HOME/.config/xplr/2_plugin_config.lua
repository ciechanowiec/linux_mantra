-- 2_plugin_config
local home = os.getenv("HOME")
package.path = home
.. "/.config/xplr/plugins/?/init.lua;"
.. home
.. "/.config/xplr/plugins/?.lua;"
.. package.path

commandMode = require("command-mode")
commandMode.setup()
require("icons").setup()
require("trash-cli").setup()

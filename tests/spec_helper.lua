-- Busted global helper (loaded once via .busted's `helper` option, before
-- any spec file runs). This executes in a raw Lua environment rather than
-- the DSL-wrapped environment busted gives to spec files, so busted's
-- exported globals (spy, before_each, ...) aren't available here -- pull
-- luassert directly instead.
--
-- Replaces vim.notify with a spy so plugin notifications never hit stdout
-- during a test run, while remaining inspectable through
-- test_helper.notify_spy for specs that want to assert on message/level.
local test_helper = require("test_helper")
local spy = require("luassert.spy")

test_helper.notify_spy = spy.new(function() end)
vim.notify = test_helper.notify_spy

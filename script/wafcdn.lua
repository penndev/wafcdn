local ssl = require("ssl")
local rewrite = require("rewrite")
local backend = require("backend")
local cache = require("cache")

return {
    ssl = ssl.setup,
    main = rewrite.setup,
    backaccess = backend.access,
    backhead = backend.header,
    backbody = backend.body,
    backlog = backend.log,
    cacheaccess = cache.access,
    cachehead = cache.header,
    cachelog = cache.log,
}
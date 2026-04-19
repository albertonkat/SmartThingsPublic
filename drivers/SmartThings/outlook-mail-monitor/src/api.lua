local https = require("ssl.https")
local ltn12 = require("ltn12")
local json  = require("dkjson")
local log   = require("log")

local Api = {}

local GRAPH_BASE = "https://graph.microsoft.com/v1.0"

local function get(path, token)
  local resp = {}
  local _, status = https.request({
    url     = GRAPH_BASE .. path,
    method  = "GET",
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Content-Type"]  = "application/json",
    },
    sink = ltn12.sink.table(resp),
  })
  return json.decode(table.concat(resp)), tonumber(status)
end

function Api.get_inbox(token)
  local data, status = get("/me/mailFolders/Inbox", token)
  if status == 200 and data then
    return data, nil
  end
  return nil, tostring(status)
end

return Api

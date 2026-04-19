local https  = require("ssl.https")
local ltn12  = require("ltn12")
local json   = require("dkjson")
local log    = require("log")

local Auth = {}

local DEVICE_CODE_URL = "https://login.microsoftonline.com/%s/oauth2/v2.0/devicecode"
local TOKEN_URL       = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
local SCOPE           = "Mail.Read+offline_access"

local function url_encode(str)
  return (str:gsub("([^A-Za-z0-9%-_%.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function post(url, body)
  local resp = {}
  local _, status = https.request({
    url     = url,
    method  = "POST",
    headers = {
      ["Content-Type"]   = "application/x-www-form-urlencoded",
      ["Content-Length"] = tostring(#body),
    },
    source  = ltn12.source.string(body),
    sink    = ltn12.sink.table(resp),
  })
  return json.decode(table.concat(resp)), tonumber(status)
end

function Auth.request_device_code(tenant_id, client_id)
  local url  = string.format(DEVICE_CODE_URL, tenant_id)
  local body = "client_id=" .. url_encode(client_id) .. "&scope=" .. SCOPE
  local data, status = post(url, body)
  if status == 200 and data then
    return data, nil
  end
  return nil, "HTTP " .. tostring(status)
end

function Auth.poll_for_token(tenant_id, client_id, device_code)
  local url  = string.format(TOKEN_URL, tenant_id)
  local body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code"
            .. "&device_code=" .. url_encode(device_code)
            .. "&client_id="   .. url_encode(client_id)
  local data, status = post(url, body)
  if not data then return nil, "no_response" end
  if data.access_token then return data, nil end
  return nil, data.error or "unknown"
end

function Auth.refresh(tenant_id, client_id, refresh_token)
  local url  = string.format(TOKEN_URL, tenant_id)
  local body = "grant_type=refresh_token"
            .. "&refresh_token=" .. url_encode(refresh_token)
            .. "&client_id="     .. url_encode(client_id)
            .. "&scope="         .. SCOPE
  local data, status = post(url, body)
  if data and data.access_token then return data, nil end
  return nil, (data and data.error) or ("HTTP " .. tostring(status))
end

function Auth.save_tokens(device, tokens)
  device:set_field("access_token",  tokens.access_token,  { persist = true })
  device:set_field("refresh_token", tokens.refresh_token, { persist = true })
  device:set_field("token_expiry",  os.time() + (tokens.expires_in or 3600), { persist = true })
  log.info("Tokens saved for " .. device.label)
end

function Auth.get_valid_token(device, tenant_id, client_id)
  local token   = device:get_field("access_token")
  local expiry  = device:get_field("token_expiry") or 0
  local refresh = device:get_field("refresh_token")

  if not token then return nil end

  if os.time() < expiry - 60 then
    return token
  end

  if refresh then
    local tokens, err = Auth.refresh(tenant_id, client_id, refresh)
    if tokens then
      Auth.save_tokens(device, tokens)
      return tokens.access_token
    end
    log.warn("Token refresh failed: " .. tostring(err))
  end

  return nil
end

return Auth

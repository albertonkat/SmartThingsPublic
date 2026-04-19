local Driver       = require("st.driver")
local capabilities = require("st.capabilities")
local log          = require("log")

local auth = require("auth")
local api  = require("api")

-- Set your Azure app values here or configure via environment / driver settings
local CLIENT_ID = "77b461bf-52fc-4ec3-ba96-3ebbe87dbaa9"
local TENANT_ID = "965b284f-2cd8-4846-9a56-d084bf85b90f"

local POLL_INTERVAL = 300  -- seconds (5 minutes)
local AUTH_POLL_INTERVAL = 5  -- seconds between device-code polling

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function set_contact(device, has_unread)
  if has_unread then
    device:emit_event(capabilities.contactSensor.contact.open())
  else
    device:emit_event(capabilities.contactSensor.contact.closed())
  end
end

-----------------------------------------------------------------------
-- Auth flow (Microsoft Device Authorization Grant)
-- User visits microsoft.com/devicelogin and enters the displayed code.
-----------------------------------------------------------------------

local function start_auth_flow(driver, device)
  log.info("Starting Microsoft device-code auth flow for " .. device.label)

  local code_data, err = auth.request_device_code(TENANT_ID, CLIENT_ID)
  if not code_data then
    log.error("Failed to get device code: " .. tostring(err))
    return
  end

  -- Surface the user code prominently so the user can see it in Hub logs
  log.warn("=======================================================")
  log.warn("ACTION REQUIRED to activate Outlook Mail Monitor:")
  log.warn("1. On any device, open: " .. code_data.verification_uri)
  log.warn("2. Enter code: " .. code_data.user_code)
  log.warn("=======================================================")

  -- Poll until the user completes auth or code expires
  local deadline = os.time() + (code_data.expires_in or 900)
  device.thread:call_with_delay(AUTH_POLL_INTERVAL, function()
    local function try_get_token()
      if os.time() > deadline then
        log.error("Device code expired. Re-add device to retry auth.")
        return
      end

      local tokens, poll_err = auth.poll_for_token(TENANT_ID, CLIENT_ID, code_data.device_code)
      if tokens then
        auth.save_tokens(device, tokens)
        log.info("Auth complete for " .. device.label)
        -- Immediately poll inbox after auth
        local inbox, api_err = api.get_inbox(tokens.access_token)
        if inbox then
          set_contact(device, inbox.unreadItemCount > 0)
        end
        return
      end

      if poll_err == "authorization_pending" or poll_err == "slow_down" then
        device.thread:call_with_delay(AUTH_POLL_INTERVAL, try_get_token)
      else
        log.error("Auth polling error: " .. tostring(poll_err))
      end
    end
    try_get_token()
  end)
end

-----------------------------------------------------------------------
-- Inbox polling
-----------------------------------------------------------------------

local function poll_inbox(driver, device)
  local token = auth.get_valid_token(device, TENANT_ID, CLIENT_ID)
  if not token then
    log.warn("No valid token for " .. device.label .. " — skipping poll")
    return
  end

  local inbox, err = api.get_inbox(token)
  if inbox then
    local unread = inbox.unreadItemCount or 0
    log.debug(device.label .. " unread: " .. unread)
    set_contact(device, unread > 0)
  else
    log.warn("Inbox poll failed: " .. tostring(err))
    if err == "401" then
      log.warn("Token rejected — re-run auth flow")
      device:set_field("access_token",  nil, { persist = true })
      device:set_field("refresh_token", nil, { persist = true })
    end
  end
end

-----------------------------------------------------------------------
-- Driver lifecycle handlers
-----------------------------------------------------------------------

local function device_added(driver, device)
  log.info("Device added: " .. device.label)
  set_contact(device, false)

  if not device:get_field("access_token") then
    start_auth_flow(driver, device)
  end

  -- Schedule recurring poll
  device.thread:call_on_schedule(POLL_INTERVAL, function()
    poll_inbox(driver, device)
  end, "poll_inbox")
end

local function device_init(driver, device)
  log.info("Device init: " .. device.label)
  -- Schedule recurring poll (restores schedule after Hub restart)
  device.thread:call_on_schedule(POLL_INTERVAL, function()
    poll_inbox(driver, device)
  end, "poll_inbox")
  -- Run once immediately on init
  poll_inbox(driver, device)
end

local function device_removed(driver, device)
  log.info("Device removed: " .. device.label)
end

-----------------------------------------------------------------------
-- Capability command handlers
-----------------------------------------------------------------------

local function handle_refresh(driver, device, command)
  log.info("Manual refresh for " .. device.label)
  poll_inbox(driver, device)
end

-----------------------------------------------------------------------
-- Driver definition
-----------------------------------------------------------------------

local outlook_driver = Driver("outlook-mail-monitor", {
  lifecycle_handlers = {
    added   = device_added,
    init    = device_init,
    removed = device_removed,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
  },
})

outlook_driver:run()

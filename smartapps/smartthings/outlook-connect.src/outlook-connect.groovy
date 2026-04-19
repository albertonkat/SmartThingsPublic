/**
 *  Copyright 2015 SmartThings
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License. You may obtain a copy of the License at:
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *  for the specific language governing permissions and limitations under the License.
 *
 *  Outlook (Connect)
 *
 *  Author: SmartThings
 *  Date: 2015-01-01
 */

include 'localization'

definition(
        name: "Outlook (Connect)",
        namespace: "smartthings",
        author: "SmartThings",
        description: "Connect your Microsoft Outlook account to SmartThings.",
        category: "SmartThings Labs",
        iconUrl: "https://s3.amazonaws.com/smartapp-icons/Partner/outlook.png",
        iconX2Url: "https://s3.amazonaws.com/smartapp-icons/Partner/outlook@2x.png",
        singleInstance: true,
        usesThirdPartyAuthentication: true,
        pausable: false
) {
    appSetting "clientId"
    appSetting "clientSecret"
    appSetting "tenantId"
}

preferences {
    page(name: "auth", title: "Outlook", nextPage: "", content: "authPage", uninstall: true, install: true)
}

mappings {
    path("/oauth/initialize") {action: [GET: "oauthInitUrl"]}
    path("/oauth/callback") {action: [GET: "callback"]}
}

def authPage() {
    log.debug "authPage()"

    if (!atomicState.accessToken) {
        atomicState.accessToken = createAccessToken()
    }

    def description
    def uninstallAllowed = false
    def oauthTokenProvided = false

    if (atomicState.authToken) {
        description = "You are connected."
        uninstallAllowed = true
        oauthTokenProvided = true
    } else {
        description = "Click to enter Microsoft Outlook credentials"
    }

    def redirectUrl = buildRedirectUrl
    log.debug "RedirectUrl = ${redirectUrl}"

    if (!oauthTokenProvided) {
        return dynamicPage(name: "auth", title: "Login", nextPage: "", uninstall: uninstallAllowed) {
            section() {
                paragraph "Tap below to log in to your Microsoft account and authorize SmartThings access to your Outlook inbox."
                href url: redirectUrl, style: "embedded", required: true, title: "Microsoft Outlook", description: description
            }
        }
    } else {
        def inboxes = getOutlookMailFolders()
        log.debug "Outlook mail folders: $inboxes"
        return dynamicPage(name: "auth", title: "Select Mail Folders to Monitor", uninstall: true) {
            section("") {
                paragraph "Tap below to select which Outlook mail folders SmartThings should monitor for new messages."
                input(name: "selectedFolders", title: "Select Mail Folders ({{numFound}} found)", messageArgs: [numFound: inboxes.size()],
                    type: "enum", required: true, multiple: true, description: "Tap to choose", metadata: [values: inboxes])
            }
        }
    }
}

def oauthInitUrl() {
    log.debug "oauthInitUrl with callback: ${callbackUrl}"

    atomicState.oauthInitState = UUID.randomUUID().toString()

    def oauthParams = [
        response_type: "code",
        scope        : "Mail.Read offline_access",
        client_id    : appSettings.clientId,
        state        : atomicState.oauthInitState,
        redirect_uri : callbackUrl
    ]

    redirect(location: "${apiEndpoint}/authorize?${toQueryString(oauthParams)}")
}

def callback() {
    log.debug "callback()>> params: $params, params.code ${params.code}"

    def code = params.code
    def oauthState = params.state

    if (oauthState == atomicState.oauthInitState) {
        def tokenParams = [
            grant_type   : "authorization_code",
            code         : code,
            client_id    : appSettings.clientId,
            client_secret: appSettings.clientSecret,
            redirect_uri : callbackUrl
        ]

        httpPost(uri: tokenEndpoint, body: tokenParams) { resp ->
            atomicState.refreshToken = resp.data.refresh_token
            atomicState.authToken = resp.data.access_token
            atomicState.tokenExpiry = now() + (resp.data.expires_in * 1000)
        }

        if (atomicState.authToken) {
            success()
        } else {
            fail()
        }
    } else {
        log.error "callback() failed: oauthState != atomicState.oauthInitState"
    }
}

def success() {
    def message = """
        <p>Your Microsoft Outlook account is now connected to SmartThings!</p>
        <p>Click 'Done' to finish setup.</p>
    """
    connectionStatus(message)
}

def fail() {
    def message = """
        <p>The connection could not be established!</p>
        <p>Click 'Done' to return to the menu.</p>
    """
    connectionStatus(message)
}

def connectionStatus(message, redirectUrl = null) {
    def redirectHtml = ""
    if (redirectUrl) {
        redirectHtml = """
            <meta http-equiv="refresh" content="3; url=${redirectUrl}" />
        """
    }

    def html = """
        <!DOCTYPE html>
        <html>
            <head>
                <meta name="viewport" content="width=640">
                <title>Outlook &amp; SmartThings connection</title>
                <style type="text/css">
                    @font-face {
                        font-family: 'Swiss 721 W01 Thin';
                        src: url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-thin-webfont.eot');
                        src: url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-thin-webfont.eot?#iefix') format('embedded-opentype'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-thin-webfont.woff') format('woff'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-thin-webfont.ttf') format('truetype'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-thin-webfont.svg#swis721_th_btthin') format('svg');
                        font-weight: normal;
                        font-style: normal;
                    }
                    @font-face {
                        font-family: 'Swiss 721 W01 Light';
                        src: url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-light-webfont.eot');
                        src: url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-light-webfont.eot?#iefix') format('embedded-opentype'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-light-webfont.woff') format('woff'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-light-webfont.ttf') format('truetype'),
                        url('https://s3.amazonaws.com/smartapp-icons/Partner/fonts/swiss-721-light-webfont.svg#swis721_lt_btlight') format('svg');
                        font-weight: normal;
                        font-style: normal;
                    }
                    .container {
                        width: 90%;
                        padding: 4%;
                        text-align: center;
                    }
                    img {
                        vertical-align: middle;
                    }
                    p {
                        font-size: 2.2em;
                        font-family: 'Swiss 721 W01 Thin';
                        text-align: center;
                        color: #666666;
                        padding: 0 40px;
                        margin-bottom: 0;
                    }
                    span {
                        font-family: 'Swiss 721 W01 Light';
                    }
                </style>
            </head>
        <body>
            <div class="container">
                <img src="https://s3.amazonaws.com/smartapp-icons/Partner/outlook%402x.png" alt="Outlook icon" />
                <img src="https://s3.amazonaws.com/smartapp-icons/Partner/support/connected-device-icn%402x.png" alt="connected device icon" />
                <img src="https://s3.amazonaws.com/smartapp-icons/Partner/support/st-logo%402x.png" alt="SmartThings logo" />
                ${message}
            </div>
        </body>
    </html>
    """

    render contentType: 'text/html', data: html
}

def getOutlookMailFolders() {
    log.debug "getOutlookMailFolders()"

    def folders = [:]
    def params = [
        uri    : graphEndpoint,
        path   : "/me/mailFolders",
        headers: ["Authorization": "Bearer ${atomicState.authToken}", "Content-Type": "application/json"]
    ]

    try {
        httpGet(params) { resp ->
            if (resp.status == 200) {
                resp.data.value.each { folder ->
                    def dni = [app.id, folder.id].join('.')
                    folders[dni] = folder.displayName
                }
            } else {
                log.debug "http status: ${resp.status}"
            }
        }
    } catch (groovyx.net.http.HttpResponseException e) {
        log.trace "Exception getting mail folders: " + e.response.data
        if (e.statusCode == 401) {
            atomicState.action = "getOutlookMailFolders"
            log.debug "Refreshing auth token!"
            refreshAuthToken()
        }
    }

    atomicState.folders = folders
    return folders
}

def installed() {
    log.debug "Installed with settings: ${settings}"
    initialize()
}

def updated() {
    log.debug "Updated with settings: ${settings}"
    unsubscribe()
    initialize()
}

def initialize() {
    log.debug "initialize"

    def devices = selectedFolders.collect { dni ->
        def d = getChildDevice(dni)
        if (!d) {
            d = addChildDevice(app.namespace, getChildName(), dni, null,
                ["label": "${atomicState.folders[dni]}" ?: "Outlook Inbox"])
            log.debug "created ${d.displayName} with id $dni"
        } else {
            log.debug "found ${d.displayName} with id $dni"
        }
        return d
    }

    def delete = selectedFolders ?
        getChildDevices().findAll { !selectedFolders.contains(it.deviceNetworkId) } :
        getAllChildDevices()

    log.warn "deleting ${delete.size()} devices"
    delete.each { deleteChildDevice(it.deviceNetworkId) }

    def notificationMessage = "is connected to SmartThings"
    sendActivityFeeds(notificationMessage)
    atomicState.reAttempt = 0

    pollHandler()
    runEvery5Minutes("poll")
}

def pollHandler() {
    log.debug "pollHandler()"
    pollChildren()
}

def pollChildren() {
    log.debug "pollChildren()"

    if (!atomicState.authToken) {
        log.warn "No auth token, skipping poll"
        return false
    }

    if (atomicState.tokenExpiry && now() > atomicState.tokenExpiry - 60000) {
        log.debug "Token near expiry, refreshing"
        refreshAuthToken()
    }

    def result = false
    def folderIds = selectedFolders?.collect { it.split(/\./).last() }

    folderIds?.each { folderId ->
        def params = [
            uri    : graphEndpoint,
            path   : "/me/mailFolders/${folderId}",
            headers: ["Authorization": "Bearer ${atomicState.authToken}", "Content-Type": "application/json"]
        ]

        try {
            httpGet(params) { resp ->
                if (resp.status == 200) {
                    def folder = resp.data
                    def dni = [app.id, folderId].join('.')
                    def d = getChildDevice(dni)
                    if (d) {
                        d.sendEvent(name: "unreadCount", value: folder.unreadItemCount)
                        d.sendEvent(name: "totalCount", value: folder.totalItemCount)
                        d.sendEvent(name: "contact", value: folder.unreadItemCount > 0 ? "open" : "closed")
                        log.debug "Updated ${d.displayName}: ${folder.unreadItemCount} unread"
                    }
                    result = true
                }
            }
        } catch (groovyx.net.http.HttpResponseException e) {
            log.trace "Exception polling folder ${folderId}: " + e.response.data
            if (e.statusCode == 401) {
                atomicState.action = "pollChildren"
                log.debug "Refreshing auth token!"
                refreshAuthToken()
            }
        }
    }

    return result
}

void poll() {
    pollChildren()
}

private refreshAuthToken() {
    log.debug "refreshing auth token"

    if (!atomicState.refreshToken) {
        log.warn "Cannot refresh OAuth token: no refresh token stored"
        return
    }

    def refreshParams = [
        uri : tokenEndpoint,
        body: [
            grant_type   : "refresh_token",
            refresh_token: atomicState.refreshToken,
            client_id    : appSettings.clientId,
            client_secret: appSettings.clientSecret,
            scope        : "Mail.Read offline_access"
        ]
    ]

    def notificationMessage = "is disconnected from SmartThings, because the access credential changed or was lost. Please go to the Outlook (Connect) SmartApp and re-enter your account login credentials."

    try {
        httpPost(refreshParams) { resp ->
            if (resp.status == 200) {
                log.debug "Token refreshed successfully"
                saveTokenAndResumeAction(resp.data)
            }
        }
    } catch (groovyx.net.http.HttpResponseException e) {
        log.error "refreshAuthToken() >> Error: e.statusCode ${e.statusCode}"
        def reAttemptPeriod = 300
        if (e.statusCode != 401) {
            runIn(reAttemptPeriod, "refreshAuthToken")
        } else {
            atomicState.reAttempt = (atomicState.reAttempt ?: 0) + 1
            log.warn "reAttempt refreshAuthToken count = ${atomicState.reAttempt}"
            if (atomicState.reAttempt <= 3) {
                runIn(reAttemptPeriod, "refreshAuthToken")
            } else {
                sendPushAndFeeds(notificationMessage)
                atomicState.reAttempt = 0
            }
        }
    }
}

private void saveTokenAndResumeAction(json) {
    log.debug "token response json: $json"
    if (json) {
        atomicState.refreshToken = json?.refresh_token
        atomicState.authToken = json?.access_token
        atomicState.tokenExpiry = now() + ((json?.expires_in ?: 3600) * 1000)
        if (atomicState.action) {
            log.debug "got refresh token, executing next action: ${atomicState.action}"
            "${atomicState.action}"()
        }
    } else {
        log.warn "did not get response body from token refresh"
    }
    atomicState.action = ""
}

def sendPushAndFeeds(notificationMessage) {
    log.warn "sendPushAndFeeds >> notificationMessage: ${notificationMessage}"
    if (atomicState.timeSendPush) {
        if (now() - atomicState.timeSendPush > 86400000) {
            sendPush("Your Outlook account " + notificationMessage)
            sendActivityFeeds(notificationMessage)
            atomicState.timeSendPush = now()
        }
    } else {
        sendPush("Your Outlook account " + notificationMessage)
        sendActivityFeeds(notificationMessage)
        atomicState.timeSendPush = now()
    }
    atomicState.authToken = null
}

def sendActivityFeeds(notificationMessage) {
    def devices = getChildDevices()
    devices.each { child ->
        child.generateActivityFeedsEvent(notificationMessage)
    }
}

def toQueryString(Map m) {
    return m.collect { k, v -> "${k}=${URLEncoder.encode(v.toString())}" }.sort().join("&")
}

def getChildName()      { return "Outlook Inbox" }
def getServerUrl()      { return "https://graph.api.smartthings.com" }
def getShardUrl()       { return getApiServerUrl() }
def getCallbackUrl()    { return "https://graph.api.smartthings.com/oauth/callback" }
def getBuildRedirectUrl() { return "${serverUrl}/oauth/initialize?appId=${app.id}&access_token=${atomicState.accessToken}&apiServerUrl=${shardUrl}" }
def getApiEndpoint()    { return "https://login.microsoftonline.com/${appSettings.tenantId}/oauth2/v2.0" }
def getTokenEndpoint()  { return "https://login.microsoftonline.com/${appSettings.tenantId}/oauth2/v2.0/token" }
def getGraphEndpoint()  { return "https://graph.microsoft.com/v1.0" }

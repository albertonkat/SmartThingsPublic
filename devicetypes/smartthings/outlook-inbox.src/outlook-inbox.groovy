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
 *  Outlook Inbox
 *
 *  Author: SmartThings
 *  Date: 2015-01-01
 */

metadata {
    definition(name: "Outlook Inbox", namespace: "smartthings", author: "SmartThings") {
        capability "Contact Sensor"
        capability "Sensor"
        capability "Refresh"
        capability "Polling"

        attribute "unreadCount", "number"
        attribute "totalCount", "number"
        attribute "folderName", "string"

        command "generateActivityFeedsEvent"
    }

    simulator {
        status "has unread mail": "contact:open"
        status "no unread mail": "contact:closed"
    }

    tiles {
        standardTile("contact", "device.contact", width: 2, height: 2) {
            state("open", label: "Unread Mail", icon: "st.contact.contact.open",
                backgroundColor: "#e86d13")
            state("closed", label: "No New Mail", icon: "st.contact.contact.closed",
                backgroundColor: "#00a0dc")
        }

        valueTile("unreadCount", "device.unreadCount", decoration: "flat") {
            state "default", label: 'Unread\n${currentValue}'
        }

        valueTile("totalCount", "device.totalCount", decoration: "flat") {
            state "default", label: 'Total\n${currentValue}'
        }

        standardTile("refresh", "device.contact", inactiveLabel: false, decoration: "flat") {
            state "default", action: "refresh.refresh", icon: "st.secondary.refresh"
        }

        main "contact"
        details(["contact", "unreadCount", "totalCount", "refresh"])
    }
}

def installed() {
    log.trace "Outlook Inbox installed"
    sendEvent(name: "contact", value: "closed")
    sendEvent(name: "unreadCount", value: 0)
    sendEvent(name: "totalCount", value: 0)
}

def updated() {
    log.trace "Outlook Inbox updated"
}

def poll() {
    log.debug "poll() - requesting parent refresh"
    parent.pollChildren()
}

def refresh() {
    log.debug "refresh() - requesting parent refresh"
    parent.pollChildren()
}

def generateActivityFeedsEvent(notificationMessage) {
    sendEvent(name: "notificationMessage",
        value: "${device.displayName} ${notificationMessage}",
        descriptionText: "${device.displayName} ${notificationMessage}",
        isStateChange: true)
}

// Copyright © 2022 Beldex International. All rights reserved.

import SignalUtilitiesKit
import UserNotifications

public class NSENotificationPresenter: NSObject, NotificationsProtocol {
    
    private var notifications: [String: UNNotificationRequest] = [:]
    
    public func notifyUser(for incomingMessage: TSIncomingMessage, in thread: TSThread, transaction: YapDatabaseReadTransaction) {
        guard !thread.isMuted else { return }
        guard let threadID = thread.uniqueId else { return }
        
        // If the thread is a message request and the user hasn't hidden message requests then we need
        // to check if this is the only message request thread (group threads can't be message requests
        // so just ignore those and if the user has hidden message requests then we want to show the
        // notification regardless of how many message requests there are)
        if !thread.isGroupThread() && thread.isMessageRequest(using: transaction) && !CurrentAppContext().appUserDefaults()[.hasHiddenMessageRequests] {
            let threads = transaction.ext(TSThreadDatabaseViewExtensionName) as! YapDatabaseViewTransaction
            let numMessageRequests = threads.numberOfItems(inGroup: TSMessageRequestGroup)
            
            // Allow this to show a notification if there are no message requests (ie. this is the first one)
            guard numMessageRequests == 0 else { return }
        }
        else if thread.isMessageRequest(using: transaction) && CurrentAppContext().appUserDefaults()[.hasHiddenMessageRequests] {
            // If there are other interactions on this thread already then don't show the notification
            if thread.numberOfInteractions(with: transaction) > 1 { return }
            
            CurrentAppContext().appUserDefaults()[.hasHiddenMessageRequests] = false
        }
        
        let senderPublicKey = incomingMessage.authorId
        let userPublicKey = GeneralUtilities.getUserPublicKey()
        guard senderPublicKey != userPublicKey else {
            // Ignore PNs for messages sent by the current user
            // after handling the message. Otherwise the closed
            // group self-send messages won't show.
            return
        }
        
        let identifier = incomingMessage.notificationIdentifier ?? UUID().uuidString
        let isBackgroudPoll = identifier == threadID
        
        let context = Contact.context(for: thread)
        let senderName = Storage.shared.getContact(with: senderPublicKey, using: transaction)?.displayName(for: context) ?? senderPublicKey
        
        var notificationTitle = senderName
        if let group = thread as? TSGroupThread {
            if group.isOnlyNotifyingForMentions && !incomingMessage.isUserMentioned {
                // Ignore PNs if the group is set to only notify for mentions
                return
            }
            
            var groupName = thread.name(with: transaction)
            if groupName.count < 1 {
                groupName = MessageStrings.newGroupDefaultTitle
            }
            notificationTitle = isBackgroudPoll ? groupName : String(format: NotificationStrings.incomingGroupMessageTitleFormat, senderName, groupName)
        }
        
        let snippet = incomingMessage.previewText(with: transaction).filterForDisplay?.replacingMentions(for: threadID, using: transaction)
        ?? "APN_Message".localized()
        
        var userInfo: [String:Any] = [ NotificationServiceExtension.isFromRemoteKey : true ]
        userInfo[NotificationServiceExtension.threadIdKey] = threadID
        
        let notificationContent = UNMutableNotificationContent()
        notificationContent.userInfo = userInfo
        notificationContent.sound = OWSSounds.notificationSound(for: thread).notificationSound(isQuiet: false)
        
        // Badge Number
        let newBadgeNumber = CurrentAppContext().appUserDefaults().integer(forKey: "currentBadgeNumber") + 1
        notificationContent.badge = NSNumber(value: newBadgeNumber)
        CurrentAppContext().appUserDefaults().set(newBadgeNumber, forKey: "currentBadgeNumber")
        
        // Title & body
        let notificationsPreference = Environment.shared.preferences!.notificationPreviewType()
        switch notificationsPreference {
        case .namePreview:
            notificationContent.title = notificationTitle
            notificationContent.body = snippet
        case .nameNoPreview:
            notificationContent.title = notificationTitle
            notificationContent.body = NotificationStrings.incomingMessageBody
        case .noNameNoPreview:
            notificationContent.title = "BChat"
            notificationContent.body = NotificationStrings.incomingMessageBody
        default: break
        }
        
        // If it's a message request then overwrite the body to be something generic (only show a notification
        // when receiving a new message request if there aren't any others or the user had hidden them)
        if thread.isMessageRequest(using: transaction) {
            notificationContent.title = "BChat"
            notificationContent.body = "MESSAGE_REQUESTS_NOTIFICATION".localized()
        }
        
        // Add request
        let trigger: UNNotificationTrigger?
        if isBackgroudPoll {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let numberOfNotifications: Int
            if let lastRequest = notifications[identifier], let counter = lastRequest.content.userInfo[NotificationServiceExtension.threadNotificationCounter] as? Int  {
                numberOfNotifications = counter + 1
                notificationContent.body = String(format: NotificationStrings.incomingCollapsedMessagesBody, "\(numberOfNotifications)")
            } else {
                numberOfNotifications = 1
            }
            notificationContent.userInfo[NotificationServiceExtension.threadNotificationCounter] = numberOfNotifications
        } else {
            trigger = nil
        }

        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: trigger)
        SNLog("Add remote notification request: \(notificationContent.body)")
        let semaphore = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                SNLog("Failed to add notification request due to error:\(error)")
            }
            self.notifications[identifier] = request
            semaphore.signal()
        }
        semaphore.wait()
        SNLog("Finish adding remote notification request")
    }
    
    public func notifyUser(forIncomingCall callInfoMessage: TSInfoMessage, in thread: TSThread, transaction: YapDatabaseReadTransaction) {
        guard !thread.isMuted else { return }
        guard !thread.isGroupThread() else { return } // Calls shouldn't happen in groups
        guard let threadID = thread.uniqueId else { return }
        guard [ .missed, .permissionDenied ].contains(callInfoMessage.callState) else { return } // Only notify missed call
        
        var userInfo: [String:Any] = [ NotificationServiceExtension.isFromRemoteKey : true ]
        userInfo[NotificationServiceExtension.threadIdKey] = threadID
        
        let notificationContent = UNMutableNotificationContent()
        notificationContent.userInfo = userInfo
        notificationContent.sound = OWSSounds.notificationSound(for: thread).notificationSound(isQuiet: false)
        
        // Badge Number
        let newBadgeNumber = CurrentAppContext().appUserDefaults().integer(forKey: "currentBadgeNumber") + 1
        notificationContent.badge = NSNumber(value: newBadgeNumber)
        CurrentAppContext().appUserDefaults().set(newBadgeNumber, forKey: "currentBadgeNumber")
        
        notificationContent.title = callInfoMessage.previewText(with: transaction)
        notificationContent.body = ""
        if callInfoMessage.callState == .permissionDenied {
            notificationContent.body = String(format: "modal_call_missed_tips_explanation".localized(), thread.name(with: transaction))
        }
        
        // Add request
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)
        SNLog("Add remote notification request: \(notificationContent.body)")
        let semaphore = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                SNLog("Failed to add notification request due to error:\(error)")
            }
            semaphore.signal()
        }
        semaphore.wait()
        SNLog("Finish adding remote notification request")
    }
    
    public func cancelNotification(_ identifier: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [ identifier ])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [ identifier ])
    }
    
    public func clearAllNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}

private extension String {
    
    func replacingMentions(for threadID: String, using transaction: YapDatabaseReadTransaction) -> String {
        var result = self
        let regex = try! NSRegularExpression(pattern: "@[0-9a-fA-F]{66}", options: [])
        var mentions: [(range: NSRange, publicKey: String)] = []
        var m0 = regex.firstMatch(in: result, options: .withoutAnchoringBounds, range: NSRange(location: 0, length: result.utf16.count))
        while let m1 = m0 {
            let publicKey = String((result as NSString).substring(with: m1.range).dropFirst()) // Drop the @
            var matchEnd = m1.range.location + m1.range.length
            let displayName = Storage.shared.getContact(with: publicKey, using: transaction)?.displayName(for: .regular)
            if let displayName = displayName {
                result = (result as NSString).replacingCharacters(in: m1.range, with: "@\(displayName)")
                mentions.append((range: NSRange(location: m1.range.location, length: displayName.utf16.count + 1), publicKey: publicKey)) // + 1 to include the @
                matchEnd = m1.range.location + displayName.utf16.count
            }
            m0 = regex.firstMatch(in: result, options: .withoutAnchoringBounds, range: NSRange(location: matchEnd, length: result.utf16.count - matchEnd))
        }
        return result
    }
}


//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import <BChatMessagingKit/OWSReadTracking.h>
#import <BChatMessagingKit/TSMessage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSInfoMessage : TSMessage <OWSReadTracking>

typedef NS_ENUM(NSInteger, TSInfoMessageType) {
    TSInfoMessageTypeGroupCreated,
    TSInfoMessageTypeGroupUpdated,
    TSInfoMessageTypeGroupCurrentUserLeft,
    TSInfoMessageTypeDisappearingMessagesUpdate,
    TSInfoMessageTypeScreenshotNotification,
    TSInfoMessageTypeMediaSavedNotification,
    TSInfoMessageTypeCall,
    TSInfoMessageTypeMessageRequestAccepted = 99 // Avoid conficts wit TSInfoMessageTypeCall
};

typedef NS_ENUM(NSInteger, TSInfoMessageCallState) {
    TSInfoMessageCallStateIncoming,
    TSInfoMessageCallStateOutgoing,
    TSInfoMessageCallStateMissed,
    TSInfoMessageCallStatePermissionDenied,
    TSInfoMessageCallStateUnknown
};

@property (atomic, readonly) TSInfoMessageType messageType;
@property (atomic, nullable) NSString *customMessage;
@property (atomic, readonly, nullable) NSString *unregisteredRecipientId;
@property (atomic) TSInfoMessageCallState callState;

- (instancetype)initMessageWithTimestamp:(uint64_t)timestamp
                                inThread:(nullable TSThread *)thread
                             messageBody:(nullable NSString *)body
                           attachmentIds:(NSArray<NSString *> *)attachmentIds
                        expiresInSeconds:(uint32_t)expiresInSeconds
                         expireStartedAt:(uint64_t)expireStartedAt
                           quotedMessage:(nullable TSQuotedMessage *)quotedMessage
                            contactShare:(nullable OWSContact *)contact
                             linkPreview:(nullable OWSLinkPreview *)linkPreview NS_UNAVAILABLE;

- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(TSThread *)contact
                      messageType:(TSInfoMessageType)infoMessage NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(TSThread *)thread
                      messageType:(TSInfoMessageType)infoMessage
                    customMessage:(NSString *)customMessage;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(TSThread *)thread
                      messageType:(TSInfoMessageType)infoMessage
          unregisteredRecipientId:(NSString *)unregisteredRecipientId;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(nullable TSThread *)thread
                      messageBody:(nullable NSString *)body
                    attachmentIds:(NSArray<NSString *> *)attachmentIds
                 expiresInSeconds:(uint32_t)expiresInSeconds
                  expireStartedAt:(uint64_t)expireStartedAt NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

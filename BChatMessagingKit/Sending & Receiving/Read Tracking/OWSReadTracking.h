//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YapDatabaseReadWriteTransaction;

/**
 * Some interactions track read/unread status.
 * e.g. incoming messages and call notifications
 */
@protocol OWSReadTracking <NSObject>

/**
 * Has the local user seen the interaction?
 */
@property (nonatomic, readonly, getter=wasRead) BOOL read;

@property (nonatomic, readonly) uint64_t expireStartedAt;
@property (nonatomic, readonly) uint64_t sortId;
@property (nonatomic, readonly) NSString *uniqueThreadId;

- (BOOL)shouldAffectUnreadCounts;

/**
 * Used both for *responding* to a remote read receipt and in response to the local user's activity.
 */
- (void)markAsReadAtTimestamp:(uint64_t)readTimestamp
           trySendReadReceipt:(BOOL)trySendReadReceipt
                  transaction:(YapDatabaseReadWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END

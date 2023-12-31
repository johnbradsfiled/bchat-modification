//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSResaveCollectionDBMigration.h"
#import <YapDatabase/YapDatabaseConnection.h>
#import <YapDatabase/YapDatabaseTransaction.h>
#import <SignalUtilitiesKit/SignalUtilitiesKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSResaveCollectionDBMigration

- (void)resaveDBCollection:(NSString *)collection
                    filter:(nullable DBRecordFilterBlock)filter
              dbConnection:(YapDatabaseConnection *)dbConnection
                completion:(OWSDatabaseMigrationCompletion)completion
{
    OWSAssertDebug(collection.length > 0);
    OWSAssertDebug(dbConnection);
    OWSAssertDebug(completion);

    NSMutableArray<NSString *> *recordIds = [NSMutableArray new];
    [LKStorage writeWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
        [recordIds addObjectsFromArray:[transaction allKeysInCollection:collection]];
        OWSLogInfo(@"Migrating %lu records from: %@.", (unsigned long)recordIds.count, collection);
    }
    completion:^{
        [self resaveBatch:recordIds
               collection:collection
                   filter:filter
             dbConnection:dbConnection
               completion:completion];
    }];
}

- (void)resaveBatch:(NSMutableArray<NSString *> *)recordIds
         collection:(NSString *)collection
             filter:(nullable DBRecordFilterBlock)filter
       dbConnection:(YapDatabaseConnection *)dbConnection
         completion:(OWSDatabaseMigrationCompletion)completion
{
    OWSAssertDebug(recordIds);
    OWSAssertDebug(collection.length > 0);
    OWSAssertDebug(dbConnection);
    OWSAssertDebug(completion);

    OWSLogVerbose(@"%lu", (unsigned long)recordIds.count);

    if (recordIds.count < 1) {
        completion(true, false);
        return;
    }

    [LKStorage writeWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
        const int kBatchSize = 1000;
        for (int i = 0; i < kBatchSize && recordIds.count > 0; i++) {
            NSString *messageId = [recordIds lastObject];
            [recordIds removeLastObject];
            id record = [transaction objectForKey:messageId inCollection:collection];
            if (filter && !filter(record)) {
                continue;
            }
            TSYapDatabaseObject *entity = (TSYapDatabaseObject *)record;
            [entity saveWithTransaction:transaction];
        }
    }
    completion:^{
        // Process the next batch.
        [self resaveBatch:recordIds
               collection:collection
                   filter:filter
             dbConnection:dbConnection
               completion:completion];
    }];
}

@end

NS_ASSUME_NONNULL_END

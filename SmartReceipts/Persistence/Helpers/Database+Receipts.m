//
//  Database+Receipts.m
//  SmartReceipts
//
//  Created by Jaanus Siim on 06/05/15.
//  Copyright (c) 2015 Will Baumann. All rights reserved.
//

#import <FMDB/FMDatabase.h>
#import "Database+Receipts.h"
#import "DatabaseTableNames.h"
#import "Database+Functions.h"
#import "WBReceipt.h"
#import "DatabaseQueryBuilder.h"
#import "WBTrip.h"
#import "WBCurrency.h"
#import "WBPrice.h"
#import "FetchedModelAdapter.h"
#import "WBPreferences.h"
#import "Database+Trips.h"
#import "Database+PaymentMethods.h"
#import "PaymentMethod.h"

@implementation Database (Receipts)

- (BOOL)createReceiptsTable {
    NSArray *createReceiptsTable = @[
            @"CREATE TABLE ", ReceiptsTable.TABLE_NAME, @" (",
            ReceiptsTable.COLUMN_ID, @" INTEGER PRIMARY KEY AUTOINCREMENT, ",
            ReceiptsTable.COLUMN_PATH, @" TEXT, ",
            ReceiptsTable.COLUMN_PARENT, @" TEXT REFERENCES ", TripsTable.TABLE_NAME, @" ON DELETE CASCADE, ",
            ReceiptsTable.COLUMN_NAME, @" TEXT DEFAULT \"New Receipt\", ",
            ReceiptsTable.COLUMN_CATEGORY, @" TEXT, ",
            ReceiptsTable.COLUMN_DATE, @" DATE DEFAULT (DATE('now', 'localtime')), ",
            ReceiptsTable.COLUMN_TIMEZONE, @" TEXT, ",
            ReceiptsTable.COLUMN_COMMENT, @" TEXT, ",
            ReceiptsTable.COLUMN_ISO4217, @" TEXT NOT NULL, ",
            ReceiptsTable.COLUMN_PRICE, @" DECIMAL(10, 2) DEFAULT 0.00, ",
            ReceiptsTable.COLUMN_TAX, @" DECIMAL(10, 2) DEFAULT 0.00, ",
            ReceiptsTable.COLUMN_PAYMENTMETHOD, @" TEXT, ",
            ReceiptsTable.COLUMN_EXPENSEABLE, @" BOOLEAN DEFAULT 1, ",
            ReceiptsTable.COLUMN_NOTFULLPAGEIMAGE, @" BOOLEAN DEFAULT 1, ",
            ReceiptsTable.COLUMN_EXTRA_EDITTEXT_1, @" TEXT, ",
            ReceiptsTable.COLUMN_EXTRA_EDITTEXT_2, @" TEXT, ",
            ReceiptsTable.COLUMN_EXTRA_EDITTEXT_3, @" TEXT",
            @");"];
    return [self executeUpdateWithStatementComponents:createReceiptsTable];
}

- (BOOL)saveReceipt:(WBReceipt *)receipt {
    __block BOOL result;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [self saveReceipt:receipt usingDatabase:db];
    }];

    return result;
}

- (BOOL)saveReceipt:(WBReceipt *)receipt usingDatabase:(FMDatabase *)database {
    DatabaseQueryBuilder *insert = [DatabaseQueryBuilder insertStatementForTable:ReceiptsTable.TABLE_NAME];
    [self appendCommonValuesFromReceipt:receipt toQuery:insert];
    BOOL result = [self executeQuery:insert usingDatabase:database];
    if (result) {
        [self updatePriceOfTrip:receipt.trip usingDatabase:database];
    }
    return result;
}

- (BOOL)updateReceipt:(WBReceipt *)receipt {
    __block BOOL result;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [self updateReceipt:receipt usingDatabase:db];
    }];

    return result;
}

- (BOOL)updateReceipt:(WBReceipt *)receipt usingDatabase:(FMDatabase *)database {
    DatabaseQueryBuilder *update = [DatabaseQueryBuilder updateStatementForTable:ReceiptsTable.TABLE_NAME];
    [self appendCommonValuesFromReceipt:receipt toQuery:update];
    [update where:ReceiptsTable.COLUMN_ID value:@(receipt.id)];
    BOOL result = [self executeQuery:update usingDatabase:database];
    if (result) {
        [self updatePriceOfTrip:receipt.trip usingDatabase:database];
    }
    return result;
}

- (NSArray *)allReceiptsForTrip:(WBTrip *)trip descending:(BOOL)desc {
    DatabaseQueryBuilder *selectAll = [DatabaseQueryBuilder selectAllStatementForTable:ReceiptsTable.TABLE_NAME];
    [selectAll where:ReceiptsTable.COLUMN_PARENT value:trip.name];
    [selectAll orderBy:ReceiptsTable.COLUMN_DATE ascending:!desc];
    return [self allReceiptsWithQuery:selectAll forTrip:trip];
}

- (NSArray *)allReceipts {
    DatabaseQueryBuilder *selectAll = [DatabaseQueryBuilder selectAllStatementForTable:ReceiptsTable.TABLE_NAME];
    [selectAll orderBy:ReceiptsTable.COLUMN_DATE ascending:YES];
    return [self allReceiptsWithQuery:selectAll forTrip:nil];
}

- (NSArray *)allReceiptsWithQuery:(DatabaseQueryBuilder *)query forTrip:(WBTrip *)trip {
    FetchedModelAdapter *adapter = [[FetchedModelAdapter alloc] initWithDatabase:self];
    [adapter setQuery:query.buildStatement parameters:query.parameters];
    [adapter setModelClass:[WBReceipt class]];
    [adapter fetch];
    //TODO jaanus: maybe can do this better
    NSArray *paymentMethods = [self allPaymentMethods];
    NSArray *receipts = [adapter allObjects];
    for (WBReceipt *receipt in receipts) {
        [receipt setTrip:trip];
        [receipt setPaymentMethod:[paymentMethods filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            PaymentMethod *method = evaluatedObject;
            return method.objectId == receipt.paymentMethodId;
        }]].firstObject];
    }
    return receipts;
}

- (NSDecimalNumber *)sumOfReceiptsForTrip:(WBTrip *)trip {
    __block NSDecimalNumber *result;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [self sumOfReceiptsForTrip:trip usingDatabase:db];
    }];

    return result;
}

- (NSDecimalNumber *)sumOfReceiptsForTrip:(WBTrip *)trip usingDatabase:(FMDatabase *)database {
    return [self sumOfReceiptsForTrip:trip onlyExpenseableReceipts:[WBPreferences onlyIncludeExpensableReceiptsInReports] usingDatabase:database];
}

- (NSDecimalNumber *)sumOfReceiptsForTrip:(WBTrip *)trip onlyExpenseableReceipts:(BOOL)onlyExpenseable {
    __block NSDecimalNumber *result;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [self sumOfReceiptsForTrip:trip onlyExpenseableReceipts:onlyExpenseable usingDatabase:db];
    }];

    return result;
}

- (NSDecimalNumber *)sumOfReceiptsForTrip:(WBTrip *)trip onlyExpenseableReceipts:(BOOL)onlyExpenseable usingDatabase:(FMDatabase *)database {
    DatabaseQueryBuilder *sumStatement = [DatabaseQueryBuilder sumStatementForTable:ReceiptsTable.TABLE_NAME];
    [sumStatement setSumColumn:ReceiptsTable.COLUMN_PRICE];
    [sumStatement where:ReceiptsTable.COLUMN_PARENT value:trip.name];
    if (onlyExpenseable) {
        [sumStatement where:ReceiptsTable.COLUMN_EXPENSEABLE value:@(YES)];
    }
    return [self executeDecimalQuery:sumStatement usingDatabase:database];
}

+ (NSString *)extraInsertValue:(NSString *)extraValue {
    if (!extraValue) {
        return [WBReceipt NO_DATA];
    } else {
        if ([extraValue caseInsensitiveCompare:@"null"] == NSOrderedSame) {
            return @"";
        }
    }

    return extraValue;
}

- (NSString *)currencyForTripReceipts:(WBTrip *)trip {
    __block NSString *result;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [self currencyForTripReceipts:trip usingDatabase:db];
    }];

    return result;
}

- (NSString *)currencyForTripReceipts:(WBTrip *)trip usingDatabase:(FMDatabase *)database {
    return [self selectCurrencyFromTable:ReceiptsTable.TABLE_NAME currencyColumn:ReceiptsTable.COLUMN_ISO4217 forTrip:trip usingDatabase:database];
}

- (void)appendCommonValuesFromReceipt:(WBReceipt *)receipt toQuery:(DatabaseQueryBuilder *)query {
    [query addParam:ReceiptsTable.COLUMN_PATH value:receipt.imageFileName fallback:[WBReceipt NO_DATA]];
    [query addParam:ReceiptsTable.COLUMN_PARENT value:receipt.trip.name];
    [query addParam:ReceiptsTable.COLUMN_NAME value:[receipt.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [query addParam:ReceiptsTable.COLUMN_CATEGORY value:receipt.category];
    [query addParam:ReceiptsTable.COLUMN_DATE value:@(receipt.dateMs)];
    [query addParam:ReceiptsTable.COLUMN_TIMEZONE value:receipt.timeZone.name];
    [query addParam:ReceiptsTable.COLUMN_EXPENSEABLE value:@(receipt.isExpensable)];
    [query addParam:ReceiptsTable.COLUMN_ISO4217 value:receipt.price.currency.code];
    [query addParam:ReceiptsTable.COLUMN_NOTFULLPAGEIMAGE value:@(!receipt.isFullPage)];
    [query addParam:ReceiptsTable.COLUMN_PRICE value:receipt.price.amount];
    [query addParam:ReceiptsTable.COLUMN_TAX value:receipt.tax.amount];
    [query addParam:ReceiptsTable.COLUMN_EXTRA_EDITTEXT_1 value:[Database extraInsertValue:receipt.extraEditText1]];
    [query addParam:ReceiptsTable.COLUMN_EXTRA_EDITTEXT_2 value:[Database extraInsertValue:receipt.extraEditText2]];
    [query addParam:ReceiptsTable.COLUMN_EXTRA_EDITTEXT_3 value:[Database extraInsertValue:receipt.extraEditText3]];
    [query addParam:ReceiptsTable.COLUMN_PAYMENT_METHOD_ID value:@(receipt.paymentMethod.objectId)];
}

@end
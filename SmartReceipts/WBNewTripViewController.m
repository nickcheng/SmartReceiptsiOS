//
//  WBNewTripViewController.m
//  SmartReceipts
//
//  Created on 17/03/14.
//  Copyright (c) 2014 Will Baumann. All rights reserved.
//

#import "WBNewTripViewController.h"
#import "WBDateFormatter.h"
#import "WBTrip.h"

#import "WBDB.h"
#import "WBPreferences.h"

#import "WBAutocompleteHelper.h"
#import "WBCustomization.h"
#import "TitledAutocompleteEntryCell.h"
#import "UIView+LoadHelpers.h"
#import "UITableViewCell+Identifier.h"
#import "InputCellsSection.h"
#import "UIApplication+DismissKeyboard.h"
#import "PickerCell.h"
#import "ProperNameInputValidation.h"
#import "NSString+Validation.h"
#import "InlinedDatePickerCell.h"

@interface WBNewTripViewController ()

@property (nonatomic, strong) WBDateFormatter *dateFormatter;
@property (nonatomic, strong) TitledAutocompleteEntryCell *nameCell;
@property (nonatomic, strong) PickerCell *startDateCell;
@property (nonatomic, strong) InlinedDatePickerCell *startDatePickerCell;
@property (nonatomic, strong) PickerCell *endDateCell;
@property (nonatomic, strong) InlinedDatePickerCell *endDatePickerCell;

@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, strong) NSTimeZone *startTimeZone;
@property (nonatomic, strong) NSTimeZone *endTimeZone;

@end

@implementation WBNewTripViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [WBCustomization customizeOnViewDidLoad:self];

    __weak WBNewTripViewController *weakSelf = self;

    [self.tableView registerNib:[TitledAutocompleteEntryCell viewNib] forCellReuseIdentifier:[TitledAutocompleteEntryCell cellIdentifier]];
    [self.tableView registerNib:[PickerCell viewNib] forCellReuseIdentifier:[PickerCell cellIdentifier]];
    [self.tableView registerNib:[InlinedDatePickerCell viewNib] forCellReuseIdentifier:[InlinedDatePickerCell cellIdentifier]];

    self.nameCell = [self.tableView dequeueReusableCellWithIdentifier:[TitledAutocompleteEntryCell cellIdentifier]];
    [self.nameCell setTitle:NSLocalizedString(@"Name", nil)];
    [self.nameCell setAutocompleteHelper:[[WBAutocompleteHelper alloc] initWithAutocompleteField:(HTAutocompleteTextField *) self.nameCell.entryField inView:self.view useReceiptsHints:NO]];
    [self.nameCell.entryField setAutocapitalizationType:UITextAutocapitalizationTypeSentences];
    [self.nameCell setInputValidation:[[ProperNameInputValidation alloc] init]];

    self.startDateCell = [self.tableView dequeueReusableCellWithIdentifier:[PickerCell cellIdentifier]];
    [self.startDateCell setTitle:NSLocalizedString(@"Start Date", nil)];

    self.startDatePickerCell = [self.tableView dequeueReusableCellWithIdentifier:[InlinedDatePickerCell cellIdentifier]];
    [self.startDatePickerCell setChangeHandler:^(NSDate *selected) {
        [weakSelf.startDateCell setValue:[weakSelf.dateFormatter formattedDate:selected inTimeZone:weakSelf.startTimeZone]];
        weakSelf.startDate = selected;
        [weakSelf.endDatePickerCell setMinDate:selected maxDate:nil];
    }];

    self.endDateCell = [self.tableView dequeueReusableCellWithIdentifier:[PickerCell cellIdentifier]];
    [self.endDateCell setTitle:NSLocalizedString(@"End Date", nil)];

    self.endDatePickerCell = [self.tableView dequeueReusableCellWithIdentifier:[InlinedDatePickerCell cellIdentifier]];
    [self.endDatePickerCell setChangeHandler:^(NSDate *selected) {
        [weakSelf.endDateCell setValue:[weakSelf.dateFormatter formattedDate:selected inTimeZone:weakSelf.endTimeZone]];
        weakSelf.endDate = selected;
        [weakSelf.startDatePickerCell setMinDate:nil maxDate:selected];
    }];

    NSMutableArray *presentedCells = [NSMutableArray array];

    [presentedCells addObject:self.nameCell];
    [presentedCells addObject:self.startDateCell];
    [presentedCells addObject:self.endDateCell];

    [self addSectionForPresentation:[InputCellsSection sectionWithCells:presentedCells]];

    [self addInlinedPickerCell:self.startDatePickerCell forCell:self.startDateCell];
    [self addInlinedPickerCell:self.endDatePickerCell forCell:self.endDateCell];

    self.dateFormatter = [[WBDateFormatter alloc] init];
    
    [self.nameCell.entryField becomeFirstResponder];

    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unfocusTextField:)];
    [self.view addGestureRecognizer:gestureRecognizer];
    gestureRecognizer.cancelsTouchesInView = NO;

    [self loadDataToCells];
}

// unfocus textfield on touch out
- (void)unfocusTextField:(UITapGestureRecognizer *)recognizer {
    [UIApplication dismissKeyboard];
}

- (void)loadDataToCells {
    if (_trip) {
        self.navigationItem.title = NSLocalizedString(@"Edit Trip", nil);
        self.nameCell.value = [_trip name];
        _startDate = [_trip startDate];
        _endDate = [_trip endDate];
        _startTimeZone = [_trip startTimeZone];
        _endTimeZone = [_trip endTimeZone];
    } else {
        self.navigationItem.title = NSLocalizedString(@"New Trip", nil);
        _startDate = [NSDate date];

        NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
        dayComponent.day = [WBPreferences defaultTripDuration];
        NSCalendar *theCalendar = [NSCalendar currentCalendar];
        _endDate = [theCalendar dateByAddingComponents:dayComponent toDate:_startDate options:0];

        _startTimeZone = _endTimeZone = [NSTimeZone localTimeZone];
    }

    [self.startDateCell setValue:[self.dateFormatter formattedDate:_startDate inTimeZone:_startTimeZone]];
    [self.endDateCell setValue:[self.dateFormatter formattedDate:_endDate inTimeZone:_endTimeZone]];
    [self.startDatePickerCell setDate:_startDate];
    [self.startDatePickerCell setMinDate:nil maxDate:self.endDate];
    [self.endDatePickerCell setDate:_endDate];
    [self.endDatePickerCell setMinDate:self.startDate maxDate:nil];
}

- (IBAction)actionDone:(id)sender {
    WBTrip* newTrip;
    
    NSString* name = [self.nameCell.value lastPathComponent];

    if (![name hasValue]) {
        [WBNewTripViewController showAlertWithTitle:nil message:NSLocalizedString(@"Please enter a name",nil)];
        return;
    }
    
    if (_trip == nil) {
        newTrip = [[WBDB trips] insertWithName:name from:_startDate to:_endDate];
        if(!newTrip){
            [WBNewTripViewController showAlertWithTitle:nil message:NSLocalizedString(@"Cannot add this trip",nil)];
            return;
        }
        [self.delegate viewController:self newTrip:newTrip];
    } else {
        newTrip = [[WBDB trips] updateTrip:_trip dir:name from:_startDate to:_endDate];
        if(!newTrip){
            [WBNewTripViewController showAlertWithTitle:nil message:NSLocalizedString(@"Cannot save this trip",nil)];
            return;
        }
        [self.delegate viewController:self updatedTrip:newTrip fromTrip:_trip];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)actionCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
}

@end

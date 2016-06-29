//
//  ReceiveCoinsViewControllerViewController.m
//  Blockchain
//
//  Created by Ben Reeves on 17/03/2012.
//  Copyright (c) 2012 Qkos Services Ltd. All rights reserved.
//

#import "ReceiveCoinsViewController.h"
#import "AppDelegate.h"
#import "ReceiveTableCell.h"
#import "Address.h"
#import "PrivateKeyReader.h"
#import "UIViewController+AutoDismiss.h"
#import "QRCodeGenerator.h"
#import "BCAddressSelectionView.h"
#import "BCLine.h"

@interface ReceiveCoinsViewController() <UIActivityItemSource, AddressSelectionDelegate>
@property (nonatomic) UITextField *lastSelectedField;
@property (nonatomic) QRCodeGenerator *qrCodeGenerator;
@property (nonatomic) uint64_t lastRequestedAmount;
@end

@implementation ReceiveCoinsViewController

@synthesize activeKeys;

Boolean didClickAccount = NO;
int clickedAccount;

UILabel *mainAddressLabel;

NSString *mainAddress;
NSString *mainLabel;

NSString *detailAddress;
NSString *detailLabel;

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.frame = CGRectMake(0, 0, app.window.frame.size.width,
                                 app.window.frame.size.height - DEFAULT_HEADER_HEIGHT - DEFAULT_FOOTER_HEIGHT);
    
    [self setupBottomViews];
    [self selectDefaultDestination];
    
    float imageWidth = 160;
    
    qrCodeMainImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - imageWidth) / 2, 52, imageWidth, imageWidth)];
    qrCodeMainImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self setupTapGestureForMainQR];
    
    // iPhone4/4S
    if ([[UIScreen mainScreen] bounds].size.height < 568) {
        int reduceImageSizeBy = 40;
        
        // Smaller QR Code Image
        qrCodeMainImageView.frame = CGRectMake(qrCodeMainImageView.frame.origin.x + reduceImageSizeBy / 2,
                                               qrCodeMainImageView.frame.origin.y - 10,
                                               qrCodeMainImageView.frame.size.width - reduceImageSizeBy,
                                               qrCodeMainImageView.frame.size.height - reduceImageSizeBy);
    }
    
    btcAmountField.placeholder = [NSString stringWithFormat:BTC_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
    fiatAmountField.placeholder = [NSString stringWithFormat:FIAT_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
    
    [self reload];
    
    [self setupHeaderView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    app.mainTitleLabel.text = BC_STRING_RECEIVE;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self hideKeyboard];
}

- (QRCodeGenerator *)qrCodeGenerator
{
    if (!_qrCodeGenerator) {
        _qrCodeGenerator = [[QRCodeGenerator alloc] init];
    }
    return _qrCodeGenerator;
}

- (void)setupBottomViews
{
    UIButton *requestButton = [[UIButton alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - BUTTON_HEIGHT, self.view.frame.size.width, BUTTON_HEIGHT)];
    requestButton.backgroundColor = COLOR_BUTTON_GREEN;
    [requestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [requestButton setTitle:BC_STRING_REQUEST forState:UIControlStateNormal];
    [self.view addSubview:requestButton];
    [requestButton addTarget:self action:@selector(share) forControlEvents:UIControlEventTouchUpInside];
    
    self.bottomContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 100 - requestButton.frame.size.height, self.view.frame.size.width, 100)];
    [self.view addSubview:self.bottomContainerView];
    
    BCLine *lineAboveAmounts = [[BCLine alloc] initWithFrame:CGRectMake(15, 0, self.view.frame.size.width - 15, 1)];
    BCLine *lineBelowAmounts = [[BCLine alloc] initWithFrame:CGRectMake(15, 50, self.view.frame.size.width - 15, 1)];
    lineAboveAmounts.backgroundColor = COLOR_LINE_GRAY;
    lineBelowAmounts.backgroundColor = COLOR_LINE_GRAY;
    [self.bottomContainerView addSubview:lineAboveAmounts];
    [self.bottomContainerView addSubview:lineBelowAmounts];
    
    receiveBtcLabel = [[UILabel alloc] initWithFrame:CGRectMake(lineAboveAmounts.frame.origin.x, 15, 40, 21)];
    receiveBtcLabel.font = [UIFont systemFontOfSize:13];
    receiveBtcLabel.textColor = [UIColor lightGrayColor];
    receiveBtcLabel.text = app.latestResponse.symbol_btc.symbol;
    [self.bottomContainerView addSubview:receiveBtcLabel];
    
    self.receiveBtcField = [[BCSecureTextField alloc] initWithFrame:CGRectMake(receiveBtcLabel.frame.origin.x + 53, 10, 117, 30)];
    self.receiveBtcField.font = [UIFont systemFontOfSize:13];
    self.receiveBtcField.placeholder = [NSString stringWithFormat:BTC_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
    self.receiveBtcField.keyboardType = UIKeyboardTypeDecimalPad;
    self.receiveBtcField.inputAccessoryView = amountKeyboardAccessoryView;
    self.receiveBtcField.delegate = self;
    [self.bottomContainerView addSubview:self.receiveBtcField];
    
    receiveFiatLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 136, 15, 40, 21)];
    receiveFiatLabel.font = [UIFont systemFontOfSize:13];
    receiveFiatLabel.textColor = [UIColor lightGrayColor];
    receiveFiatLabel.text = app.latestResponse.symbol_local.code;
    [self.bottomContainerView addSubview:receiveFiatLabel];
    
    self.receiveFiatField = [[BCSecureTextField alloc] initWithFrame:CGRectMake(receiveFiatLabel.frame.origin.x + 47, 10, 117, 30)];
    self.receiveFiatField.font = [UIFont systemFontOfSize:13];
    self.receiveFiatField.placeholder = [NSString stringWithFormat:FIAT_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
    self.receiveFiatField.keyboardType = UIKeyboardTypeDecimalPad;
    self.receiveFiatField.inputAccessoryView = amountKeyboardAccessoryView;
    self.receiveFiatField.delegate = self;
    [self.bottomContainerView addSubview:self.receiveFiatField];
    
    UILabel *whereLabel = [[UILabel alloc] initWithFrame:CGRectMake(lineAboveAmounts.frame.origin.x, 65, 40, 21)];
    whereLabel.font = [UIFont systemFontOfSize:13];
    whereLabel.textColor = [UIColor lightGrayColor];
    whereLabel.text = BC_STRING_WHERE;
    [self.bottomContainerView addSubview:whereLabel];
    
    UIButton *selectDestinationButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 35, 60, 35, 30)];
    selectDestinationButton.adjustsImageWhenHighlighted = NO;
    [selectDestinationButton setImage:[UIImage imageNamed:@"disclosure"] forState:UIControlStateNormal];
    [selectDestinationButton addTarget:self action:@selector(selectDestination) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomContainerView addSubview:selectDestinationButton];
    
    self.receiveToLabel = [[UILabel alloc] initWithFrame:CGRectMake(whereLabel.frame.origin.x + whereLabel.frame.size.width + 16, 65, selectDestinationButton.frame.origin.x - (whereLabel.frame.origin.x + whereLabel.frame.size.width + 16), 21)];
    self.receiveToLabel.font = [UIFont systemFontOfSize:13];
    [self.bottomContainerView addSubview:self.receiveToLabel];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectDestination)];
    [self.receiveToLabel addGestureRecognizer:tapGesture];
    self.receiveToLabel.userInteractionEnabled = YES;
    
    [self updateUI];
    
    [doneButton setTitle:BC_STRING_DONE forState:UIControlStateNormal];
    doneButton.titleLabel.adjustsFontSizeToFitWidth = YES;
}

- (void)selectDefaultDestination
{
    if ([app.wallet didUpgradeToHd]) {
        [self didSelectToAccount:[app.wallet getDefaultAccountIndex]];
    } else {
        [self didSelectToAddress:[[app.wallet allLegacyAddresses] firstObject]];
    }
}

- (void)setupTapGestureForMainLabel
{
    UITapGestureRecognizer *tapGestureForMainLabel = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainQRClicked:)];
    [mainAddressLabel addGestureRecognizer:tapGestureForMainLabel];
    mainAddressLabel.userInteractionEnabled = YES;
}

- (void)setupTapGestureForMainQR
{
    UITapGestureRecognizer *tapMainQRGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainQRClicked:)];
    [qrCodeMainImageView addGestureRecognizer:tapMainQRGestureRecognizer];
    qrCodeMainImageView.userInteractionEnabled = YES;
}

- (void)reload
{
    [self reloadAddresses];
    
    [self reloadLocalAndBtcSymbolsFromLatestResponse];
    
    if (!mainAddress) {
        [self reloadMainAddress];
    } else if (didClickAccount) {
        [self didSelectFromAccount:clickedAccount];
    } else {
        [self updateUI];
    }
}

- (void)reloadAddresses
{
    self.activeKeys = [app.wallet activeLegacyAddresses];
}

- (void)reloadLocalAndBtcSymbolsFromLatestResponse
{
    if (app.latestResponse.symbol_local && app.latestResponse.symbol_btc) {
        fiatLabel.text = app.latestResponse.symbol_local.code;
        receiveFiatLabel.text = app.latestResponse.symbol_local.code;

        btcLabel.text = app.latestResponse.symbol_btc.symbol;
        receiveBtcLabel.text = app.latestResponse.symbol_btc.symbol;
    }
}

- (void)reloadMainAddress
{
    // Get an address: the first empty receive address for the default HD account
    // Or the first active legacy address if there are no HD accounts
    if ([app.wallet getActiveAccountsCount] > 0) {
        [self didSelectFromAccount:[app.wallet getDefaultAccountIndex]];
    }
    else if (activeKeys.count > 0) {
        for (NSString *address in activeKeys) {
            if (![app.wallet isWatchOnlyLegacyAddress:address]) {
                [self didSelectFromAddress:address];
                break;
            }
        }
    }
}

- (void)setupHeaderView
{
    // Show table header with the QR code of an address from the default account
    float imageWidth = qrCodeMainImageView.frame.size.width;
    
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, imageWidth + 75 + 4)];
    
    [self.view addSubview:self.headerView];
    
    UILabel *instructionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, self.view.frame.size.width - 50, 40)];
    instructionsLabel.font = [[UIScreen mainScreen] bounds].size.height < 568 ? [UIFont systemFontOfSize:12] : [UIFont systemFontOfSize:14];
    instructionsLabel.textColor = COLOR_FOREGROUND_GRAY;
    instructionsLabel.textAlignment = NSTextAlignmentCenter;
    instructionsLabel.text = BC_STRING_RECEIVE_SCREEN_INSTRUCTIONS;
    instructionsLabel.numberOfLines = 0;
    instructionsLabel.adjustsFontSizeToFitWidth = YES;
    instructionsLabel.center = CGPointMake(self.view.center.x, 25);
    [self.headerView addSubview:instructionsLabel];
    
    if ([app.wallet getActiveAccountsCount] > 0 || activeKeys.count > 0) {
        
        qrCodeMainImageView.image = [self.qrCodeGenerator qrImageFromAddress:mainAddress];
        
        [self.headerView addSubview:qrCodeMainImageView];
        
        mainAddressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, imageWidth + 55, self.view.frame.size.width - 40, 18)];
        
        mainAddressLabel.font = [UIFont systemFontOfSize:15];
        mainAddressLabel.textAlignment = NSTextAlignmentCenter;
        mainAddressLabel.textColor = [UIColor blackColor];
        [mainAddressLabel setMinimumScaleFactor:.5f];
        [mainAddressLabel setAdjustsFontSizeToFitWidth:YES];
        [self.headerView addSubview:mainAddressLabel];
        
        informationButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 18, 18)];
        [informationButton setImage:[UIImage imageNamed:@"icon_support"] forState:UIControlStateNormal];
        informationButton.center = self.view.center;
        informationButton.frame = CGRectMake(informationButton.frame.origin.x, self.headerView.frame.size.height + 4, informationButton.frame.size.width, informationButton.frame.size.height);
        [informationButton addTarget:self action:@selector(informationButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:informationButton];
        
        [self setupTapGestureForMainLabel];
        [self updateUI];
    }
}

#pragma mark - Helpers

- (NSString *)getAddress:(NSIndexPath*)indexPath
{
    NSString *addr = nil;
    
    if ([indexPath section] == 1)
        addr = [activeKeys objectAtIndex:[indexPath row]];
    
    return addr;
}

- (NSString *)uriURL
{
    double amount = (double)[self getInputAmountInSatoshi] / SATOSHI;
    
    app.btcFormatter.usesGroupingSeparator = NO;
    NSLocale *currentLocale = app.btcFormatter.locale;
    app.btcFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    NSString *amountString = [app.btcFormatter stringFromNumber:[NSNumber numberWithDouble:amount]];
    app.btcFormatter.locale = currentLocale;
    app.btcFormatter.usesGroupingSeparator = YES;
    
    return [NSString stringWithFormat:@"bitcoin://%@?amount=%@", self.clickedAddress, amountString];
}

- (uint64_t)getInputAmountInSatoshi
{
    BOOL shouldUseBtcField = YES;
    
    if ([btcAmountField isFirstResponder]) {
        shouldUseBtcField = YES;
    } else if ([fiatAmountField isFirstResponder]) {
        shouldUseBtcField = NO;
        
    } else if (self.lastSelectedField == btcAmountField) {
        shouldUseBtcField = YES;
    } else if (self.lastSelectedField == fiatAmountField) {
        shouldUseBtcField = NO;
    }
    
    if (shouldUseBtcField) {
        NSString *requestedAmountString = [btcAmountField.text stringByReplacingOccurrencesOfString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] withString:@"."];
        return [app.wallet parseBitcoinValue:requestedAmountString];
    } else {
        NSString *requestedAmountString = [fiatAmountField.text stringByReplacingOccurrencesOfString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] withString:@"."];
        return app.latestResponse.symbol_local.conversion * [requestedAmountString doubleValue];
    }
    
    return 0;
}

- (void)doCurrencyConversion
{
    uint64_t amount = [self getInputAmountInSatoshi];
    
    if ([btcAmountField isFirstResponder]) {
        fiatAmountField.text = [app formatAmount:amount localCurrency:YES];
    }
    else if ([fiatAmountField isFirstResponder]) {
        btcAmountField.text = [app formatAmount:amount localCurrency:NO];
    }
    
    self.receiveFiatField.text = fiatAmountField.text;
    self.receiveBtcField.text = btcAmountField.text;
}

- (NSString *)getKey:(NSIndexPath*)indexPath
{
    NSString *key;
    
    if ([indexPath section] == 0)
        key = [activeKeys objectAtIndex:[indexPath row]];
    
    return key;
}

- (void)setQRPayment
{
    double amount = (double)[self getInputAmountInSatoshi] / SATOSHI;
        
    UIImage *image = [self.qrCodeGenerator qrImageFromAddress:self.clickedAddress amount:amount];
        
    qrCodeMainImageView.image = image;
    qrCodeMainImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self doCurrencyConversion];
}

- (void)animateTextOfLabel:(UILabel *)labelToAnimate fromText:(NSString *)originalText toIntermediateText:(NSString *)intermediateText speed:(float)speed gestureReceiver:(UIView *)gestureReceiver
{
    gestureReceiver.userInteractionEnabled = NO;
    
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        labelToAnimate.alpha = 0.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            labelToAnimate.text = intermediateText;
            labelToAnimate.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(speed * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                    labelToAnimate.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                        labelToAnimate.text = originalText;
                        labelToAnimate.alpha = 1.0;
                        gestureReceiver.userInteractionEnabled = YES;
                    }];
                }];
            });
        }];
    }];
}

#pragma mark - Actions

- (IBAction)doneButtonClicked:(UIButton *)sender
{
    [self hideKeyboard];
}

- (IBAction)labelSaveClicked:(id)sender
{
    NSString *label = [labelTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![app.wallet didUpgradeToHd]) {
        NSMutableCharacterSet *allowedCharSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
        [allowedCharSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([label rangeOfCharacterFromSet:[allowedCharSet invertedSet]].location != NSNotFound) {
            [app standardNotify:BC_STRING_LABEL_MUST_BE_ALPHANUMERIC];
            return;
        }
    }

    NSString *addr = self.clickedAddress;
    
    [app.wallet setLabel:label forLegacyAddress:addr];
    
    [self reload];
    
    [app closeModalWithTransition:kCATransitionFade];
    
    if (app.wallet.isSyncing) {
        [app showBusyViewWithLoadingText:BC_STRING_LOADING_SYNCING_WALLET];
    }
}

- (IBAction)mainQRClicked:(id)sender
{
    [UIPasteboard generalPasteboard].string = mainAddress;
    
    [self animateTextOfLabel:mainAddressLabel fromText:mainAddress toIntermediateText:BC_STRING_COPIED_TO_CLIPBOARD speed:1 gestureReceiver:qrCodeMainImageView];
}

- (NSString*)formatPaymentRequestWithAmount:(NSString *)amount url:(NSString*)url
{
    return [NSString stringWithFormat:BC_STRING_PAYMENT_REQUEST_ARGUMENT_ARGUMENT, amount, url];
}

- (NSString*)formatPaymentRequestHTML:(NSString*)url
{
    return [NSString stringWithFormat:BC_STRING_PAYMENT_REQUEST_HTML, url];
}

- (IBAction)archiveAddressClicked:(id)sender
{
    NSString *addr = self.clickedAddress;
    Boolean isArchived = [app.wallet isAddressArchived:addr];
    
    if (isArchived) {
        [app.wallet toggleArchiveLegacyAddress:addr];
    }
    else {
        // Need at least one active address
        if (activeKeys.count == 1 && ![app.wallet hasAccount]) {
            [app closeModalWithTransition:kCATransitionFade];
            
            [app standardNotifyAutoDismissingController:BC_STRING_AT_LEAST_ONE_ACTIVE_ADDRESS];
            
            return;
        }
        
        [app.wallet toggleArchiveLegacyAddress:addr];
    }
    
    [self reload];
    
    [app closeModalWithTransition:kCATransitionFade];
}

- (void)showKeyboard
{
    // Select the entry field
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        if ([self.receiveBtcField isFirstResponder]) {
            [btcAmountField becomeFirstResponder];
        } else if ([self.receiveFiatField isFirstResponder]){
            [fiatAmountField becomeFirstResponder];
        } else {
            [labelTextField becomeFirstResponder];
        }
    });
    
    [UIView animateWithDuration:0.3 animations:^{
        informationButton.alpha = 0.0;
    } completion:^(BOOL finished) {
        informationButton.userInteractionEnabled = NO;
    }];
}

- (void)hideKeyboard
{
    [fiatAmountField resignFirstResponder];
    [btcAmountField resignFirstResponder];
    [labelTextField resignFirstResponder];
    [self.receiveFiatField resignFirstResponder];
    [self.receiveBtcField resignFirstResponder];
    
    [UIView animateWithDuration:0.3 animations:^{
        informationButton.alpha = 1.0;
    } completion:^(BOOL finished) {
        informationButton.userInteractionEnabled = YES;
    }];
}

- (void)alertUserOfPaymentWithMessage:(NSString *)messageString
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BC_STRING_PAYMENT_RECEIVED message:messageString delegate:nil cancelButtonTitle:BC_STRING_OK otherButtonTitles: nil];
    [alertView show];
}

- (void)alertUserOfWatchOnlyAddress:(NSString *)address
{
    UIAlertController *alertForWatchOnly = [UIAlertController alertControllerWithTitle:BC_STRING_WARNING_TITLE message:BC_STRING_WATCH_ONLY_RECEIVE_WARNING preferredStyle:UIAlertControllerStyleAlert];
    [alertForWatchOnly addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self didSelectFromAddress:address];
        [app closeModalWithTransition:kCATransitionFromLeft];
    }]];
    [alertForWatchOnly addAction:[UIAlertAction actionWithTitle:BC_STRING_DONT_SHOW_AGAIN style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:USER_DEFAULTS_KEY_HIDE_WATCH_ONLY_RECEIVE_WARNING];
        [self didSelectFromAddress:address];
        [app closeModalWithTransition:kCATransitionFromLeft];
    }]];
    [alertForWatchOnly addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    
    [[NSNotificationCenter defaultCenter] addObserver:alertForWatchOnly selector:@selector(autoDismiss) name:NOTIFICATION_KEY_RELOAD_TO_DISMISS_VIEWS object:nil];
    
    [app.tabViewController presentViewController:alertForWatchOnly animated:YES completion:nil];
}

- (void)storeRequestedAmount
{
    NSString *requestedAmountString = [btcAmountField.text stringByReplacingOccurrencesOfString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] withString:@"."];
    self.lastRequestedAmount = [app.wallet parseBitcoinValue:requestedAmountString];
}

- (void)updateUI
{
    self.receiveToLabel.text = mainLabel;
    mainAddressLabel.text = mainAddress;
    
    [self setQRPayment];
}

- (void)paymentReceived:(NSDecimalNumber *)amount
{
    u_int64_t amountReceived = [[amount decimalNumberByMultiplyingBy:(NSDecimalNumber *)[NSDecimalNumber numberWithDouble:SATOSHI]] longLongValue];
    if (amountReceived == self.lastRequestedAmount) {
        NSString *btcAmountString = [app formatMoney:self.lastRequestedAmount localCurrency:NO];
        NSString *localCurrencyAmountString = [app formatMoney:self.lastRequestedAmount localCurrency:YES];
        [self alertUserOfPaymentWithMessage:[[NSString alloc] initWithFormat:@"%@\n%@", btcAmountString,localCurrencyAmountString]];
    }
}

- (void)selectDestination
{
    [self hideKeyboard];
    
    BCAddressSelectionView *addressSelectionView = [[BCAddressSelectionView alloc] initWithWallet:app.wallet showOwnAddresses:YES allSelectable:YES];
    addressSelectionView.delegate = self;
    
    [app showModalWithContent:addressSelectionView closeType:ModalCloseTypeBack showHeader:YES headerText:BC_STRING_RECEIVE_TO onDismiss:nil onResume:nil];
}

- (void)share
{
    uint64_t amount = [self getInputAmountInSatoshi];
    NSString *amountString = amount > 0 ? [app formatMoney:[self getInputAmountInSatoshi] localCurrency:NO] : [BC_STRING_AMOUNT lowercaseString];
    NSString *message = [self formatPaymentRequestWithAmount:amountString url:@""];
    
    NSURL *url = [NSURL URLWithString:[self uriURL]];
    
    NSArray *activityItems = @[message, self, url];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypeAddToReadingList, UIActivityTypePostToFacebook];
    
    [activityViewController setValue:BC_STRING_PAYMENT_REQUEST_SUBJECT forKey:@"subject"];
    
    // Keyboard is behaving a little strangely because of UITextFields in the Keyboard Accessory View
    // This makes it work correctly - resign first Responder for UITextFields inside the Accessory View...
    [btcAmountField resignFirstResponder];
    [fiatAmountField resignFirstResponder];
    
    [app.tabViewController presentViewController:activityViewController animated:YES completion:nil];
    
    activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *error) {
        [self showKeyboard];
    };
}

- (void)clearAmounts
{
    btcAmountField.text = nil;
    fiatAmountField.text = nil;
    self.receiveBtcField.text = nil;
    self.receiveFiatField.text = nil;
}

- (void)informationButtonClicked:(UIButton *)sender
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_INFORMATION message:BC_STRING_INFORMATION_RECEIVE preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_LEARN_MORE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:INFORMATION_RECEIVE_URL]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

# pragma mark - UITextField delegates

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (app.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
        
        [UIView animateWithDuration:0.3 animations:^{
            informationButton.alpha = 1.0;
        } completion:^(BOOL finished) {
            informationButton.userInteractionEnabled = YES;
        }];
        
        return NO;
    }
    
    if (textField == self.receiveFiatField) {
        [self showKeyboard];
        return YES;
    } else if (textField == self.receiveBtcField) {
        [self showKeyboard];
        return YES;
    }
    
    if (textField == fiatAmountField || textField == btcAmountField) {
        self.lastSelectedField = textField; 
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    if (textField == labelTextField) {
        [self labelSaveClicked:nil];
        return YES;
    }
    
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == btcAmountField || textField == fiatAmountField) {
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSArray  *points = [newString componentsSeparatedByString:@"."];
        NSArray  *commas = [newString componentsSeparatedByString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
        
        // Only one comma or point in input field allowed
        if ([points count] > 2 || [commas count] > 2)
            return NO;
        
        // Only 1 leading zero
        if (points.count == 1 || commas.count == 1) {
            if (range.location == 1 && ![string isEqualToString:@"."] && ![string isEqualToString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]] && [textField.text isEqualToString:@"0"]) {
                return NO;
            }
        }
        
        // When entering amount in BTC, max 8 decimal places
        if ([btcAmountField isFirstResponder]) {
            // Max number of decimal places depends on bitcoin unit
            NSUInteger maxlength = [@(SATOSHI) stringValue].length - [@(SATOSHI / app.latestResponse.symbol_btc.conversion) stringValue].length;
            
            if (points.count == 2) {
                NSString *decimalString = points[1];
                if (decimalString.length > maxlength) {
                    return NO;
                }
            }
            else if (commas.count == 2) {
                NSString *decimalString = commas[1];
                if (decimalString.length > maxlength) {
                    return NO;
                }
            }
        }
        
        // Fiat currencies have a max of 3 decimal places, most of them actually only 2. For now we will use 2.
        else if ([fiatAmountField isFirstResponder]) {
            if (points.count == 2) {
                NSString *decimalString = points[1];
                if (decimalString.length > 2) {
                    return NO;
                }
            }
            else if (commas.count == 2) {
                NSString *decimalString = commas[1];
                if (decimalString.length > 2) {
                    return NO;
                }
            }
        }
        
        uint64_t amountInSatoshi = 0;
        NSString *amountString = [newString stringByReplacingOccurrencesOfString:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] withString:@"."];
        if (textField == fiatAmountField) {
            amountInSatoshi = app.latestResponse.symbol_local.conversion * [amountString doubleValue];
        }
        else {
            amountInSatoshi = [app.wallet parseBitcoinValue:amountString];
        }
        
        if (amountInSatoshi > BTC_LIMIT_IN_SATOSHI) {
            return NO;
        } else {
            [self performSelector:@selector(setQRPayment) withObject:nil afterDelay:0.1f];
            return YES;
        }
    } else {
        return YES;
    }
}

#pragma mark - UIActivityItemSource Delegate

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
    if (activityType == UIActivityTypePostToTwitter) {
        return nil;
    } else {
        return qrCodeMainImageView.image;
    }
}

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
    return @"";
}

#pragma mark - BCAddressSelectionView Delegate

- (void)didSelectFromAddress:(NSString*)address
{
    mainAddress = address;
    NSString *addr = mainAddress;
    NSString *label = [app.wallet labelForLegacyAddress:addr];
    
    self.clickedAddress = addr;
    didClickAccount = NO;
    
    if (label.length > 0) {
        mainLabel = label;
    } else {
        mainLabel = addr;
    }
    
    [self updateUI];
}

- (void)didSelectToAddress:(NSString*)address
{
    [self didSelectFromAddress:address];
}

- (void)didSelectFromAccount:(int)account
{
    mainAddress = [app.wallet getReceiveAddressForAccount:account];
    self.clickedAddress = mainAddress;
    clickedAccount = account;
    didClickAccount = YES;
    
    mainLabel = [app.wallet getLabelForAccount:account];
    
    [self updateUI];
}

- (void)didSelectToAccount:(int)account
{
    [self didSelectFromAccount:account];
}

- (void)didSelectWatchOnlyAddress:(NSString *)address
{
    [self alertUserOfWatchOnlyAddress:address];
}

@end

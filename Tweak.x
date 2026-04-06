#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <rootless.h>

#define TweakName @"YTIcons"

static const NSInteger YTIconsSection = 'ytic';
static NSInteger ytIconsRangeStart = 0;
static const NSInteger kRangeSize = 100;
static const NSInteger kMaxIcons = 1500;

@interface YTSettingsSectionItemManager (Tweak)
- (void)updateYTIconsSectionWithEntry:(id)entry;
@end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSMutableArray <NSNumber *> *mutableOrder = [order mutableCopy];
    [mutableOrder insertObject:@(YTIconsSection) atIndex:0];
    return mutableOrder.copy;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTIconsSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // Navigation row
    NSInteger rangeEnd = MIN(ytIconsRangeStart + kRangeSize, kMaxIcons);
    NSString *navTitle = [NSString stringWithFormat:@"Showing %ld - %ld  (Tap to change range)", (long)ytIconsRangeStart, (long)rangeEnd - 1];

    __block __weak YTSettingsSectionItemManager *weakSelf = self;
    YTSettingsSectionItem *navItem = [YTSettingsSectionItemClass itemWithTitle:navTitle
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Jump to range"
                message:[NSString stringWithFormat:@"Enter start number (0-%ld)", (long)kMaxIcons - 1]
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
                tf.keyboardType = UIKeyboardTypeNumberPad;
                tf.placeholder = [NSString stringWithFormat:@"%ld", (long)ytIconsRangeStart];
            }];
            [alert addAction:[UIAlertAction actionWithTitle:@"Go" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSInteger val = [alert.textFields.firstObject.text integerValue];
                ytIconsRangeStart = MAX(0, MIN(val, kMaxIcons - kRangeSize));
                [weakSelf updateYTIconsSectionWithEntry:nil];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [settingsViewController presentViewController:alert animated:YES completion:nil];
            return YES;
        }];
    [sectionItems addObject:navItem];

    // Prev/Next row
    if (ytIconsRangeStart > 0 || rangeEnd < kMaxIcons) {
        NSMutableString *pnTitle = [NSMutableString string];
        if (ytIconsRangeStart > 0) [pnTitle appendString:@"◀ Previous"];
        if (ytIconsRangeStart > 0 && rangeEnd < kMaxIcons) [pnTitle appendString:@"   |   "];
        if (rangeEnd < kMaxIcons) [pnTitle appendString:@"Next ▶"];

        YTSettingsSectionItem *pnItem = [YTSettingsSectionItemClass itemWithTitle:pnTitle
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
                // Toggle between prev and next — if at start go next, at end go prev, otherwise go next
                if (rangeEnd >= kMaxIcons) {
                    ytIconsRangeStart = MAX(0, ytIconsRangeStart - kRangeSize);
                } else {
                    ytIconsRangeStart = MIN(kMaxIcons - kRangeSize, ytIconsRangeStart + kRangeSize);
                }
                [weakSelf updateYTIconsSectionWithEntry:nil];
                return YES;
            }];
        [sectionItems addObject:pnItem];
    }

    // Icon rows
    for (NSInteger i = ytIconsRangeStart; i < rangeEnd; ++i) {
        @try {
            YTIIcon *icon = [%c(YTIIcon) new];
            icon.iconType = i;
            NSString *iconDescription = [icon description];
            NSRange range = [iconDescription rangeOfString:@"icon_type: "];
            if (range.location != NSNotFound)
                iconDescription = [iconDescription substringFromIndex:range.location + range.length];
            NSString *title = [NSString stringWithFormat:@"%ld - %@", (long)i, iconDescription];
            YTSettingsSectionItem *option = [YTSettingsSectionItemClass itemWithTitle:title
                accessibilityIdentifier:nil
                detailTextBlock:NULL
                selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
                    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%ld", (long)i];
                    return YES;
                }];
            option.settingIcon = icon;
            [sectionItems addObject:option];
        } @catch (id ex) {}
    }

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)])
        [settingsViewController setSectionItems:sectionItems forCategory:YTIconsSection title:TweakName icon:nil titleDescription:nil headerHidden:NO];
    else
        [settingsViewController setSectionItems:sectionItems forCategory:YTIconsSection title:TweakName titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTIconsSection) {
        [self updateYTIconsSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

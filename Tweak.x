#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <rootless.h>

#define TweakName @"YTIcons"

static const NSInteger YTIconsSection = 'ytic';
static NSString *ytIconsSearchQuery = nil;

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
    __weak YTSettingsSectionItemManager *weakSelf = self;

    // Search row
    NSString *searchTitle = ytIconsSearchQuery
        ? [NSString stringWithFormat:@"🔍 \"%@\" — Tap to change", ytIconsSearchQuery]
        : @"🔍 Search Icons";

    YTSettingsSectionItem *searchItem = [YTSettingsSectionItemClass itemWithTitle:searchTitle
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            return ytIconsSearchQuery ? @"Clear ✕" : nil;
        }
        selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Search Icons"
                message:@"Search by name or number"
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
                tf.placeholder = @"e.g. HISTORY or 59";
                tf.text = ytIconsSearchQuery;
                tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
                tf.clearButtonMode = UITextFieldViewModeAlways;
            }];
            [alert addAction:[UIAlertAction actionWithTitle:@"Search" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *query = alert.textFields.firstObject.text;
                ytIconsSearchQuery = query.length > 0 ? query : nil;
                [weakSelf updateYTIconsSectionWithEntry:nil];
            }]];
            if (ytIconsSearchQuery) {
                [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    ytIconsSearchQuery = nil;
                    [weakSelf updateYTIconsSectionWithEntry:nil];
                }]];
            }
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [settingsViewController presentViewController:alert animated:YES completion:nil];
            return YES;
        }];
    [sectionItems addObject:searchItem];

    // Count matches for feedback
    NSInteger matchCount = 0;

    for (NSInteger i = 0; i < 1500; ++i) {
        @try {
            YTIIcon *icon = [%c(YTIIcon) new];
            icon.iconType = i;
            NSString *iconDescription = [icon description];
            NSRange range = [iconDescription rangeOfString:@"icon_type: "];
            if (range.location != NSNotFound)
                iconDescription = [iconDescription substringFromIndex:range.location + range.length];
            NSString *title = [NSString stringWithFormat:@"%ld - %@", (long)i, iconDescription];

            if (ytIconsSearchQuery) {
                if ([title rangeOfString:ytIconsSearchQuery options:NSCaseInsensitiveSearch].location == NSNotFound)
                    continue;
            }

            matchCount++;

            YTSettingsSectionItem *option = [YTSettingsSectionItemClass itemWithTitle:title
                accessibilityIdentifier:nil
                detailTextBlock:NULL
                selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
                    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%ld", (long)i];
                    [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:
                        [%c(YTHUDMessage) messageWithText:[NSString stringWithFormat:@"Copied: %ld", (long)i]]];
                    return YES;
                }];
            option.settingIcon = icon;
            [sectionItems addObject:option];
        } @catch (id ex) {}
    }

    // Update search row with count if searching
    if (ytIconsSearchQuery && matchCount == 0) {
        YTSettingsSectionItem *noResults = [YTSettingsSectionItemClass itemWithTitle:@"No matching icons found"
            accessibilityIdentifier:nil detailTextBlock:nil selectBlock:nil];
        [sectionItems addObject:noResults];
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

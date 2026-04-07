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

%hook YTSettingsViewController

- (void)loadWithModel:(id)model fromView:(UIView *)view {
    %orig;
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection)
        [self setValue:@(YES) forKey:@"_shouldShowSearchBar"];
}

// Let YouTube handle search first, then re-inject our filtered items
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        ytIconsSearchQuery = searchText.length > 0 ? searchText : nil;
        %orig;
        // Re-inject after YouTube clears our section
        YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
        [manager updateYTIconsSectionWithEntry:nil];
        return;
    }
    %orig;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        ytIconsSearchQuery = nil;
        %orig;
        YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
        [manager updateYTIconsSectionWithEntry:nil];
        return;
    }
    %orig;
}

// Also catch the search bar's begin/end editing to handle edge cases
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        [searchBar resignFirstResponder];
        return;
    }
    %orig;
}

%end

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

            YTSettingsSectionItem *option = [YTSettingsSectionItemClass itemWithTitle:title
                accessibilityIdentifier:nil
                detailTextBlock:NULL
                selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
                    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%ld", (long)i];
                    @try {
                        [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:
                            [%c(YTHUDMessage) messageWithText:[NSString stringWithFormat:@"Copied: %ld", (long)i]]];
                    } @catch (id ex) {}
                    return YES;
                }];
            option.settingIcon = icon;
            [sectionItems addObject:option];
        } @catch (id ex) {}
    }

    if (ytIconsSearchQuery && sectionItems.count == 0) {
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

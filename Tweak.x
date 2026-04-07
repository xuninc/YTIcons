#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <rootless.h>

#define TweakName @"YTIcons"

static const NSInteger YTIconsSection = 'ytic';
static NSString *ytIconsSearchQuery = nil;
static __weak UISearchBar *ytIconsSearchBar = nil;

@interface YTSettingsSectionItemManager (Tweak)
- (void)updateYTIconsSectionWithEntry:(id)entry;
@end

// Find UISearchBar in a view hierarchy
static UISearchBar *findSearchBar(UIView *view) {
    if ([view isKindOfClass:[UISearchBar class]]) return (UISearchBar *)view;
    for (UIView *subview in view.subviews) {
        UISearchBar *found = findSearchBar(subview);
        if (found) return found;
    }
    return nil;
}

%hook YTSettingsViewController

- (void)loadWithModel:(id)model fromView:(UIView *)view {
    %orig;
    @try {
        if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
            [self setValue:@(YES) forKey:@"_shouldShowSearchBar"];

            // Find the search bar after layout and monitor it directly
            __weak YTSettingsViewController *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!weakSelf) return;
                UISearchBar *bar = findSearchBar(weakSelf.view);
                if (bar) {
                    ytIconsSearchBar = bar;
                    // Add target to the search bar's text field for direct monitoring
                    UITextField *tf = [bar valueForKey:@"searchField"];
                    if (tf) {
                        [tf addTarget:weakSelf action:@selector(yticons_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
                    }
                }
            });
        }
    } @catch (id ex) {}
}

// Direct text field monitoring — works regardless of YouTube's delegate chain
%new
- (void)yticons_searchTextChanged:(UITextField *)textField {
    NSString *text = textField.text;
    ytIconsSearchQuery = text.length > 0 ? text : nil;
    @try {
        YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
        [manager updateYTIconsSectionWithEntry:nil];
    } @catch (id ex) {}
}

// Also hook delegate methods as backup
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        ytIconsSearchQuery = searchText.length > 0 ? searchText : nil;
        %orig;
        @try {
            YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
            [manager updateYTIconsSectionWithEntry:nil];
        } @catch (id ex) {}
        return;
    }
    %orig;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        ytIconsSearchQuery = nil;
        %orig;
        @try {
            YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
            [manager updateYTIconsSectionWithEntry:nil];
        } @catch (id ex) {}
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

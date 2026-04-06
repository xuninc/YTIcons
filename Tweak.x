#import <YouTubeHeader/YTSearchableSettingsViewController.h>
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

- (void)searchBarTextDidChange:(id)searchBar text:(NSString *)text {
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTIconsSection) {
        ytIconsSearchQuery = text.length > 0 ? text : nil;
        YTSettingsSectionItemManager *manager = [self valueForKey:@"_sectionItemManager"];
        [manager updateYTIconsSectionWithEntry:nil];
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
            NSString *title = [NSString stringWithFormat:@"Option %ld - %@", (long)i, iconDescription];

            if (ytIconsSearchQuery) {
                if ([title rangeOfString:ytIconsSearchQuery options:NSCaseInsensitiveSearch].location == NSNotFound)
                    continue;
            }

            YTSettingsSectionItem *option = [YTSettingsSectionItemClass itemWithTitle:title
                accessibilityIdentifier:nil
                detailTextBlock:NULL
                selectBlock:NULL];
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

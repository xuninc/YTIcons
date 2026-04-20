#import <objc/runtime.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <rootless.h>

#define TweakName @"YTIcons"

static const NSInteger YTIconsSection = 'ytic';

#pragma mark - Icon catalog

@interface YTIconSearchEntry : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, assign) NSInteger iconType;
@property (nonatomic, strong) id icon;
@end
@implementation YTIconSearchEntry
@end

static NSArray<YTIconSearchEntry *> *YTIconsAllEntries(void) {
    static NSArray *cached;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:1500];
        Class IconCls = objc_getClass("YTIIcon");
        for (NSInteger i = 0; i < 1500; ++i) {
            @try {
                id icon = [IconCls new];
                [icon setValue:@(i) forKey:@"iconType"];
                NSString *desc = [icon description];
                NSRange r = [desc rangeOfString:@"icon_type: "];
                if (r.location != NSNotFound) desc = [desc substringFromIndex:r.location + r.length];
                NSString *title = [NSString stringWithFormat:@"%ld - %@", (long)i, desc];
                YTIconSearchEntry *e = [YTIconSearchEntry new];
                e.title = title;
                e.searchText = title.lowercaseString;
                e.iconType = i;
                e.icon = icon;
                [out addObject:e];
            } @catch (id ex) {}
        }
        cached = out.copy;
    });
    return cached;
}

static void YTIconsCopyType(NSInteger iconType) {
    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%ld", (long)iconType];
    @try {
        id hudManager = [objc_getClass("GOOHUDManagerInternal") performSelector:@selector(sharedInstance)];
        id message = [objc_getClass("YTHUDMessage") performSelector:@selector(messageWithText:) withObject:[NSString stringWithFormat:@"Copied: %ld", (long)iconType]];
        [hudManager performSelector:@selector(showMessageMainThread:) withObject:message];
    } @catch (id ex) {}
}

#pragma mark - Search controller

@interface YTIconsSearchController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *search;
@property (nonatomic, copy) NSArray<YTIconSearchEntry *> *filtered;
@end

@implementation YTIconsSearchController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Search Icons";
        self.filtered = @[];
        self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
        self.search.searchResultsUpdater = self;
        self.search.obscuresBackgroundDuringPresentation = NO;
        self.search.hidesNavigationBarDuringPresentation = NO;
        self.search.searchBar.placeholder = @"Search icon types";
        self.navigationItem.searchController = self.search;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
        self.definesPresentationContext = YES;
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.search.searchBar becomeFirstResponder];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text.lowercaseString;
    if (q.length == 0) {
        self.filtered = @[];
    } else {
        NSArray<NSString *> *tokens = [q componentsSeparatedByString:@" "];
        NSMutableArray *out = [NSMutableArray array];
        for (YTIconSearchEntry *e in YTIconsAllEntries()) {
            BOOL ok = YES;
            for (NSString *t in tokens) {
                if (t.length == 0) continue;
                if ([e.searchText rangeOfString:t].location == NSNotFound) { ok = NO; break; }
            }
            if (ok) [out addObject:e];
        }
        self.filtered = out.copy;
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *kID = @"YTIconSearchCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:kID];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kID];
    YTIconSearchEntry *e = self.filtered[ip.row];
    cell.textLabel.text = e.title;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.7;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    YTIconSearchEntry *e = self.filtered[ip.row];
    YTIconsCopyType(e.iconType);
    [tv deselectRowAtIndexPath:ip animated:YES];
}

@end

#pragma mark - Section registration

@interface YTSettingsSectionItemManager (Tweak)
- (void)updateYTIconsSectionWithEntry:(id)entry;
@end

%hook YTAppSettingsPresentationData
+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSMutableArray<NSNumber *> *m = [%orig mutableCopy];
    [m insertObject:@(YTIconsSection) atIndex:0];
    return m.copy;
}
%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTIconsSectionWithEntry:(id)entry {
    NSMutableArray *items = [NSMutableArray array];
    Class ItemCls = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsVC = [self valueForKey:@"_settingsViewControllerDelegate"];

    YTSettingsSectionItem *searchRow = nil;
    if ([ItemCls respondsToSelector:@selector(itemWithTitle:titleDescription:accessibilityIdentifier:detailTextBlock:selectBlock:)]) {
        searchRow = [ItemCls itemWithTitle:@"Search Icons"
                          titleDescription:@"Find an icon by name and copy its ID."
                   accessibilityIdentifier:nil
                           detailTextBlock:nil
                               selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            YTIconsSearchController *ctrl = [YTIconsSearchController new];
            UINavigationController *nav = settingsVC.navigationController;
            if (nav) {
                [nav pushViewController:ctrl animated:YES];
            } else {
                UINavigationController *wrap = [[UINavigationController alloc] initWithRootViewController:ctrl];
                [settingsVC presentViewController:wrap animated:YES completion:nil];
            }
            return YES;
        }];
    } else {
        searchRow = [ItemCls itemWithTitle:@"Search Icons"
                   accessibilityIdentifier:nil
                           detailTextBlock:nil
                               selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            YTIconsSearchController *ctrl = [YTIconsSearchController new];
            UINavigationController *nav = settingsVC.navigationController;
            if (nav) {
                [nav pushViewController:ctrl animated:YES];
            } else {
                UINavigationController *wrap = [[UINavigationController alloc] initWithRootViewController:ctrl];
                [settingsVC presentViewController:wrap animated:YES completion:nil];
            }
            return YES;
        }];
    }
    [items addObject:searchRow];

    for (YTIconSearchEntry *e in YTIconsAllEntries()) {
        NSInteger iconType = e.iconType;
        YTSettingsSectionItem *option = [ItemCls itemWithTitle:e.title
                                       accessibilityIdentifier:nil
                                               detailTextBlock:NULL
                                                   selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
            YTIconsCopyType(iconType);
            return YES;
        }];
        @try { [option setValue:e.icon forKey:@"settingIcon"]; } @catch (id ex) {}
        [items addObject:option];
    }

    if ([settingsVC respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)])
        [settingsVC setSectionItems:items forCategory:YTIconsSection title:TweakName icon:nil titleDescription:nil headerHidden:NO];
    else
        [settingsVC setSectionItems:items forCategory:YTIconsSection title:TweakName titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTIconsSection) {
        [self updateYTIconsSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

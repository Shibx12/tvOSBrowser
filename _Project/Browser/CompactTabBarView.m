#import "CompactTabBarView.h"

#import "BrowserTabViewModel.h"
#import "BrowserViewModel.h"
#import "CompactTabCell.h"

static NSString * const kCompactTabCellReuseIdentifier = @"CompactTabCell";

static CGFloat BrowserTabBarSquaredDistance(CGPoint firstPoint, CGPoint secondPoint) {
    CGFloat deltaX = firstPoint.x - secondPoint.x;
    CGFloat deltaY = firstPoint.y - secondPoint.y;
    return (deltaX * deltaX) + (deltaY * deltaY);
}

@interface CompactTabBarView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CompactTabCellDelegate>

@property (nonatomic) BrowserViewModel *viewModel;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray<NSString *> *displayedTabIdentifiers;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *displayedSignatures;
@property (nonatomic, copy) NSString *displayedActiveTabIdentifier;
@property (nonatomic, copy) NSString *preferredTabIdentifier;
@property (nonatomic) BOOL performedInitialReload;

@end

@implementation CompactTabBarView

- (instancetype)initWithViewModel:(BrowserViewModel *)viewModel {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _viewModel = viewModel;
        _displayedTabIdentifiers = @[];
        _displayedSignatures = @{};
        _displayedActiveTabIdentifier = @"";
        _preferredTabIdentifier = @"";
        _chromeFocusEnabled = NO;
        self.backgroundColor = UIColor.clearColor;

        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.minimumLineSpacing = 10.0;
        layout.minimumInteritemSpacing = 10.0;
        layout.sectionInset = UIEdgeInsetsMake(2.0, 2.0, 2.0, 2.0);
        layout.itemSize = CGSizeMake(320.0, 64.0);

        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        _collectionView.backgroundColor = UIColor.clearColor;
        _collectionView.clipsToBounds = YES;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.remembersLastFocusedIndexPath = YES;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView registerClass:CompactTabCell.class forCellWithReuseIdentifier:kCompactTabCellReuseIdentifier];
        [self addSubview:_collectionView];

        [NSLayoutConstraint activateConstraints:@[
            [_collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_collectionView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (NSArray<NSString *> *)currentTabIdentifiers {
    NSMutableArray<NSString *> *identifiers = [NSMutableArray arrayWithCapacity:self.viewModel.tabs.count];
    for (BrowserTabViewModel *tab in self.viewModel.tabs) {
        [identifiers addObject:tab.identifier ?: @""];
    }
    return identifiers;
}

- (NSDictionary<NSString *, NSString *> *)currentSignatures {
    NSMutableDictionary<NSString *, NSString *> *signatures = [NSMutableDictionary dictionary];
    for (BrowserTabViewModel *tab in self.viewModel.tabs) {
        signatures[tab.identifier ?: @""] =
            [NSString stringWithFormat:@"%@|%@|%@",
             tab.title ?: @"",
             tab.URLString ?: @"",
             tab.loading ? @"1" : @"0"];
    }
    return signatures;
}

- (void)applyViewModelUpdate {
    NSArray<NSString *> *newIdentifiers = [self currentTabIdentifiers];
    NSDictionary<NSString *, NSString *> *newSignatures = [self currentSignatures];
    BrowserTabViewModel *activeTab = self.viewModel.activeTab;
    self.preferredTabIdentifier = activeTab.identifier ?: @"";

    if (!self.performedInitialReload) {
        self.performedInitialReload = YES;
        self.displayedTabIdentifiers = newIdentifiers;
        self.displayedSignatures = newSignatures;
        self.displayedActiveTabIdentifier = self.preferredTabIdentifier;
        [self.collectionView reloadData];
        return;
    }

    NSArray<NSString *> *oldIdentifiers = self.displayedTabIdentifiers;
    NSDictionary<NSString *, NSString *> *oldSignatures = self.displayedSignatures;
    NSString *oldActiveIdentifier = self.displayedActiveTabIdentifier;
    NSMutableArray<NSIndexPath *> *deletions = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *insertions = [NSMutableArray array];

    [oldIdentifiers enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger index, BOOL *stop) {
        (void)stop;
        if (![newIdentifiers containsObject:identifier]) {
            [deletions addObject:[NSIndexPath indexPathForItem:index inSection:0]];
        }
    }];
    [newIdentifiers enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger index, BOOL *stop) {
        (void)stop;
        if (![oldIdentifiers containsObject:identifier]) {
            [insertions addObject:[NSIndexPath indexPathForItem:index inSection:0]];
        }
    }];

    self.displayedTabIdentifiers = newIdentifiers;
    self.displayedSignatures = newSignatures;
    self.displayedActiveTabIdentifier = self.preferredTabIdentifier;

    void (^reloadChangedItems)(void) = ^{
        NSMutableArray<NSIndexPath *> *changedItems = [NSMutableArray array];
        [newIdentifiers enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger index, BOOL *stop) {
            (void)stop;
            NSString *oldSignature = oldSignatures[identifier];
            NSString *newSignature = newSignatures[identifier];
            BOOL selectionCouldHaveChanged =
                [identifier isEqualToString:self.preferredTabIdentifier] ||
                [identifier isEqualToString:oldActiveIdentifier];
            if (oldSignature == nil || ![oldSignature isEqualToString:newSignature] || selectionCouldHaveChanged) {
                [changedItems addObject:[NSIndexPath indexPathForItem:index inSection:0]];
            }
        }];
        if (changedItems.count > 0 && self.collectionView.numberOfSections > 0) {
            [self.collectionView reloadItemsAtIndexPaths:changedItems];
        }
        [self scrollActiveTabIntoView];
    };

    if (deletions.count == 0 && insertions.count == 0) {
        reloadChangedItems();
        return;
    }

    [self.collectionView performBatchUpdates:^{
        if (deletions.count > 0) {
            [self.collectionView deleteItemsAtIndexPaths:deletions];
        }
        if (insertions.count > 0) {
            [self.collectionView insertItemsAtIndexPaths:insertions];
        }
    } completion:^(__unused BOOL finished) {
        reloadChangedItems();
    }];
}

- (void)scrollActiveTabIntoView {
    NSInteger activeIndex = self.viewModel.activeTabIndex;
    if (activeIndex < 0 || activeIndex >= self.displayedTabIdentifiers.count) {
        return;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:activeIndex inSection:0];
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)setChromeFocusEnabled:(BOOL)chromeFocusEnabled {
    _chromeFocusEnabled = chromeFocusEnabled;
    self.collectionView.userInteractionEnabled = chromeFocusEnabled;
    for (CompactTabCell *cell in self.collectionView.visibleCells) {
        cell.chromeFocusEnabled = chromeFocusEnabled;
        [cell refreshAppearance];
    }
}

- (void)refreshAppearance {
    for (CompactTabCell *cell in self.collectionView.visibleCells) {
        [cell refreshAppearance];
    }
}

- (UIView *)preferredFocusItem {
    NSInteger index = [self.displayedTabIdentifiers indexOfObject:self.preferredTabIdentifier];
    if (index == NSNotFound) {
        index = self.viewModel.activeTabIndex;
    }
    if (index >= 0 && index < self.displayedTabIdentifiers.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        CompactTabCell *cell = (CompactTabCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        if (cell != nil) {
            return cell;
        }
    }
    return self.collectionView;
}

- (BOOL)containsFocusedItem:(UIView *)focusedItem {
    return focusedItem != nil &&
        (focusedItem == self.collectionView || [focusedItem isDescendantOfView:self.collectionView]);
}

- (NSInteger)tabIndexAtPoint:(CGPoint)point {
    CGPoint collectionPoint = [self.collectionView convertPoint:point fromView:self];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:collectionPoint];
    if (indexPath == nil || indexPath.item >= self.displayedTabIdentifiers.count) {
        return NSNotFound;
    }

    NSString *identifier = self.displayedTabIdentifiers[indexPath.item];
    NSInteger tabIndex = [self.viewModel.tabs indexOfObjectPassingTest:
        ^BOOL(BrowserTabViewModel *tab, NSUInteger index, BOOL *stop) {
            (void)index;
            (void)stop;
            return [tab.identifier isEqualToString:identifier];
        }];
    return tabIndex;
}

- (CompactTabCell *)tabCellAtPoint:(CGPoint)point {
    CGPoint collectionPoint = [self.collectionView convertPoint:point fromView:self];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:collectionPoint];
    if (indexPath == nil) {
        return nil;
    }
    return (CompactTabCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
}

- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point {
    return [self tabIndexAtPoint:point] != NSNotFound;
}

- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point {
    CompactTabCell *cell = [self tabCellAtPoint:point];
    if (cell != nil) {
        CGPoint cellPoint = [cell convertPoint:point fromView:self];
        if ([cell handleCloseButtonAtPoint:cellPoint]) {
            return YES;
        }
    }

    NSInteger tabIndex = [self tabIndexAtPoint:point];
    if (tabIndex == NSNotFound) {
        return NO;
    }
    [self.delegate compactTabBarView:self didSelectTabAtIndex:tabIndex];
    return YES;
}

- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance {
    CGFloat bestSquaredDistance = maximumDistance * maximumDistance;
    CGPoint bestPoint = CGPointZero;
    BOOL foundCandidate = NO;

    for (CompactTabCell *cell in self.collectionView.visibleCells) {
        CGPoint tabCenter = [cell.superview convertPoint:cell.center toView:self];
        CGFloat tabDistance = BrowserTabBarSquaredDistance(point, tabCenter);
        if (tabDistance <= bestSquaredDistance) {
            bestSquaredDistance = tabDistance;
            bestPoint = tabCenter;
            foundCandidate = YES;
        }

        CGPoint closeCenter = [cell closeButtonCenterInView:self];
        CGFloat closeDistance = BrowserTabBarSquaredDistance(point, closeCenter);
        if (closeDistance <= bestSquaredDistance) {
            bestSquaredDistance = closeDistance;
            bestPoint = closeCenter;
            foundCandidate = YES;
        }
    }

    if (foundCandidate && magnetPoint != NULL) {
        *magnetPoint = bestPoint;
    }
    return foundCandidate;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)collectionView;
    return section == 0 ? self.displayedTabIdentifiers.count : 0;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CompactTabCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCompactTabCellReuseIdentifier
                                                                      forIndexPath:indexPath];
    cell.delegate = self;
    cell.chromeFocusEnabled = self.chromeFocusEnabled;
    if (indexPath.item >= self.displayedTabIdentifiers.count) {
        return cell;
    }

    NSString *identifier = self.displayedTabIdentifiers[indexPath.item];
    BrowserTabViewModel *tab = nil;
    for (BrowserTabViewModel *candidate in self.viewModel.tabs) {
        if ([candidate.identifier isEqualToString:identifier]) {
            tab = candidate;
            break;
        }
    }
    if (tab != nil) {
        [cell configureWithTab:tab
                     selected:[identifier isEqualToString:self.viewModel.activeTab.identifier]
                      loading:tab.loading];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionView;
    if (indexPath.item < self.viewModel.tabs.count) {
        [self.delegate compactTabBarView:self didSelectTabAtIndex:indexPath.item];
    }
}

- (NSIndexPath *)indexPathForPreferredFocusedViewInCollectionView:(UICollectionView *)collectionView {
    (void)collectionView;
    NSInteger index = [self.displayedTabIdentifiers indexOfObject:self.preferredTabIdentifier];
    if (index == NSNotFound) {
        index = self.viewModel.activeTabIndex;
    }
    if (index < 0 || index >= self.displayedTabIdentifiers.count) {
        return nil;
    }
    return [NSIndexPath indexPathForItem:index inSection:0];
}

- (void)compactTabCellDidRequestClose:(CompactTabCell *)cell {
    NSInteger index = [self.displayedTabIdentifiers indexOfObject:cell.tabIdentifier];
    if (index != NSNotFound) {
        [self.delegate compactTabBarView:self didRequestCloseTabAtIndex:index];
    }
}

@end

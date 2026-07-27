#import "BrowserFavoritesHomeViewController.h"

#import "BrowserAppearance.h"

static NSString * const kBrowserFavoritesDefaultsKey = @"FAVORITES";
static NSString * const kBrowserFavoriteCellIdentifier = @"BrowserFavoriteCell";
static NSString * const kBrowserFavoritesDidChangeNotification = @"BrowserFavoritesDidChangeNotification";

static CGFloat BrowserFavoritesSquaredDistance(CGPoint firstPoint, CGPoint secondPoint) {
    CGFloat deltaX = firstPoint.x - secondPoint.x;
    CGFloat deltaY = firstPoint.y - secondPoint.y;
    return (deltaX * deltaX) + (deltaY * deltaY);
}

@interface BrowserFavoriteHomeCell : UICollectionViewCell

@property (nonatomic) UIView *tileView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic, getter=isPointerHovered) BOOL pointerHovered;

- (void)configureWithTitle:(NSString *)title addTile:(BOOL)addTile;

@end

@implementation BrowserFavoriteHomeCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;

        _tileView = [UIView new];
        _tileView.translatesAutoresizingMaskIntoConstraints = NO;
        _tileView.backgroundColor = [UIColor colorWithWhite:0.13 alpha:0.96];
        _tileView.layer.cornerRadius = 22.0;
        _tileView.layer.borderWidth = 1.0;
        _tileView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        _tileView.layer.shadowColor = UIColor.blackColor.CGColor;
        _tileView.layer.shadowOffset = CGSizeMake(0.0, 9.0);
        _tileView.layer.shadowRadius = 14.0;
        _tileView.layer.shadowOpacity = 0.22;
        [self.contentView addSubview:_tileView];

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [BrowserAppearance primaryTextColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 2;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_tileView addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_tileView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:5.0],
            [_tileView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-5.0],
            [_tileView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
            [_tileView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_tileView.leadingAnchor constant:18.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_tileView.trailingAnchor constant:-18.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_tileView.centerYAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.pointerHovered = NO;
    self.transform = CGAffineTransformIdentity;
}

- (void)configureWithTitle:(NSString *)title addTile:(BOOL)addTile {
    self.titleLabel.text = title;
    self.tileView.backgroundColor = addTile
        ? [UIColor colorWithWhite:0.18 alpha:0.72]
        : [UIColor colorWithWhite:0.13 alpha:0.96];
}

- (void)setPointerHovered:(BOOL)pointerHovered {
    if (_pointerHovered == pointerHovered) {
        return;
    }
    _pointerHovered = pointerHovered;
    void (^changes)(void) = ^{
        self.transform = pointerHovered ? CGAffineTransformMakeScale(1.06, 1.06) : CGAffineTransformIdentity;
        self.tileView.layer.borderWidth = pointerHovered ? 3.0 : 1.0;
        self.tileView.layer.borderColor = pointerHovered
            ? [BrowserAppearance focusedBorderColor].CGColor
            : [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        self.tileView.layer.shadowOpacity = pointerHovered ? 0.48 : 0.22;
    };
    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseOut
                         animations:changes
                         completion:nil];
    }
}

@end

@interface BrowserFavoritesHomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic) UICollectionViewFlowLayout *collectionLayout;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *favorites;
@property (nonatomic, nullable) NSIndexPath *hoveredIndexPath;

@end

@implementation BrowserFavoritesHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.035 alpha:1.0];

    self.titleLabel = [UILabel new];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"Favorites";
    self.titleLabel.font = [UIFont systemFontOfSize:48.0 weight:UIFontWeightBold];
    self.titleLabel.textColor = [BrowserAppearance primaryTextColor];
    [self.view addSubview:self.titleLabel];

    self.collectionLayout = [UICollectionViewFlowLayout new];
    self.collectionLayout.minimumLineSpacing = 32.0;
    self.collectionLayout.minimumInteritemSpacing = 28.0;
    self.collectionLayout.sectionInset = UIEdgeInsetsMake(10.0, 10.0, 50.0, 10.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                             collectionViewLayout:self.collectionLayout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.userInteractionEnabled = NO;
    [self.collectionView registerClass:BrowserFavoriteHomeCell.class
            forCellWithReuseIdentifier:kBrowserFavoriteCellIdentifier];
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:110.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:160.0],
        [self.titleLabel.heightAnchor constraintEqualToConstant:62.0],

        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:90.0],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-90.0],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:25.0],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self reloadFavorites];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleFavoritesDidChange:)
                                               name:kBrowserFavoritesDidChangeNotification
                                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UIScrollView *)scrollView {
    return self.collectionView;
}

- (void)handleFavoritesDidChange:(NSNotification *)notification {
    (void)notification;
    [self reloadFavorites];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat availableWidth = MAX(CGRectGetWidth(self.collectionView.bounds) - 40.0, 1.0);
    CGFloat itemWidth = floor((availableWidth - (4.0 * self.collectionLayout.minimumInteritemSpacing)) / 5.0);
    CGSize itemSize = CGSizeMake(itemWidth, MAX(176.0, floor(itemWidth * 0.58)));
    if (!CGSizeEqualToSize(self.collectionLayout.itemSize, itemSize)) {
        self.collectionLayout.itemSize = itemSize;
        [self.collectionLayout invalidateLayout];
    }
}

- (void)reloadFavorites {
    NSArray *storedFavorites = [NSUserDefaults.standardUserDefaults arrayForKey:kBrowserFavoritesDefaultsKey];
    NSMutableArray<NSArray<NSString *> *> *validFavorites = [NSMutableArray array];
    for (id object in storedFavorites) {
        if (![object isKindOfClass:NSArray.class]) {
            continue;
        }
        NSArray *entry = (NSArray *)object;
        NSString *URLString = entry.count > 0 && [entry[0] isKindOfClass:NSString.class] ? entry[0] : @"";
        NSString *title = entry.count > 1 && [entry[1] isKindOfClass:NSString.class] ? entry[1] : @"";
        if (URLString.length == 0) {
            continue;
        }
        [validFavorites addObject:@[URLString, title.length > 0 ? title : URLString]];
    }
    self.favorites = validFavorites;
    [self.collectionView reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    (void)collectionView;
    return section == 0 ? self.favorites.count + 1 : 0;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BrowserFavoriteHomeCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:kBrowserFavoriteCellIdentifier
                                                  forIndexPath:indexPath];
    BOOL addTile = indexPath.item == self.favorites.count;
    if (addTile) {
        [cell configureWithTitle:@"Add Website" addTile:YES];
    } else {
        NSArray<NSString *> *favorite = self.favorites[indexPath.item];
        [cell configureWithTitle:favorite[1] addTile:NO];
    }
    cell.pointerHovered = [indexPath isEqual:self.hoveredIndexPath];
    return cell;
}

- (NSIndexPath *)indexPathAtPoint:(CGPoint)point {
    CGPoint collectionPoint = [self.collectionView convertPoint:point fromView:self.view];
    return [self.collectionView indexPathForItemAtPoint:collectionPoint];
}

- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point {
    return [self indexPathAtPoint:point] != nil;
}

- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point {
    NSIndexPath *indexPath = [self indexPathAtPoint:point];
    if (indexPath == nil) {
        return NO;
    }
    if (indexPath.item == self.favorites.count) {
        [self.delegate browserFavoritesHomeViewControllerDidRequestAddFavorite:self];
        return YES;
    }
    if (indexPath.item < self.favorites.count) {
        [self.delegate browserFavoritesHomeViewController:self
                                      didSelectURLString:self.favorites[indexPath.item][0]];
        return YES;
    }
    return NO;
}

- (BOOL)handleLongPressAtPoint:(CGPoint)point {
    NSIndexPath *indexPath = [self indexPathAtPoint:point];
    if (indexPath == nil || indexPath.item >= self.favorites.count) {
        return NO;
    }

    NSArray<NSString *> *favorite = self.favorites[indexPath.item];
    NSString *URLString = favorite.count > 0 ? favorite[0] : @"";
    NSString *title = favorite.count > 1 ? favorite[1] : URLString;
    [self.delegate browserFavoritesHomeViewController:self
                 didRequestActionsForFavoriteAtIndex:(NSUInteger)indexPath.item
                                               title:title
                                           URLString:URLString];
    return YES;
}

- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance {
    CGFloat bestSquaredDistance = maximumDistance * maximumDistance;
    CGPoint bestPoint = CGPointZero;
    BOOL foundCandidate = NO;
    for (BrowserFavoriteHomeCell *cell in self.collectionView.visibleCells) {
        CGPoint cellCenter = [cell.superview convertPoint:cell.center toView:self.view];
        CGFloat squaredDistance = BrowserFavoritesSquaredDistance(point, cellCenter);
        if (squaredDistance <= bestSquaredDistance) {
            bestSquaredDistance = squaredDistance;
            bestPoint = cellCenter;
            foundCandidate = YES;
        }
    }
    if (foundCandidate && magnetPoint != NULL) {
        *magnetPoint = bestPoint;
    }
    return foundCandidate;
}

- (void)updatePointerHoverAtPoint:(CGPoint)point {
    NSIndexPath *nextIndexPath = [self indexPathAtPoint:point];
    if ((nextIndexPath == nil && self.hoveredIndexPath == nil) ||
        [nextIndexPath isEqual:self.hoveredIndexPath]) {
        return;
    }
    NSIndexPath *previousIndexPath = self.hoveredIndexPath;
    self.hoveredIndexPath = nextIndexPath;
    BrowserFavoriteHomeCell *previousCell = previousIndexPath != nil
        ? (BrowserFavoriteHomeCell *)[self.collectionView cellForItemAtIndexPath:previousIndexPath]
        : nil;
    BrowserFavoriteHomeCell *nextCell = nextIndexPath != nil
        ? (BrowserFavoriteHomeCell *)[self.collectionView cellForItemAtIndexPath:nextIndexPath]
        : nil;
    previousCell.pointerHovered = NO;
    nextCell.pointerHovered = YES;
}

- (void)clearPointerHover {
    BrowserFavoriteHomeCell *cell = self.hoveredIndexPath != nil
        ? (BrowserFavoriteHomeCell *)[self.collectionView cellForItemAtIndexPath:self.hoveredIndexPath]
        : nil;
    cell.pointerHovered = NO;
    self.hoveredIndexPath = nil;
}

@end

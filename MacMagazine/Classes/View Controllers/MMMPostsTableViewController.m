//
//  MMMPostsTableViewController.m
//  MacMagazine
//
//  Created by Fernando Saragoca on 6/20/15.
//  Copyright (c) 2015 made@sampa. All rights reserved.
//

#import <PureLayout/PureLayout.h>

#import "MMMPostsTableViewController.h"
#import "MMMFeaturedPostTableViewCell.h"
#import "MMMLabel.h"
#import "MMMPost.h"
#import "MMMPostDetailViewController.h"
#import "MMMPostPresenter.h"
#import "MMMPostTableViewCell.h"
#import "MMMTableViewHeaderView.h"
#import "NSDate+Formatters.h"
#import "SUNCoreDataStore.h"

#pragma mark MMMPostsTableViewController

@implementation MMMPostsTableViewController

#pragma mark - Class Methods

#pragma mark - Getters/Setters

@synthesize fetchedResultsController = _fetchedResultsController;

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[MMMPost entityName]];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO],
                                     [NSSortDescriptor sortDescriptorWithKey:@"pubDate" ascending:NO],
                                     [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"visible = %@", @YES];
    fetchRequest.returnsObjectsAsFaults = NO;
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[SUNCoreDataStore defaultStore].mainQueueContext sectionNameKeyPath:@"date" cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return _fetchedResultsController;
}

#pragma mark - Actions

#pragma mark - Instance Methods

- (BOOL)canFetchMoreData {
    if (self.activityIndicatorView.isAnimating) {
        return NO;
    }
    
    if (self.nextPage <= 1) {
        return NO;
    }
    
    return YES;
}

- (void)configureCell:(__kindof MMMTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    MMMPost *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.layoutMargins = self.tableView.layoutMargins;
    cell.layoutWidth = CGRectGetWidth(self.tableView.bounds);
    
    NSUInteger numberOfRows = [self.tableView numberOfRowsInSection:indexPath.section];
    cell.separatorView.hidden = (indexPath.row + 1 == numberOfRows);

    MMMPostPresenter *presenter = [[MMMPostPresenter alloc] initWithObject:post];
    [presenter setupView:cell];
}

- (void)fetchMoreData {
    if (!self.canFetchMoreData) {
        return;
    }
    
    [self.activityIndicatorView startAnimating];
    [MMMPost getWithPage:self.nextPage success:^(id response) {
        [self.activityIndicatorView stopAnimating];
        self.nextPage += 1;
    } failure:^(NSError *error) {
        [self handleError:error];
        [self.activityIndicatorView stopAnimating];
    }];
}

- (void)handleError:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:error.localizedDescription
                                                                             message:error.localizedFailureReason
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)reloadData {
    if (!self.refreshControl.isRefreshing && self.fetchedResultsController.fetchedObjects.count == 0) {
        [self.refreshControl beginRefreshing];
    }
    
    [MMMPost getWithPage:1 success:^(NSArray *response) {
        self.numberOfResponseObjectsPerRequest = response.count;
        self.nextPage = 2;
        [self.refreshControl endRefreshing];
    } failure:^(NSError *error) {
        [self handleError:error];
        [self.refreshControl endRefreshing];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
    if (selectedIndexPath) {
        MMMPostDetailViewController *detailViewController = segue.destinationViewController;
        detailViewController.posts = self.fetchedResultsController.fetchedObjects;
        detailViewController.post = [self.fetchedResultsController objectAtIndexPath:selectedIndexPath];
    }

    [super prepareForSegue:segue sender:sender];
}

- (void)applyRefreshControlFix {
    if (!self.refreshControl.isRefreshing) {
        [self.tableView sendSubviewToBack:self.refreshControl];
    }
}

#pragma mark - Protocols

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MMMPost *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString *identifier = [MMMPostTableViewCell identifier];
    if (post.featuredValue) {
        identifier = [MMMFeaturedPostTableViewCell identifier];
    }
    
    __kindof MMMTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];

    [cell layoutIfNeeded];
    
    if (CGRectGetWidth(cell.frame) != CGRectGetWidth(tableView.frame)) {
        cell.frame = CGRectMake(0, 0, CGRectGetWidth(tableView.frame), CGRectGetHeight(cell.frame));
        [cell layoutIfNeeded];
        [cell layoutSubviews];
    }

    return cell;
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *segueIdentifier = NSStringFromClass([MMMPostDetailViewController class]);
    [self performSegueWithIdentifier:segueIdentifier sender:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger numberOfSections = [tableView numberOfSections];
    if (indexPath.section + 1 != numberOfSections) {
        return;
    }
    
    NSUInteger numberOfRemainingCells = labs(indexPath.row - [tableView numberOfRowsInSection:indexPath.section]);
    if (numberOfRemainingCells <= 10) {
        [self fetchMoreData];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    MMMTableViewHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[MMMTableViewHeaderView identifier]];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];

    MMMPost *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    MMMPostPresenter *presenter = [[MMMPostPresenter alloc] initWithObject:post];
    headerView.titleLabel.text = presenter.sectionTitle;
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
    MMMPost *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    if ([calendar isDateInToday:post.pubDate]) {
        return 0;
    }
    
    return [MMMTableViewHeaderView height];
}

#pragma mark - NSFetchedResultsController delegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyRefreshControlFix)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self.tableView
                                             selector:@selector(reloadData)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [self.tableView registerNib:[MMMPostTableViewCell nib] forCellReuseIdentifier:[MMMPostTableViewCell identifier]];
    [self.tableView registerNib:[MMMFeaturedPostTableViewCell nib] forCellReuseIdentifier:[MMMFeaturedPostTableViewCell identifier]];
    [self.tableView registerClass:[MMMTableViewHeaderView class] forHeaderFooterViewReuseIdentifier:[MMMTableViewHeaderView identifier]];
    
    self.tableView.estimatedRowHeight = 100;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 60)];
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [footerView addSubview:activityIndicatorView];
    [activityIndicatorView autoCenterInSuperviewMargins];
    self.activityIndicatorView = activityIndicatorView;
    self.tableView.tableFooterView = footerView;

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;

#warning Verificar necessidade com @cesarbars.
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(navigationBar.frame), CGRectGetWidth(navigationBar.frame), 1)];
    separatorView.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
    separatorView.autoresizesSubviews = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [navigationBar addSubview:separatorView];

    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"mm_logo"]];
    logoImageView.frame = CGRectMake(0, 0, 34, 34);
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.navigationItem.titleView = logoImageView;

    [self reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
    if (selectedIndexPath) {
        [self.tableView deselectRowAtIndexPath:selectedIndexPath animated:animated];
    }

    [self.navigationController setToolbarHidden:YES animated:animated];
    self.navigationController.hidesBarsOnSwipe = NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#import "MMMLabel.h"
#import "MMMTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMMFeaturedPostTableViewCell : MMMTableViewCell

@property (nonatomic, weak, nullable) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak, nullable) IBOutlet MMMLabel *headlineLabel;
@property (nonatomic, weak, nullable) IBOutlet MMMLabel *subheadlineLabel;

@property (nonatomic, weak, nullable) IBOutlet NSLayoutConstraint *topSpaceConstraint;
@property (nonatomic, weak, nullable) IBOutlet NSLayoutConstraint *bottomSpaceConstraint;
@property (nonatomic, weak, nullable) IBOutlet NSLayoutConstraint *trailingSpaceConstraint;
@property (nonatomic, weak, nullable) IBOutlet NSLayoutConstraint *leadingSpaceConstraint;

@property (nonatomic) CGFloat headlineTopSpaceConstant;
@property (nonatomic) CGFloat headlineBottomSpaceConstant;

@end

NS_ASSUME_NONNULL_END

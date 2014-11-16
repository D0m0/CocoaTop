
#import <UIKit/UIKit.h>

@interface SetupViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
	//UITableViewController
- (instancetype)initWithColumns:(NSArray *)columns;
@end

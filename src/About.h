#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "Compat.h"

CGFloat cellMargin(UITableView *tableView);
CGFloat cellOrigin(UITableView *tableView);
CGFloat cellWidth(UITableView *tableView);

@interface AboutViewController : UITableViewController<MFMailComposeViewControllerDelegate>
@end

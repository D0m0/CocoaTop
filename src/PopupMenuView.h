#import <UIKit/UIKit.h>

@protocol PopupMenuHandlerProtocol<NSObject>
@optional
- (void)popupMenuTappedItem:(NSInteger)item;
@end

@interface UITableViewControllerWithMenu : UITableViewController<PopupMenuHandlerProtocol>
@property (assign) NSInteger popupMenuSelected;
- (void)popupMenuWithItems:(NSArray *)items selected:(NSInteger)sel aligned:(UIControlContentHorizontalAlignment)align;
- (void)popupMenuLayout;
- (IBAction)popupMenuToggle;
@end

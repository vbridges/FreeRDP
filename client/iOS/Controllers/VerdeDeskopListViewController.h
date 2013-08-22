//
//  VerdeDeskopListViewController.h
//  FreeRDP
//
//  Created by Corey Clayton on 2013-08-20.
//
//

#import <UIKit/UIKit.h>
#import "Misc/VBridge.h"
#import "Bookmark.h"

@interface VerdeDeskopListViewController : UIViewController

@property (nonatomic, readwrite, assign) IBOutlet UITableView *tab;

@property (nonatomic, readwrite, strong) VBridge *vb;

@property (nonatomic, readwrite, strong) ComputerBookmark *bookmark;

@property (readwrite) BOOL startedSession;

- (id)initWithBookmark:(ComputerBookmark *)bookmark;

- (void)doRDP;

@end

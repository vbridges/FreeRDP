//
//  VerdeDeskopListViewController.m
//  FreeRDP
//
//  Created by Corey Clayton on 2013-08-20.
//
//

#import "VerdeDeskopListViewController.h"
#import "RDPSessionViewController.h"

@interface VerdeDeskopListViewController ()

@end

@implementation VerdeDeskopListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithBookmark:(ComputerBookmark *)bookmark
{
	if (!bookmark)
		[NSException raise:NSInvalidArgumentException format:@"%s: params may not be nil.", __func__];
	
	NSLog(@"initialized with bookmark: [%@]", bookmark.uuid);
	
	self.bookmark = [bookmark retain];
	
	NSLog(@"stored as bookmark: [%@]", self.bookmark.uuid);
	
	self.startedSession = NO;
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	
	
	NSString *old_urlStr = @"https://verde01.aus.vbridges.com/";
	NSString *old_usrStr = @"cclayton@aus.vbridges.com";
	NSString *old_pass = @"C0ryClayt0n##";
	//NSString *usrStr = @"cclayton";

	NSString *urlStr = [NSString stringWithString:[self.bookmark.params StringForKey:@"hostname"]];
	
	NSString *usrStr = [NSString stringWithFormat:@"%@@%@",
			    [self.bookmark.params StringForKey:@"username"],
			    [self.bookmark.params StringForKey:@"domain"]];
	
	NSString *pass = [self.bookmark.params StringForKey:@"password"];
	
	
	if (
	    ( [urlStr hasPrefix:@"http"] == NO ) &&
	    ( [urlStr hasPrefix:@"https"] == NO ) )
	{
		//append http by default
		urlStr = [NSString stringWithFormat:@"https://%@", urlStr];
	}
	
	if ( [urlStr hasSuffix:@"/"] == NO )
	{
		urlStr = [NSString stringWithFormat:@"%@/", urlStr];
	}
	
	
	NSLog(@"old url: %@", old_urlStr);
	NSLog(@"url: %@", urlStr);
	NSLog(@"old usr: %@", old_usrStr);
	NSLog(@"usr: %@", usrStr);
	
	self.vb = [[VBridge alloc] initWithUsername:usrStr Password:pass URL:urlStr completionHandler:^{
		NSLog(@"==Complete==");
		
		[self.tab reloadData];
	}];
	
	[self.vb getDesktops];
	
	//NSLog(@"end of didLoad = urlStr: [%@] [%p]", urlStr, urlStr);
	//NSLog(@"end of didLoad = vb.url: [%@] [%p]", self.vb.broker_url, self.vb.broker_url);
}

- (void)viewWillAppear:(BOOL)animated
{
	if (self.startedSession == YES)
	{
		self.startedSession = NO;
		[[self navigationController] popViewControllerAnimated:NO];
	}
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

//TABLE STUFF

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger num;
	
	num = [self.vb getNumDesktops];
	
	NSLog(@"table should have %d rows", num);
	
	return num;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MainCell"];
	
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MainCell"];
	}
	
	cell.textLabel.text = [self.vb getDesktopNameByNum:indexPath.row];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSLog(@"Selected index %d", indexPath.row);
	
	self.vb.selected_hostname = [[self.vb getDesktopNameByNum:indexPath.row] retain];
	
	NSLog(@"Corresponding server: %@", self.vb.selected_hostname);
	
	[self.vb callWhenGotTicket:^{
		NSLog(@"--> got ticket: [%@]", self.vb.security_ticket);
		NSLog(@"--> bookmark [%@]", self.bookmark.uuid);
		[self doRDP];
	}];
	
	[self.vb startDesktopByNum:indexPath.row];
	
	
	
	//[[self navigationController] popViewControllerAnimated:YES];
}

- (void)doRDP
{
	self.startedSession = YES;
	
	// create rdp session
	RDPSession* session = [[[RDPSession alloc] initWithBookmark:self.bookmark andVB:self.vb] autorelease];
	UIViewController* ctrl = [[[RDPSessionViewController alloc] initWithNibName:@"RDPSessionView" bundle:nil session:session] autorelease];
	[ctrl setHidesBottomBarWhenPushed:YES];
	
	[[self retain] autorelease];
	
	//NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:[[self navigationController] viewControllers]];
	//[viewControllers removeLastObject];
	//[viewControllers addObject:ctrl];
	
	//[[self navigationController] popViewControllerAnimated:NO];
	[[self navigationController] pushViewController:ctrl animated:YES];
	//[_active_sessions addObject:session];
}

@end


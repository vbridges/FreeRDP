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
		
	self.bookmark = [bookmark retain];
		
	self.startedSession = NO;
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	
	
	//NSString *old_urlStr = @"https://verde01.aus.vbridges.com/";
	//NSString *old_usrStr = @"cclayton@aus.vbridges.com";
	//NSString *old_pass = @"C0ryClayt0n##";
	//NSString *usrStr = @"cclayton";

	NSString *urlStr = [NSString stringWithString:[self.bookmark.params StringForKey:@"hostname"]];
	
	NSString *domain = [self.bookmark.params StringForKey:@"domain"];
	
	NSString *usrStr;
	
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
	
	if ([domain length] > 0)
	{
		usrStr = [NSString stringWithFormat:@"%@@%@",
			  [self.bookmark.params StringForKey:@"username"],
			  domain];
	}
	else
	{
		NSString *realm;
		
		//strip the https://
		NSString *stripped = [urlStr substringWithRange:NSMakeRange(8, [urlStr length] - 9)];
		
		//now we should have either x.y.z.com/derp or x.y.z.com
		
		//if we have a / then realm is derp
		if ([stripped rangeOfString:@"/"].length == 1)
		{
			NSArray *parts = [stripped componentsSeparatedByString:@"/"];
			realm = [parts objectAtIndex:[parts count]-1];
		}
		else //else y.z.com
		{
			NSArray *parts = [stripped componentsSeparatedByString:@"."];
			
			realm = @"";
			for (int i = 1; i < [parts count]; i++)
			{
				realm = [NSString stringWithFormat:@"%@.%@", realm, [parts objectAtIndex:i]];
			}
			
			//remove .prefix
			realm = [realm substringFromIndex:1];
		}
				
		usrStr = [NSString stringWithFormat:@"%@@%@",
			  [self.bookmark.params StringForKey:@"username"],
			  realm];
	}
	
	self.vb = [[VBridge alloc] initWithUsername:usrStr Password:pass URL:urlStr completionHandler:^{
		
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
	self.vb.selected_hostname = [[self.vb getDesktopNameByNum:indexPath.row] retain];
		
	[self.vb callWhenGotTicket:^{
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


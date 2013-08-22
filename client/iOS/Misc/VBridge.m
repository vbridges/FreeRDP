//
//  VBridge.m
//  Restless
//
//  Created by Corey Clayton on 2013-08-10.
//  Copyright (c) 2013 Derp Heavy Industries. All rights reserved.
//

#import "VBridge.h"

@implementation VBridge

static const char _base64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const short _base64DecodingTable[256] = {
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2, -1, -1, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62, -2, -2, -2, 63,
	52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2, -2, -2, -2, -2,
	-2,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2, -2, -2, -2, -2,
	-2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2
};

+ (NSString *)encodeBase64WithString:(NSString *)strData {
	return [VBridge encodeBase64WithData:[strData dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSString *)encodeBase64WithData:(NSData *)objData {
	const unsigned char * objRawData = [objData bytes];
	char * objPointer;
	char * strResult;
	
	// Get the Raw Data length and ensure we actually have data
	int intLength = [objData length];
	if (intLength == 0) return nil;
	
	// Setup the String-based Result placeholder and pointer within that placeholder
	strResult = (char *)calloc((((intLength + 2) / 3) * 4) + 1, sizeof(char));
	objPointer = strResult;
	
	// Iterate through everything
	while (intLength > 2) { // keep going until we have less than 24 bits
		*objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
		*objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
		*objPointer++ = _base64EncodingTable[((objRawData[1] & 0x0f) << 2) + (objRawData[2] >> 6)];
		*objPointer++ = _base64EncodingTable[objRawData[2] & 0x3f];
		
		// we just handled 3 octets (24 bits) of data
		objRawData += 3;
		intLength -= 3;
	}
	
	// now deal with the tail end of things
	if (intLength != 0) {
		*objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
		if (intLength > 1) {
			*objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
			*objPointer++ = _base64EncodingTable[(objRawData[1] & 0x0f) << 2];
			*objPointer++ = '=';
		} else {
			*objPointer++ = _base64EncodingTable[(objRawData[0] & 0x03) << 4];
			*objPointer++ = '=';
			*objPointer++ = '=';
		}
	}
	
	// Terminate the string-based result
	*objPointer = '\0';
	
	// Create result NSString object
	NSString *base64String = [NSString stringWithCString:strResult encoding:NSASCIIStringEncoding];
	
	// Free memory
	free(strResult);
	
	return base64String;
}


-(id)initWithUsername:(NSString *)user Password:(NSString *)pass URL:(NSString *)u completionHandler:(void (^)())cb
{
	
	_username = user;
	_password = pass;
	_broker_url = u;
	//_fake_url = [NSString stringWithString:u];
	_completionCallback = [cb copy];
	
	NSLog(@"VBridge: init called with username: [%@], pass: [%@], url: [%@]", self.username, self.password, self.broker_url);
	
	_upn = nil;
	_verde_status = nil;
	_security_ticket = nil;
	
	NSString *id_pass = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
	NSString *b64 = [VBridge encodeBase64WithString:id_pass];
	self.auth_header = [NSString stringWithFormat:@"Basic %@", b64];
	
	self.names = [NSMutableArray arrayWithCapacity:64];
	
	NSLog(@"names initialized with %d elements", [self.names count]);
	
	return self;
}


-(void)getDesktops
{
	NSString *old_auth_header = @"Basic Y2NsYXl0b25AYXVzLnZicmlkZ2VzLmNvbTpDMHJ5Q2xheXQwbiMj";
	
	NSString *fullURL = [NSString stringWithFormat:@"%@_mpcdesktops?version=v3", _broker_url];
	
	//self.auth_header = old_auth_header;
	
	NSLog(@"old_auth: %@", old_auth_header);
	//NSLog(@"auth: %@", self.auth_header);
	
	
	/* create the request */
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
	
	[request addValue:self.auth_header forHTTPHeaderField:@"Authorization"];
	
	/* create the connection */
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	
	/* ensure the connection was created */
	if (self.connection)
	{
		/* initialize the buffer */
		self.buffer = [[NSMutableData data] retain];
		
		/* start the request */
		[self.connection start];
	}
	else
	{
		NSLog(@"Connection Failed");
	}
	
	NSLog(@"getdesktops return -- url -> [%@] [%p]", _broker_url, _broker_url);
}

-(void)startDesktopByNum:(NSUInteger)dnum
{
	NSLog(@"sdbn(%d)", dnum);
	NSLog(@"starting desktop [%@]", [self.names objectAtIndex:dnum]);
	NSLog(@"url = %@", _broker_url);
	NSString *old_auth_header = @"Basic Y2NsYXl0b25AYXVzLnZicmlkZ2VzLmNvbTpDMHJ5Q2xheXQwbiMj";
	
	NSString *fullURL = [NSString stringWithFormat:@"%@_mpcstart?image=%@&protocol=0", _broker_url, [self.names objectAtIndex:dnum]];
	
	NSLog(@"fullURL = [%@]", fullURL);
	
	/* create the request */
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
	
	[request addValue:self.auth_header forHTTPHeaderField:@"Authorization"];
	
	/* create the connection */
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	
	/* ensure the connection was created */
	if (self.connection)
	{
		/* initialize the buffer */
		self.buffer = [NSMutableData data];
		
		/* start the request */
		[self.connection start];
	}
	else
	{
		NSLog(@"Connection Failed");
	}

}

-(NSUInteger)getNumDesktops
{
	return [self.names count];
}

-(NSString *)getDesktopNameByNum:(NSUInteger)dnum
{
	if ( [self.names count] > dnum)
	{
		return [self.names objectAtIndex:dnum];
	}
	
	return nil;
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	/* clear the connection &amp; the buffer */
	self.connection = nil;
	self.buffer     = nil;
	
	NSLog(@"Connection failed! Error - %@ %@",
	      [error localizedDescription],
	      [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSLog(@"response 1-- url -> [%@] [%p]", _broker_url, _broker_url);
	
	/* reset the buffer length each time this is called */
	[self.buffer setLength:0];
	
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
	
	NSLog(@"Receive Response: status=%d", [httpResponse statusCode]);
	
	NSDictionary *headers = [httpResponse allHeaderFields];
	
	if ([headers objectForKey:@"X-Auth-upn"] != nil)
	{
		self.upn = [headers objectForKey:@"X-Auth-upn"];
		NSLog(@"Got upn! [%@]", self.upn);
	}
	
	if ([headers objectForKey:@"X-Verde-Status"] != nil)
	{
		self.verde_status = [headers objectForKey:@"X-Verde-Status"];
		NSLog(@"Got verde status! [%@]", self.verde_status);
	}
	
	NSLog(@"response 2-- url -> [%@] [%p]", _broker_url, _broker_url);
	
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSLog(@"Receive Data");
	/* Append data to the buffer */
	[self.buffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSLog(@"Connection Finished Loading");
	NSLog(@"loaded -- url -> [%@]", _broker_url);
	
	NSString *body = [[NSString alloc] initWithData:self.buffer encoding:NSUTF8StringEncoding];
	
	NSLog(@"String sent from server %@", body);
	
	NSArray *lines = [body componentsSeparatedByString:@"\n"];
	
	if (self.verde_status != nil)
	{
		
		//not sure if ticket is first line or the entire body
		self.security_ticket = [lines objectAtIndex:0];
	
		NSLog(@"Got security ticket (valid for 60s)");
		NSLog(@"ticket = [%@]", self.security_ticket);
		
		//_gotTicketCallback();
		
		return;
	}
	
	/////
	// testing
	/////
	/*
	NSString *testBody = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n",
			      @"#version:3",
			      @"name:CORP-WIN732|title:CORP-WIN732|os:0|modes:7000|updated:1374930198|modem:3|dsl:3|broadband:3|lan:3|usb:0 0 0 0|printing_enable:true|clipboard:true|has_vdagent:true",
			      @"name:FAKE-WIN864|title:CORP-WIN732|os:0|modes:7000|updated:1374930198|modem:3|dsl:3|broadband:3|lan:3|usb:0 0 0 0|printing_enable:true|clipboard:true|has_vdagent:true",
			      @"name:DERP-WINNT4|title:CORP-WIN732|os:0|modes:7000|updated:1374930198|modem:3|dsl:3|broadband:3|lan:3|usb:0 0 0 0|printing_enable:true|clipboard:true|has_vdagent:true"];
	
	NSArray *lines = [testBody componentsSeparatedByString:@"\n"];
	*/
	//end test
	
	
	NSString *firstLine = [lines objectAtIndex:0];
	
	//check the version key:value
	NSArray *fields = [firstLine componentsSeparatedByString:@":"];
	if ( ([[fields objectAtIndex:0] isEqualToString:@"#version"] == YES) &&
	    ([[fields objectAtIndex:1] isEqualToString:@"3"] == YES) )
	{
		NSLog(@"Version 3 protocol :)");
	}
	else
	{
		NSLog(@"Unsupported protocol version!");
	}
	
	//now we want the names
	
	for (int i = 1; i < [lines count]; i++)
	{
		NSString *currentLine = [lines objectAtIndex:i];
		
		fields = [currentLine componentsSeparatedByString:@"|"];
		
		//now we just get the name (may have to iterate over all pairs in the future)
		NSArray *pair = [[fields objectAtIndex:0] componentsSeparatedByString:@":"];
		
		if ([[pair objectAtIndex:0] isEqualToString:@"name"] == YES)
		{
			NSString *name = [pair objectAtIndex:1];
			
			NSArray *os_pair = [[fields objectAtIndex:2] componentsSeparatedByString:@":"];
			NSString *os = [os_pair objectAtIndex:1];
			
			NSLog(@"Got name: [%@] os: [%@]", name, os);
			
			if ([os intValue] == 1)
			{
				//ignore SPICE only hosts
				NSLog(@"Ignoring SPICE only host %@", name);
				continue;
			}
			
			[self.names addObject:name];
		}
	}
	/*
	NSString *secondLine = [lines objectAtIndex:1];
	
	fields = [secondLine componentsSeparatedByString:@"|"];
	
	NSArray *pair = [[fields objectAtIndex:0] componentsSeparatedByString:@":"];
	
	if ([[pair objectAtIndex:0] isEqualToString:@"name"] == YES)
	{
		NSString *name = [pair objectAtIndex:1];
		
		NSLog(@"Got name: [%@]", name);
		[self.names addObject:name];
	}
	 */
	
	/*
	 for (NSString *part in lines)
	 {
	 NSLog(@"-> [%@]", part);
	 }
	 */
	
	NSLog(@"finished -- url -> [%@]", _broker_url);
	
	_completionCallback();
}


-(BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space
{
	NSLog(@"auth -- url -> [%@] [%p]", _broker_url, _broker_url);
	
	if( [[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust] )
	{
		// Note: this is presently only called once per server (or URL?) until you restart the app
		
		NSLog(@"Self signed cert: allowing");
		return YES;
		
	}
	
	//NSLog(@"Other authentication method, aborting.");
	return YES;
}

-(void)callWhenGotTicket:(void (^)())cb
{
	_gotTicketCallback = [cb copy];
}

-(void)dealloc
{
	NSLog(@"dealloc VBridge");
	
	[super dealloc];
}

@end

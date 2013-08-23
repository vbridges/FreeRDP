//
//  VBridge.h
//  Restless
//
//  Created by Corey Clayton on 2013-08-10.
//  Copyright (c) 2013 Derp Heavy Industries. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VBridge : NSObject

@property (copy) NSString *username;
@property (copy) NSString *password;
//@property (copy) NSString *fake_url;
@property (copy) NSString *broker_url;

@property (copy) NSString *auth_header;

@property (nonatomic, strong) NSMutableArray *names;


@property (nonatomic, strong) NSMutableData   *buffer;
@property (nonatomic, strong) NSURLConnection *connection;

@property (copy) NSString *upn;
@property (copy) NSString *verde_status;

@property (copy) NSString *security_ticket;
@property (copy) NSString *selected_hostname;

@property (nonatomic, copy) void (^completionCallback)();

@property (nonatomic, copy) void (^gotTicketCallback)();


+ (NSString *)encodeBase64WithString:(NSString *)strData;

+ (NSString *)encodeBase64WithData:(NSData *)objData;


-(id)initWithUsername:(NSString*)user Password:(NSString*)pass URL:(NSString*)u completionHandler:(void(^)())cb;

-(void)getDesktops;
-(void)startDesktopByNum:(NSUInteger)dnum;

-(NSUInteger)getNumDesktops;
-(NSString *)getDesktopNameByNum:(NSUInteger)dnum;

-(void)callWhenGotTicket:(void (^)())cb;

@end

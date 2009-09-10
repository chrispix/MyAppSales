//
//  iTunesConnect.m
//  ASiST
//
//  Created by Oliver Drobnik on 19.12.08.
//  Copyright 2008 drobnik.com. All rights reserved.
//

#import "iTunesConnect.h"
#import "Database.h"
#import "DDData.h"
#import "ASiSTAppDelegate.h"

#import "App.h"
#import "Report.h"
#import "Country.h"

#import "NSString+Helpers.h"


// Static variables for compiled SQL queries. This implementation choice is to be able to share a one time
// compilation of each query across all instances of the class. Each time a query is used, variables may be bound
// to it, it will be "stepped", and then reset for the next usage. When the application begins to terminate,
// a class method will be invoked to "finalize" (delete) the compiled queries - this must happen before the database
// can be closed.
//static sqlite3_stmt *insert_statement = nil;
//static sqlite3_stmt *insert_statement_sale = nil;
//static sqlite3_stmt *reportid_statement = nil;
//static sqlite3_stmt *insertreport_statement = nil;

// private methods
@interface iTunesConnect ()
- (BOOL) shouldAutoSync;
@end






@implementation iTunesConnect

@synthesize /*username, password, */lastSuccessfulLoginTime, account;

- (id) init
{
	syncing = NO;
	
	
	if (self = [super init])
	{
		return self;
	}
	return nil;
}

- (id) initWithAccount:(Account *)itcAccount
{
	if (self = [self init])
	{
		account = [itcAccount retain];
		
		// only auto-sync if we did not already download a daily report today
		if ([self shouldAutoSync])
		{
			[self loginAndSync];
		}
		
		return self;
	}
	return nil;
}

- (void) sync
{
	// only synch if we are not already doing so
	if (syncing)
	{
		return;
	}
	
	syncing = YES;
	
	/*
	 if (loginPostURL&&![loginPostURL isEqualToString:@""])
	 {
	 [self toggleNetworkIndicator:YES];
	 
	 loginStep = 3;
	 [receivedData setLength:0];
	 
	 NSMutableURLRequest *theRequest;
	 theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginPostURL]
	 cachePolicy:NSURLRequestUseProtocolCachePolicy
	 timeoutInterval:30.0];
	 [theRequest setHTTPMethod:@"POST"];
	 [theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
	 
	 //create the body
	 NSMutableData *postBody = [NSMutableData data];
	 [postBody appendData:[@"11.7=Summary&11.9=Daily&hiddenDayOrWeekSelection=Daily&hiddenSubmitTypeName=ShowDropDown" dataUsingEncoding:NSUTF8StringEncoding]];
	 [theRequest setHTTPBody:postBody];
	 
	 theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
	 [self setStatus:@"Retrieving Day Options"];
	 }
	 else
	 {
	 [self loginAndSync];
	 }
	 
	 */
	
	[self loginAndSync];  // since we remove the cookie we always login fully
}



- (void) loginAndSync
{
	//[self importReportsFromDocumentsFolder];
	//return self;
	
	if (!(account.account&&account.password&&![account.account isEqualToString:@""]&&![account.password isEqualToString:@""]))
	{
		return;
	}
	
	syncing = YES;
	
	// remove all previous cookies
	NSHTTPCookieStorage *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	
	for (NSHTTPCookie *oneCookie in [cookies cookies])
	{
		NSLog(@"Remove Cookie: %@", oneCookie);
		[cookies deleteCookie:oneCookie];
	}
	
	// open login page
	loginStep = 0;
	NSString *URL=[NSString stringWithFormat:@"https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa"];
	NSMutableURLRequest *theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]
															cachePolicy:NSURLRequestReloadIgnoringCacheData
														timeoutInterval:30.0];
	[self toggleNetworkIndicator:YES];
	[self setStatus:@"Opening HTTPS Connection"];
	
	theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
	if (theConnection) 
	{
		
		// Create the NSMutableData that will hold
		// the received data
		// receivedData is declared as a method instance elsewhere
		if (!receivedData)
		{
			receivedData=[[NSMutableData data] retain];
		}
	}
	else
	{
		// inform the user that the download could not be made
	}
}

- (BOOL) shouldAutoSync
{
	// only auto-sync if we did not already download a daily report today
	Report *lastDailyReport = [[Database sharedInstance] latestReportOfType:ReportTypeDay];
	NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	
	NSDateComponents *lastComps = [gregorian components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:lastDailyReport.downloadedDate];
	NSDateComponents *todayComps = [gregorian components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[NSDate date]];
	
	return !((lastComps.day == todayComps.day)&&(lastComps.month == todayComps.month)&&(lastComps.year == todayComps.year));
}

- (void)dealloc {
	[lastSuccessfulLoginTime release];
	
	[dateFormatterToRead release];
	[weekOptions release];
	[dayOptions release];
	[loginPostURL release];
	[receivedData release];
	[super dealloc];
}



- (void) failLogin
{
	loginPostURL = @"";
	syncing = NO;
	[self toggleNetworkIndicator:NO];
	self.lastSuccessfulLoginTime = nil;
	
	UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
													 message:@"Your login or password was entered incorrectly."
													delegate:self
										   cancelButtonTitle:@"Ok"
										   otherButtonTitles:nil, nil];
	[alert show];
	[alert release];
	[self setStatus:nil];
}



#pragma mark HTTP call back methods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	
    // it can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    // receivedData is declared as a method instance elsewhere
    [receivedData setLength:0];
	NSLog(@"%d %@", [response statusCode], [response allHeaderFields]);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the receivedData
    // receivedData is declared as a method instance elsewhere
    [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self toggleNetworkIndicator:NO];
    // release the connection, and the data object
    //[connection release]; is autoreleased
    // receivedData is declared as a method instance elsewhere
    [receivedData release];
	receivedData = nil;
	
	[self setStatus:[error localizedDescription]];
	[self setStatus:nil];
	syncing = NO;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *URL;
	NSMutableURLRequest *theRequest;
	NSMutableData *postBody;
	
	NSString *sourceSt = [[[NSString alloc] initWithBytes:[receivedData bytes] length:[receivedData length] encoding:NSASCIIStringEncoding] autorelease];
	//NSLog(sourceSt);
	
	switch (loginStep) {
		case 0:   // received Login page
		{
			// search for outer post url
			NSRange formRange = [sourceSt rangeOfString:@"method=\"post\" action=\""];
			
			if (formRange.location!=NSNotFound)
			{
				NSRange quoteRange = [sourceSt rangeOfString:@"\"" options:NSLiteralSearch range:NSMakeRange(formRange.location+formRange.length, 100)];
				if (quoteRange.length)
				{
					URL = [@"https://itunesconnect.apple.com" stringByAppendingString:[sourceSt substringWithRange:NSMakeRange(formRange.location+formRange.length, quoteRange.location-formRange.location-formRange.length)]];
					loginStep = 7;
					[receivedData setLength:0];
					theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]
													   cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
												   timeoutInterval:30.0];
					
					[theRequest setHTTPMethod:@"POST"];
					[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
					
					//create the body
					postBody = [NSMutableData data];
					[postBody appendData:[[NSString stringWithFormat:@"theAccountName=%@&theAccountPW=%@&1.Continue.x=20&1.Continue.y=6&theAuxValue=", 
										   [account.account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
										   [account.password stringByUrlEncoding]] dataUsingEncoding:NSUTF8StringEncoding]];
					[theRequest setHTTPBody:postBody];
					
					theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
					[self setStatus:@"Sending Login Information"];
				}
			}
			else
			{
				syncing = NO;
				[self toggleNetworkIndicator:NO];
				self.lastSuccessfulLoginTime = nil;
				
				UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Cannot access Login"
																 message:@"iTunes Connect is probably down for maintenance. Please try again later."
																delegate:self
													   cancelButtonTitle:@"Ok"
													   otherButtonTitles:nil, nil];
				[alert show];
				[alert release];
				[self setStatus:nil];
			}
			
			
			break;
		}
		case 7: // Logged into iTunes Connect
		{
			
			/*
			 //successful login sets three cookies: 
			 
			 <NSHTTPCookie version:0 name:@"DefaultAppleID" value:@"oliver%40drobnik.com" expiresDate:@"2009-09-30 08:41:06 +0200" created:@"274196465.998941" sessionOnly:FALSE domain:@".apple.com" path:@"/" secure:FALSE comment:@"(null)" commentURL:@"(null)" portList:(null)>
			 <NSHTTPCookie version:0 name:@"ds01" value:@"A19278AA7C76801EDD26613A7ECCD163DFC3D9F65EBF6811032F6C3AE96B9300FCCF4A934B47B42BE51D346953899F58B0AFB0803BCD287571400E548000BD63" expiresDate:@"2010-09-09 08:41:06 +0200" created:@"274196465.998917" sessionOnly:FALSE domain:@".apple.com" path:@"/" secure:FALSE comment:@"(null)" commentURL:@"(null)" portList:(null)>
			 <NSHTTPCookie version:0 name:@"myacinfo" value:@"NTY7aykMTLfvowkz3o7O1~FLudkwrRH7noBBMdBzH5gIfngERJlXHQ2LQIU5f0m0vVypuylDwTZbeX4@" expiresDate:@"(null)" created:@"274196465.998954" sessionOnly:TRUE domain:@".apple.com" path:@"/" secure:FALSE comment:@"(null)" commentURL:@"(null)" portList:(null)>
			 */
			
			// check if we received a login session cookies
			NSArray *sessionCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:@"http://www.apple.com"]];
			
			if ([sessionCookies count])
			{
				
				URL = @"http://itts.apple.com/cgi-bin/WebObjects/Piano.woa";
				
				loginStep = 2;
				
				[receivedData setLength:0];
				
				theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]
												   cachePolicy:NSURLRequestUseProtocolCachePolicy
											   timeoutInterval:60.0];  // might take long
				
				[theRequest setHTTPMethod:@"GET"];
				
				theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
				[self setStatus:@"Accessing Sales Reports"];
			}
			else
			{
				[self failLogin];
			}
			
			break;
		}
			
			
			
		case 1: // Received Answer to Login
		{
			// search for frmVendorPage URL
			NSRange formRange = [sourceSt rangeOfString:@"<form method=\"post\" name=\"frmVendorPage\" action=\""];
			
			if (formRange.location!=NSNotFound)
			{
				// found the string, now find it's end
				NSRange quoteRange = [sourceSt rangeOfString:@"\"" options:NSLiteralSearch range:NSMakeRange(formRange.location+formRange.length, 100)];
				if (quoteRange.length==1)
				{
					self.lastSuccessfulLoginTime = [NSDate date];
					URL = [@"https://itts.apple.com" stringByAppendingString:[sourceSt substringWithRange:NSMakeRange(formRange.location+formRange.length, quoteRange.location-formRange.location-formRange.length)]];
					
					loginStep = 2;
					
					[receivedData setLength:0];
					
					theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]
													   cachePolicy:NSURLRequestUseProtocolCachePolicy
												   timeoutInterval:30.0];
					
					[theRequest setHTTPMethod:@"POST"];
					[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
					
					//create the body
					postBody = [NSMutableData data];
					[postBody appendData:[@"11.7=Summary&11.9=Daily&hiddenDayOrWeekSelection=Daily&hiddenSubmitTypeName=ShowDropDown" dataUsingEncoding:NSUTF8StringEncoding]];
					
					//add the body to the post
					[theRequest setHTTPBody:postBody];
					
					theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
					[self setStatus:@"Retrieving Day Options"];
					
				}
				else
				{
					loginPostURL = @"";
					syncing = NO;
				}
			}
			else
			{
				// Login Failed
				[self failLogin];
				
			}
			break;
		}
		case 2:  // select Day
		{
			// search for frmVendorPage URL
			NSRange formRange = [sourceSt rangeOfString:@"<form method=\"post\" name=\"frmVendorPage\" action=\""];
			
			if (formRange.location!=NSNotFound)
			{
				// found the string, now find it's end
				NSRange quoteRange = [sourceSt rangeOfString:@"\"" options:NSLiteralSearch range:NSMakeRange(formRange.location+formRange.length, 100)];
				if (quoteRange.length==1)
				{
					URL = [@"https://itts.apple.com" stringByAppendingString:[sourceSt substringWithRange:NSMakeRange(formRange.location+formRange.length, quoteRange.location-formRange.location-formRange.length)]];
					
					
					loginStep = 3;
					[receivedData setLength:0];
					theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]
													   cachePolicy:NSURLRequestUseProtocolCachePolicy
												   timeoutInterval:30.0];
					[theRequest setHTTPMethod:@"POST"];
					[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
					
					//create the body
					NSMutableData *postBody = [NSMutableData data];
					[postBody appendData:[@"11.7=Summary&11.9=Daily&hiddenDayOrWeekSelection=Daily&hiddenSubmitTypeName=ShowDropDown" dataUsingEncoding:NSUTF8StringEncoding]];
					[theRequest setHTTPBody:postBody];
					
					theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
					[self setStatus:@"Retrieving Day Options"];
				}
			}
			else
			{
				loginPostURL = @"";
				syncing = NO;
				[self toggleNetworkIndicator:NO];
				
			}
			break;
		}
		case 3:
		{
			// search for frmVendorPage URL
			NSRange formRange = [sourceSt rangeOfString:@"<form method=\"post\" name=\"frmVendorPage\" action=\""];
			
			if (formRange.location!=NSNotFound)
			{
				// found the string, now find it's end
				NSRange quoteRange = [sourceSt rangeOfString:@"\"" options:NSLiteralSearch range:NSMakeRange(formRange.location+formRange.length, 100)];
				if (quoteRange.length==1)
				{
					URL = [@"https://itts.apple.com" stringByAppendingString:[sourceSt substringWithRange:NSMakeRange(formRange.location+formRange.length, quoteRange.location-formRange.location-formRange.length)]];
					
					loginPostURL = [[NSString alloc] initWithString:URL];
					loginStep = 4;
					
					
					NSRange selectRange = [sourceSt rangeOfString:@"<select Id=\"dayorweekdropdown\""];
					
					dayOptions = nil;
					if (selectRange.location!=NSNotFound)
					{
						NSRange endSelectRange = [sourceSt rangeOfString:@"</select>" options:NSLiteralSearch range:NSMakeRange(selectRange.location, 1000)];
						dayOptions = [[[sourceSt substringWithRange:NSMakeRange(selectRange.location, endSelectRange.location - selectRange.location + endSelectRange.length)] optionsFromSelect] retain];
						dayOptionsIdx = 0;
						
						
						if (![self requestDailyReport])
						{
							loginStep = 5;
							
							[receivedData setLength:0];
							theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginPostURL]
															   cachePolicy:NSURLRequestUseProtocolCachePolicy
														   timeoutInterval:30.0];
							[theRequest setHTTPMethod:@"POST"];
							[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
							
							//create the body
							NSMutableData *postBody = [NSMutableData data];
							[postBody appendData:[@"11.7=Summary&11.9=Weekly&hiddenDayOrWeekSelection=Weekly&hiddenSubmitTypeName=ShowDropDown" dataUsingEncoding:NSUTF8StringEncoding]];
							[theRequest setHTTPBody:postBody];
							
							theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
							[self setStatus:@"Retrieving Week Options"];
							
							
						}
					}
				}
			}
			else
			{
				loginPostURL = @"";
				syncing = NO;
				[self toggleNetworkIndicator:NO];
			}
			break;
		}
		case 4:  // we should be getting day report data
		{
			if (![sourceSt hasPrefix:@"<"])
			{
				NSData *decompressed = [receivedData gzipInflate];
				NSString *decompStr = [[NSString alloc] initWithBytes:[decompressed bytes] length:[decompressed length] encoding:NSASCIIStringEncoding];
				
				[DB insertReportFromText:decompStr];
				[decompStr release];
				
				if (![self requestDailyReport])
				{
					
					loginStep = 5;
					
					[receivedData setLength:0];
					theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginPostURL]
													   cachePolicy:NSURLRequestUseProtocolCachePolicy
												   timeoutInterval:30.0];
					[theRequest setHTTPMethod:@"POST"];
					[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
					
					//create the body
					NSMutableData *postBody = [NSMutableData data];
					[postBody appendData:[@"11.7=Summary&11.9=Weekly&hiddenDayOrWeekSelection=Weekly&hiddenSubmitTypeName=ShowDropDown" dataUsingEncoding:NSUTF8StringEncoding]];
					[theRequest setHTTPBody:postBody];
					
					theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
					[self setStatus:@"Retrieving Week Options"];
					
				}
			}
			break;
		}
			
			
		case 5:
		{
			loginStep = 6;
			NSRange selectRange = [sourceSt rangeOfString:@"<select Id=\"dayorweekdropdown\""];
			
			weekOptions = nil;
			if (selectRange.location!=NSNotFound)
			{
				NSRange endSelectRange = [sourceSt rangeOfString:@"</select>" options:NSLiteralSearch range:NSMakeRange(selectRange.location, 1000)];
				weekOptions = [[[sourceSt substringWithRange:NSMakeRange(selectRange.location, endSelectRange.location - selectRange.location + endSelectRange.length)] optionsFromSelect] retain];
				weekOptionsIdx = 0;
				
				[self requestWeeklyReport];
				//[self syncReports];
			}
			break;
		}
			
		case 6:  // we should be getting week report data
		{
			if (![sourceSt hasPrefix:@"<"])
			{
				NSData *decompressed = [receivedData gzipInflate];
				NSString *decompStr = [[NSString alloc] initWithBytes:[decompressed bytes] length:[decompressed length] encoding:NSUTF8StringEncoding];
				
				[DB insertReportFromText:decompStr];
				[decompStr release];
				
				[self requestWeeklyReport];
			}
			break;
		}
			
			/*	default:  // any other step means report data
			 {
			 if (![sourceSt hasPrefix:@"<"])
			 {
			 NSData *decompressed = [receivedData gzipInflate];
			 NSString *decompStr = [[NSString alloc] initWithBytes:[decompressed bytes] length:[decompressed length] encoding:NSASCIIStringEncoding];
			 
			 [self addReportToDBfromString:decompStr forDay:[dayOptions objectAtIndex:dayOptionsIdx]];
			 
			 [decompStr release];
			 
			 [self syncReports];
			 }
			 }*/
	}
}

#pragma mark Status Indicators

- (void) setStatus:(NSString *)message
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"StatusMessage" object:nil userInfo:(id)message];
}

- (void) toggleNetworkIndicator:(BOOL)isON
{
	// forward to appDelegate
	ASiSTAppDelegate *appDelegate = (ASiSTAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	[appDelegate toggleNetworkIndicator:isON];
}



#pragma mark Report Downloading

// look at dayOptions and request to download a report if not in DB
- (BOOL) requestDailyReport
{
	NSMutableURLRequest *theRequest;
	
	if ([dayOptions count]>dayOptionsIdx)
	{
		NSString *formDate = [[dayOptions objectAtIndex:dayOptionsIdx] stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
		if ([DB reportIDForDateString:[dayOptions objectAtIndex:dayOptionsIdx] type:ReportTypeDay region:ReportRegionUnknown])
		{
			// Already downloaded this day
			dayOptionsIdx++;
			return [self requestDailyReport];
		}
		[receivedData setLength:0];
		
		theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginPostURL]
										   cachePolicy:NSURLRequestUseProtocolCachePolicy
									   timeoutInterval:30.0];
		
		[theRequest setHTTPMethod:@"POST"];
		[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
		
		//create the body
		NSMutableData *postBody = [NSMutableData data];
		NSString *body = [NSString stringWithFormat:@"11.7=Summary&11.9=Daily&11.11.1=%@&hiddenDayOrWeekSelection=%@&hiddenSubmitTypeName=Download", formDate, formDate];
		[postBody appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
		
		//add the body to the post
		[theRequest setHTTPBody:postBody];
		
		theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
		[self setStatus:[NSString stringWithFormat:@"Loading Day Report for %@", [dayOptions objectAtIndex:dayOptionsIdx]]];
		
		dayOptionsIdx ++;
		return YES;
	}
	else
	{
		return NO;
	}
}

// look at dayOptions and request to download a report if not in DB
- (BOOL) requestWeeklyReport
{
	NSMutableURLRequest *theRequest;
	
	if ([weekOptions count]>weekOptionsIdx)
	{
		NSString *formDate = [[weekOptions objectAtIndex:weekOptionsIdx] stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
		if ([DB reportIDForDateString:[weekOptions objectAtIndex:weekOptionsIdx] type:ReportTypeWeek region:ReportRegionUnknown])
		{
			// Already downloaded this week
			weekOptionsIdx++;
			return [self requestWeeklyReport];
		}
		[receivedData setLength:0];
		
		theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginPostURL]
										   cachePolicy:NSURLRequestUseProtocolCachePolicy
									   timeoutInterval:30.0];
		
		[theRequest setHTTPMethod:@"POST"];
		[theRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
		
		//create the body
		NSMutableData *postBody = [NSMutableData data];
		NSString *body = [NSString stringWithFormat:@"11.7=Summary&11.9=Weekly&11.13.1=%@&hiddenDayOrWeekSelection=%@&hiddenSubmitTypeName=Download", formDate, formDate];
		[postBody appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
		
		//add the body to the post
		[theRequest setHTTPBody:postBody];
		
		theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
		//NSLog(@"Step 4 - Request report for week %@", formDate);
		[self setStatus:[NSString stringWithFormat:@"Loading Week Report for %@", [weekOptions objectAtIndex:weekOptionsIdx]]];
		weekOptionsIdx++;
		
		return YES;
	}
	else
	{
		[self toggleNetworkIndicator:NO];
		[self setStatus:@"Synchronization Done"];
		[self setStatus:nil];
		
		syncing = NO;
		
		// need to redo totals now
		[DB getTotals];
		
		return NO;
	}
}





@end
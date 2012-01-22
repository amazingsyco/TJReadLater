// TJReadItLater
// By Tim Johnsen

#import "TJReadItLater.h"

#warning Missing Read It Later Credentials
#define API_KEY @"<Your API Key Here>"
#define APP_NAME @"<Your App Name Here>"

@implementation TJReadItLater

#pragma mark -
#pragma mark Strings

+ (NSString *)name {
	return @"Read It Later";
}

#pragma mark -
#pragma mark Private

+ (NSURLRequest *)_requestForAuthWithUsername:(NSString *)username password:(NSString *)password {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://readitlaterlist.com/v2/auth?username=%@&password=%@&apikey=%@", username, password, API_KEY]]];	
	[request setValue:APP_NAME forHTTPHeaderField:@"User-Agent"];
		
	return request;
}

+ (NSURLRequest *)_requestForSaveURL:(NSString *)url title:(NSString *)title {
	NSString *requestURL = [NSString stringWithFormat:@"https://readitlaterlist.com/v2/add?username=%@&password=%@&apikey=%@&url=%@", [self username], [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@Password", NSStringFromClass(self)]], API_KEY, url];
	if (title) {
		requestURL = [requestURL stringByAppendingFormat:@"&title=%@", title];
	}
	requestURL = [requestURL stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestURL]];
	[request setValue:APP_NAME forHTTPHeaderField:@"User-Agent"];
	
	return request;
}

@end
// TJReadItLater
// By Tim Johnsen

#import "TJReadItLater.h"

#define API_KEY @"<Your API Key Here>"
#define APP_NAME @"<Your App Name Here>"

@implementation TJReadItLater

#pragma mark -
#pragma mark Strings

+ (NSString *)name {
	return @"Read It Later";
}

#pragma mark -
#pragma mark Authorization

+ (void)authorizeWithUsername:(NSString *)username password:(NSString *)password callback:(void (^)(BOOL success))callback {
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://readitlaterlist.com/v2/auth?username=%@&password=%@&apikey=%@", username, password, API_KEY]]];
		
		[request setValue:APP_NAME forHTTPHeaderField:@"User-Agent"];
		
		NSURLResponse *response = nil;
		NSError *error = nil;
		
		[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		
		BOOL success = !error && [(NSHTTPURLResponse *)response statusCode] == 200;
		
		if (success) {
			[[NSUserDefaults standardUserDefaults] setObject:username forKey:[NSString stringWithFormat:@"%@Username", [[self class] description]]];
			[[NSUserDefaults standardUserDefaults] setObject:password forKey:[NSString stringWithFormat:@"%@Password", [[self class] description]]];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		
		if (callback) {
			dispatch_async(dispatch_get_main_queue(), ^{
				callback(success);
			});
		}
	});
}

#pragma mark -
#pragma mark URL Saving

+ (void)saveURL:(NSString *)url title:(NSString *)title callback:(void (^)(BOOL success))callback {
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		
		NSString *requestURL = [NSString stringWithFormat:@"https://readitlaterlist.com/v2/add?username=%@&password=%@&apikey=%@&url=%@", [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@Username", [[self class] description]]], [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@Password", [[self class] description]]], API_KEY, url];
		
		if (title) {
			requestURL = [requestURL stringByAppendingFormat:@"&title=%@", title];
		}
						 
		requestURL = [requestURL stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestURL]];
		
		[request setValue:APP_NAME forHTTPHeaderField:@"User-Agent"];
		
		NSURLResponse *response = nil;
		NSError *error = nil;
		
		[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		
		BOOL success = !error && [(NSHTTPURLResponse *)response statusCode] == 200;
		
		if (callback) {
			dispatch_async(dispatch_get_main_queue(), ^{
				callback(success);
			});
		}
	});
}

@end
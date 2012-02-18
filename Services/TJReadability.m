// TJReadability
// By Tim Johnsen

#import "TJReadability.h"
#import "TJReadLaterConfig.h"
#import "OAHMAC_SHA1SignatureProvider.h"

#pragma mark -
#pragma mark Categories

// NSURL Category for OAuth
// Courtesy of SSOAuthKit: 

@interface NSURL (OAuth)

- (NSString *)OAuthString;

@end

@implementation NSURL (OAuth)

// OAuth Spec 9.1.2 "Construct Request URL"
// @see http://oauth.net/core/1.0#rfc.section.9.1.2
- (NSString *)OAuthString {
	NSString *lowercaseScheme = [[self scheme] lowercaseString];
	
	// Check port - only show port if nonstandard
	NSString *port = @"";
	if ([self port]) {
		NSInteger portInteger = [[self port] integerValue];
		if (!(([lowercaseScheme isEqualToString:@"http"] && portInteger == 80) || 
			  ([lowercaseScheme isEqualToString:@"https"] && portInteger == 443)
			  )) {
			port = [NSString stringWithFormat:@":%i", portInteger];
		}
	}
	
	// Build string
	return [[NSString stringWithFormat:@"%@://%@%@%@", lowercaseScheme, [self host], port, [self path]] lowercaseString];
}

@end

// NSString URL Encoding Category
// Courtesy of SSToolkit: http://sstoolk.it/

@interface NSString (URLEncoding)

- (NSString *)URLEncodedString;

@end

@implementation NSString (URLEncoding)

- (NSString *)URLEncodedString {
	return [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8) autorelease];
}

@end

#pragma mark -
#pragma mark TJReadability

@implementation TJReadability

#pragma mark -
#pragma mark Strings

+ (NSString *)name {
	return @"Readability";
}

+ (NSString *)signUpURL {
	return @"https://www.readability.com/readers/register";
}

#pragma mark -
#pragma mark Authorization Details

+ (BOOL)isLoggedIn {
	return ([self username] != nil);
}

+ (void)logout {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@Username", NSStringFromClass(self)]];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@Token", NSStringFromClass(self)]];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@TokenSecret", NSStringFromClass(self)]];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark Authorization

+ (void)authorizeWithUsername:(NSString *)username password:(NSString *)password callback:(void (^)(BOOL))callback {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.readability.com/api/rest/v1/oauth/access_token"]];
		[request setHTTPMethod:@"POST"];
		
		// OAuth fields
		// Courtesy of SSOAuthKit: https://github.com/samsoffes/ssoauthkit
		
		// Signature provider
		id<OASignatureProviding> signatureProvider = [[OAHMAC_SHA1SignatureProvider alloc] init];
		
		// Timestamp
		NSString *timestamp = [NSString stringWithFormat:@"%d", time(NULL)];
		
		// Nonce
		CFUUIDRef theUUID = CFUUIDCreate(NULL);
		CFStringRef UUIDString = CFUUIDCreateString(NULL, theUUID);
		CFRelease(theUUID);
		NSString *nonce = [(NSString *)UUIDString autorelease];
		
		// OAuth Spec, Section 9.1.1 "Normalize Request Parameters"
		// Build a sorted array of both request parameters and OAuth header parameters
		
		
		
		NSMutableArray *parameterPairs = [[NSMutableArray alloc] initWithObjects:
										  [NSDictionary dictionaryWithObjectsAndKeys:(NSString *)kTJReadLaterReadabilityOAuthConsumerKey, @"value", @"oauth_consumer_key", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:[signatureProvider name], @"value", @"oauth_signature_method", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:timestamp, @"value", @"oauth_timestamp", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:nonce, @"value", @"oauth_nonce", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:@"1.0", @"value", @"oauth_version", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:username, @"value", @"x_auth_username", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:password, @"value", @"x_auth_password", @"key", nil],
										  [NSDictionary dictionaryWithObjectsAndKeys:@"client_auth", @"value", @"x_auth_mode", @"key", nil],
										  nil];
		
		NSArray *sortedPairs = [parameterPairs sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[obj1 objectForKey:@"key"] compare:[obj2 objectForKey:@"key"]];
		}];
		[parameterPairs release];
		
		NSMutableArray *pieces = [[NSMutableArray alloc] init];
		for (NSDictionary *pair in sortedPairs) {
			[pieces addObject:[NSString stringWithFormat:@"%@=%@", [[pair objectForKey:@"key"] URLEncodedString], [[pair objectForKey:@"value"] URLEncodedString]]];
		}
		NSString *normalizedRequestParameters = [pieces componentsJoinedByString:@"&"];
		[pieces release];

		// OAuth Spec, Section 9.1.2 "Concatenate Request Elements"
		NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@", [request HTTPMethod],
										 [[[request URL] OAuthString] URLEncodedString],
										 [normalizedRequestParameters URLEncodedString]];
		
		// Sign
		// Secrets must be urlencoded before concatenated with '&'
		NSString *secret = [NSString stringWithFormat:@"%@&", [(NSString *)kTJReadLaterReadabilityOAuthConsumerSecret URLEncodedString]];
		NSString *signature = [signatureProvider signClearText:signatureBaseString withSecret:secret];

		NSString *oauthHeader = [NSString stringWithFormat:@"OAuth oauth_nonce=\"%@\", oauth_signature_method=\"%@\", oauth_timestamp=\"%@\", oauth_consumer_key=\"%@\", oauth_signature=\"%@\", oauth_version=\"1.0\"",
								 [nonce URLEncodedString],
								 [[signatureProvider name] URLEncodedString],
								 [timestamp URLEncodedString],
								 [(NSString *)kTJReadLaterReadabilityOAuthConsumerKey URLEncodedString],
								 [signature URLEncodedString]];
		
		[signatureProvider release];
		
		[request setValue:oauthHeader forHTTPHeaderField:@"Authorization"];
		
		// xAuth Fields
		
		[request setHTTPBody:[[NSString stringWithFormat:@"x_auth_username=%@&x_auth_password=%@&x_auth_mode=client_auth", username, password] dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Other Fields
		
		[request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
		[request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
		[request setValue:@"close" forHTTPHeaderField:@"Connection"];
		
		NSError *error = nil;
		
		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
		
		NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
		// Interpret the result
		BOOL success = NO;
		
		if (!error) {
			
			NSArray *fragments = [string componentsSeparatedByString:@"&"];
			NSMutableDictionary *result = [[[NSMutableDictionary alloc] init] autorelease];
			
			for (NSString *fragment in fragments) {
				if ([fragment rangeOfString:@"="].location != NSNotFound) {
					NSString *key = [[fragment componentsSeparatedByString:@"="] objectAtIndex:0];
					NSString *value = [[fragment componentsSeparatedByString:@"="] objectAtIndex:1];
					[result setObject:value forKey:key];
				}
			}
			
			if ([result objectForKey:@"oauth_token"] && [result objectForKey:@"oauth_token_secret"]) {
				[[NSUserDefaults standardUserDefaults] setObject:username forKey:[NSString stringWithFormat:@"%@Username", NSStringFromClass(self)]];
				[[NSUserDefaults standardUserDefaults] setObject:[result objectForKey:@"oauth_token"] forKey:[NSString stringWithFormat:@"%@Token", NSStringFromClass(self)]];
				[[NSUserDefaults standardUserDefaults] setObject:[result objectForKey:@"oauth_token_secret"] forKey:[NSString stringWithFormat:@"%@TokenSecret", NSStringFromClass(self)]];
				[[NSUserDefaults standardUserDefaults] synchronize];
				
				success = YES;
			}
		}
		
		if (callback) {
			dispatch_async(dispatch_get_main_queue(), ^{
				callback(success);
			});
		}
	});
}

// TODO: Get Auth Working
// TODO: Abstract out OAuth request creator

@end

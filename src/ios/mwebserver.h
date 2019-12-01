@interface MWebCFHTTP: NSObject
@property(readonly) NSString *HTTPMethod;
@property(readonly) NSData *HTTPBody;
@property(readonly) NSString *HTTPVersion;
@property(readonly) NSURL *URL;
@property(readonly) NSInteger statusCode;
@property(readonly) NSDictionary *allHeaderFields;
@property(readonly) bool requestComplete;
@property(readonly) NSUInteger contentLength;
- (void)sendTextResponse:(NSString*)text headers:(NSDictionary*)headers;
- (void)sendDataResponse:(NSData *)data mimeType:(NSString*)mimeType headers:(NSDictionary*)headers;
- (void)sendHTTPError:(NSString*)description statusCode:(int)statusCode;
- (bool)didProvideAllData;
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;
- (NSString *)valueForHTTPHeaderField:(NSString *)field;
@end

@protocol MWebHTTPDelegate<NSObject>
@required
- (bool) handleMWebCFHTTPRequest:(MWebCFHTTP*)request;
@end

@interface MWebHTTPServer: NSObject
@property (nonatomic) NSObject<MWebHTTPDelegate>* delegate;
@property(readonly) int port;
- (bool)start:(NSError **)error port:(NSInteger)port;
- (void)stop;
@end

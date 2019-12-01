#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <unistd.h>
#include <assert.h>
#import <CFNetwork/CFSocketStream.h>
#import "mwebserver.h"
#define MYASSERT assert
static NSString * const MWebServerErrorDomain = @"MWebServerErrorDomain";
typedef enum {
      kMWebServerCouldNotBindToIPv4Address = 1,
      kMWebServerCouldNotBindToIPv6Address = 2,
      kMWebServerNoSocketsAvailable = 3,
      kMWebServerPortChanged = 4
} MWebServerErrorCode;

static NSString* dateStringForHTTP()
{
  static NSDateFormatter* fmt;
  if (fmt==nil) {
    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
    NSLocale* enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [fmt setLocale:enUSPOSIXLocale];
    [fmt setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [fmt setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
  }
  return [fmt stringFromDate:[NSDate date]];
}

static void debugDealloc(NSObject* o)
{
  NSLog(@"dealloc %@",o);
}

@interface MWebHTTPConnection: NSObject<NSStreamDelegate>
{
  //write relate members
  NSOutputStream* _oStream;
  NSMutableData* _writeData;
  int _writeIndex;
  bool _hasSpaceAvail;
  //read related members
  NSInputStream* _iStream;
  NSMutableData* _recData;
  CFSocketNativeHandle _sock;
  MWebHTTPServer* __weak _httpServ;
  MWebCFHTTP* _cfhttp;
}
- (id)initWithIn:(NSInputStream*)nsin andOut:(NSOutputStream*)nsout andSocket:(CFSocketNativeHandle)sock andServer:(MWebHTTPServer*)srv;
- (void)sendData:(NSData*)data;
- (void)writeOutput;
@end

@interface MWebCFHTTP()
{
  CFHTTPMessageRef _msg;
  MWebHTTPConnection* _conn;
  NSUInteger _currBodyLen;
  bool _requestComplete;
  int _ftnum;
  NSData* _writeData;
  NSUInteger _contentLength;
}
@end

@implementation MWebCFHTTP
- (id)initWithConnection:(MWebHTTPConnection*)conn
{
  self = [super init];
  if (self==nil) {return nil;}
  _conn = conn; //intentional retain cycle
  _msg = CFHTTPMessageCreateEmpty(NULL,TRUE);
  return self;
}

- (id)initResponse:(NSInteger)statusCode andDescription:(NSString *)description andVersion:(NSString *)version
{
  self = [super init];
  if (self==nil) {return nil;}
  _msg = CFHTTPMessageCreateResponse(NULL,(CFIndex)statusCode,(__bridge CFStringRef)description,(__bridge CFStringRef)version);
  return self;
}

-(void)sendTextResponse:(NSString *)text headers:(NSDictionary*)headers
{
  NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding];
  [self sendDataResponse:data mimeType:@"text/plain; charset=utf-8" headers:headers];
}

-(void)sendDataInt:(MWebCFHTTP*)cfheader data:(NSData*)data
{
  NSData *headerData=[cfheader getSerializedData];
  _writeData=data;
  [_conn sendData:headerData];
}

-(void)sendDataResponse:(NSData *)data mimeType:(NSString*)mimeType headers:(NSDictionary*)headers
{
  MWebCFHTTP* resp=[[MWebCFHTTP alloc] initResponse:200 andDescription:@"description" andVersion:((NSString *)kCFHTTPVersion1_1)];
  [resp setValue:mimeType forHTTPHeaderField:@"Content-Type"];
  NSString* lenStr=[NSString stringWithFormat:@"%lu",(unsigned long)data.length];
  [resp setValue:lenStr forHTTPHeaderField:@"Content-Length"];
  [resp setValue:dateStringForHTTP() forHTTPHeaderField:@"Date"];
  [resp setValue:@"*" forHTTPHeaderField:@"Access-Control-Allow-Origin"];
  [resp setValue:@"Content-Type" forHTTPHeaderField:@"Access-Control-Allow-Headers"];
  [resp setValue:@"bytes" forHTTPHeaderField:@"Accept-Ranges"];
  [resp setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
  if (headers!=nil) {
    for(NSString* field in headers.allKeys) {
      [resp setValue:headers[field] forHTTPHeaderField:field];
    }
  }
  [self sendDataInt:resp data:data];
}

-(void)sendHTTPError:(NSString*)fileName statusCode:(int)statusCode
{
  NSString* description=[NSString stringWithFormat:@"Not found:%@",fileName];
  MWebCFHTTP* resp=[[MWebCFHTTP alloc] initResponse:statusCode andDescription:description andVersion:((NSString *)kCFHTTPVersion1_1)];
  NSString* html=[NSString stringWithFormat:@"<!DOCTYPE html><html>\n"
                  "<head>\n"
                  "<style type=\"text/css\">\n"
                  "body {font-size: 20pt;}\n"
                  "button {font-size: 40pt;}\n"
                  "</style>\n"
                  "</head>\n"
                  "<body><h1>ERROR, did not find:</h1><h1>%@</h1>\n"
                  "<button onclick=\"myclick()\">Close</button>\n"
                  "<script>\n"
                  "function myclick() {\n"
                  "  window.webkit.messageHandlers.observeClose.postMessage(true);\n"
                  "}\n"
                  "</script>\n"
                  "</body>\n"
                  "</html>",
                  fileName];
  NSData *descdata=[html dataUsingEncoding:NSUTF8StringEncoding];
  NSString* lenStr=[NSString stringWithFormat:@"%lu",(unsigned long)descdata.length];
  [resp setValue:lenStr forHTTPHeaderField:@"Content-Length"];
  [resp setValue:@"text/html; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
  [resp setValue:@"close" forHTTPHeaderField:@"Connection"];
  [self sendDataInt:resp data:descdata];
}

-(bool)didProvideAllData
{
  //flush the body here
  if (_writeData!=nil) {
    NSData* data=_writeData;
    _writeData=nil;
    [_conn sendData:data];
    return true;
  }
  return false;
}

- (bool)appendData:(NSData *)data
{
  return CFHTTPMessageAppendBytes(_msg, [data bytes], [data length]);
}

- (bool)appendDataUntilComplete:(NSData*)data
{
  MYASSERT(_requestComplete==false);
  MYASSERT([self appendData:data]==true);
  if (![self isHeaderComplete]) {
    return false;
  }
  NSString* lenStr=[self valueForHTTPHeaderField:@"Content-Length"];
  if (lenStr!=nil && ![lenStr isEqualToString:@"0"]) {
    NSInteger len=lenStr.integerValue;
    MYASSERT(len>0);
    _contentLength=len;
    if (_currBodyLen==0) {
      //the first time we actually need to know the body data/length
      NSData* bodyData=self.HTTPBody;
      _currBodyLen = bodyData.length;
    } else {
      //all subsequent invocations of this method just add the data length
      //because the accumulation of body data has already started
      _currBodyLen += data.length;
    }
    if (_currBodyLen<len) {
      NSLog(@"wait again, current bodylen is:%lu",(unsigned long)_currBodyLen);
      return false;
    }
    MYASSERT(_currBodyLen==len);
  }
  _requestComplete=true;
  return true;
}

- (bool)isHeaderComplete
{
  return CFHTTPMessageIsHeaderComplete(_msg);
}

- (NSString *)HTTPMethod
{
  return (__bridge_transfer NSString *)CFHTTPMessageCopyRequestMethod(_msg);
}

- (NSString *)HTTPVersion
{
  return (__bridge_transfer NSString *)CFHTTPMessageCopyVersion(_msg);
}

- (NSData *)HTTPBody
{
  return (__bridge_transfer NSData *)CFHTTPMessageCopyBody(_msg);
}

- (void)setBodyData:(NSData *)body
{
  CFHTTPMessageSetBody(_msg, (__bridge CFDataRef)body);
}

- (NSURL *)URL
{
  return (__bridge_transfer NSURL *)CFHTTPMessageCopyRequestURL(_msg);
}

- (NSInteger)statusCode
{
  return (NSInteger)CFHTTPMessageGetResponseStatusCode(_msg);
}

- (NSDictionary *)allHeaderFields
{
  return (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(_msg);
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field;
{
  return (__bridge_transfer NSString *)CFHTTPMessageCopyHeaderFieldValue(_msg, (__bridge CFStringRef)field);
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
  CFHTTPMessageSetHeaderFieldValue(_msg,(__bridge CFStringRef)field,(__bridge CFStringRef)value);
}

- (NSData *)getSerializedData
{
  return (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(_msg);
}

- (void)dealloc
{
  debugDealloc(self);
  MYASSERT(_msg!=nil);
  CFRelease(_msg);
}
@end

@interface MWebHTTPServer()
{
  CFSocketRef _socket;
  int _port;
}
@end
@implementation MWebHTTPServer
- (void)dealloc 
{
  debugDealloc(self);
  [self stop];
}

static bool createClientConnectionInt(CFSocketNativeHandle sock,MWebHTTPConnection* conn,MWebHTTPServer* srv) {
  int flag = 1;
  setsockopt(sock, IPPROTO_TCP, TCP_NODELAY,(char *)&flag, sizeof(int));
  bool result=true;
  CFReadStreamRef readStream = NULL;
  CFWriteStreamRef writeStream = NULL;
  CFStreamCreatePairWithSocket( kCFAllocatorDefault, sock, &readStream, &writeStream );
  if( readStream && writeStream ) {
    CFReadStreamSetProperty( readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue );
    CFWriteStreamSetProperty( writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue );
    conn=[conn initWithIn:(__bridge NSInputStream*)readStream
                                     andOut:(__bridge NSOutputStream*)writeStream
                andSocket:sock andServer:srv];
  } else {
    //destroy native socket
    close( sock );
    result=false;
  }
  if( readStream ) {CFRelease( readStream );}
  if( writeStream ) {CFRelease( writeStream );}
  return result;
}

static void AcceptCallBack(CFSocketRef accsock, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
  if( type == kCFSocketAcceptCallBack ) {
    CFSocketNativeHandle sock = *(CFSocketNativeHandle*) data;
    MWebHTTPConnection* conn=[MWebHTTPConnection alloc];
    MWebHTTPServer* srv=(__bridge MWebHTTPServer*)info;
    createClientConnectionInt(sock,conn,srv);
  }
}

- (bool)start:(NSError **)error port:(NSInteger)port
{
  MYASSERT(error!=nil);
  CFSocketContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
  _socket = CFSocketCreate( kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                            kCFSocketAcceptCallBack, ( CFSocketCallBack ) & AcceptCallBack, &context );
  if (_socket == NULL) {
    *error = [[NSError alloc]
              initWithDomain : MWebServerErrorDomain
                        code : kMWebServerNoSocketsAvailable
              userInfo :  @{ NSLocalizedDescriptionKey :@"no socket available" }];
    return false;
  }
  NSInteger extport = port;
  int opt = 1;
  setsockopt( CFSocketGetNative( _socket ), SOL_SOCKET, SO_REUSEADDR, (void*) &opt, sizeof ( opt ) );
  const int maxtries=(extport==0) ? 1: 20;
  for (int i=0; i< maxtries; i++) {
    struct sockaddr_in saddr;
    memset( &saddr, 0, sizeof ( saddr ) );
    saddr.sin_len = sizeof ( saddr );
    saddr.sin_family = AF_INET;
    saddr.sin_port = htons(extport+i);
#if TARGET_IPHONE_SIMULATOR //avoid firewall disturbing
    saddr.sin_addr.s_addr = htonl( INADDR_LOOPBACK );
#else
    saddr.sin_addr.s_addr = htonl( extport==0 ? INADDR_LOOPBACK: INADDR_ANY );
#endif
    NSData* naddr = [NSData dataWithBytes : &saddr length : sizeof ( saddr )];

    if( CFSocketSetAddress( _socket, (__bridge CFDataRef) naddr ) != kCFSocketSuccess) {
      if (i==maxtries-1) {
        _port=-1;
        *error = [[NSError alloc]
                initWithDomain : MWebServerErrorDomain
                          code : kMWebServerCouldNotBindToIPv4Address
                      userInfo :  @{ NSLocalizedDescriptionKey :
                                     [NSString stringWithFormat:@"Can't bind port on %d",(int)extport ]
                                   }];
        [self stop];
        return false;
      }
    } else {
      NSData *addr = (__bridge NSData *)(CFSocketCopyAddress(_socket));
      memcpy(&saddr, [addr bytes], [addr length]);
      int actualport=ntohs(saddr.sin_port);
      _port=actualport;
      if (extport!=0 && actualport!=extport) {
        *error = [[NSError alloc]
                initWithDomain : MWebServerErrorDomain
                code : kMWebServerPortChanged
                userInfo :  @{ NSLocalizedDescriptionKey :
                                 [NSString stringWithFormat:@"port on %d instead of %d",(int)extport+i,(int)extport ]
                               }];
      }
      break;
    }
  }
  //set up the run loop source for the socket
  CFRunLoopRef cfrl = CFRunLoopGetCurrent();
  CFRunLoopSourceRef rlsource = CFSocketCreateRunLoopSource( kCFAllocatorDefault, _socket, 0 );
  CFRunLoopAddSource( cfrl, rlsource, kCFRunLoopCommonModes );
  CFRelease( rlsource );
  return true;
}

- (void)stop 
{
  if( _socket ) {
    CFSocketInvalidate( _socket );
    CFRelease( _socket );
  }
  _socket = NULL;
}
@end

@implementation MWebHTTPConnection
static void streamOpen(NSStream* stream,NSObject<NSStreamDelegate>* delegate)
{
  [stream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
  stream.delegate = delegate;
  [stream scheduleInRunLoop :[NSRunLoop currentRunLoop] forMode : NSRunLoopCommonModes];
  [stream open]; 
}

static void streamClose(NSStream* stream)
{
  [stream close];
  [stream removeFromRunLoop :[NSRunLoop currentRunLoop] forMode : NSRunLoopCommonModes];
  [stream setDelegate:nil];
}

- (id)initWithIn:(NSInputStream*)nsin andOut:(NSOutputStream*)nsout andSocket:(CFSocketNativeHandle)sock andServer:(MWebHTTPServer*)srv
{
  self = [super init];
  if (self==nil) { return nil;}
  _recData=[NSMutableData data];
  _iStream=nsin;
  streamOpen(_iStream,self);
  _oStream=nsout;
  streamOpen(_oStream,self);
  _sock=sock;
  _httpServ=srv;
  _cfhttp=[[MWebCFHTTP alloc] initWithConnection:self];
  return self;
}

-(void) dealloc
{
  streamClose(_oStream);
  streamClose(_iStream);
  close(_sock);
  debugDealloc(self);
}

-(void) mydealloc
{
  _cfhttp=nil; /* breaks the retain loop */
}

-(void)sendData:(NSData *)data
{
  if(_writeData==nil) {
    _writeData=[NSMutableData data];
  }
  [_writeData appendData : data];
  if(_hasSpaceAvail ) {
    [self writeOutput];
  }
}

-(bool) canSend
{
  return _writeIndex==0;
}

- (void)writeOutput
{
  if( _writeData == nil ) {
    return;
  }
  uint8_t* writeBytes = (uint8_t*)[_writeData bytes];
  writeBytes += _writeIndex;
  int data_len = (int)[_writeData length];
  int remaining = data_len - _writeIndex;
  if( remaining == 0  ) {
    return;
  }
  int  len = ( remaining >= 4096 ) ? 4096 : remaining;
  uint8_t buf[len];
  (void) memcpy( buf, writeBytes, len );
  len = (int)[_oStream write : (const uint8_t*) buf maxLength : len];
  _hasSpaceAvail=false;
  if( len > 0 ) {
    _writeIndex += len;
    if(_writeIndex==data_len) {
      _writeData=[NSMutableData data];
      _writeIndex=0;
      [self delegateWriteCallback];
    }
  } else {
    NSLog( @"!!!! writeOutput write errror, len:%d!!!!", len );
  }
}

-(void)delegateWriteCallback
{
  if ([_cfhttp didProvideAllData]) {
    MYASSERT(_cfhttp.requestComplete);
    //we *must* use an intermediate variable here to increase the retain count!
    MWebCFHTTP* cfhttp=[[MWebCFHTTP alloc] initWithConnection:self];
    _cfhttp=cfhttp;
  }
}

- (void)handleData
{
  NSData* data=_recData;
  _recData=[NSMutableData data];
  if (![_cfhttp appendDataUntilComplete:data]) {
    return;
  }
  if (_httpServ!=nil && ![_httpServ.delegate handleMWebCFHTTPRequest:_cfhttp]) {
    NSLog(@"not handled:%@",_cfhttp.URL);
  }
}

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
  switch( eventCode )
  {
    case NSStreamEventOpenCompleted: {
      break;
    }
    case NSStreamEventHasSpaceAvailable: {
      MYASSERT( stream == _oStream );
      _hasSpaceAvail = true;
      [self writeOutput];
      break;
    }
    case NSStreamEventHasBytesAvailable: {
      MYASSERT( stream == _iStream );
      uint8_t bytes[8192];
      NSInteger len = [_iStream read : bytes maxLength : 8192];
      if( len > 0 ) {
        [_recData appendBytes:bytes length:len];
        [self handleData];
      }
      break;
    }
    case NSStreamEventErrorOccurred: {
      NSError *e = [stream streamError];
      NSLog(@"%@",
            [NSString stringWithFormat:@"NSStreamEventErrorOcurred Error %d: %@",
             (int)[e code],[e localizedDescription]]);
      [self mydealloc];
      break;
    }
    case NSStreamEventEndEncountered: {
      [self mydealloc];
      break;
    }
    case NSStreamEventNone: { break;}
  }
}
@end

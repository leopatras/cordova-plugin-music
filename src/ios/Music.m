#import "Music.h"
#import "mwebserver.h"
typedef void (^mediaBlock)();
@interface Music()<MWebHTTPDelegate>
{
  MWebHTTPServer* _httpSrv;
}
@end
@implementation Music
-(void)checkHTTPSrv
{
  if (_httpSrv!=nil) {return;}
  _httpSrv=[[MWebHTTPServer alloc] init];
  _httpSrv.delegate=self;
  NSError* error=nil;
  if (![_httpSrv start:&error port:0]) {
    NSLog(@"Error:%@",error.localizedDescription);
  }
}
-(NSURL*)urlForPath:(NSString*)path
{
  [self checkHTTPSrv];
  NSString* urlStr=[NSString stringWithFormat:@"http://localhost:%d/%@",_httpSrv.port,path];
  NSURL* url=[NSURL URLWithString:urlStr];
  return url;
}
/*
static NSInteger getIndexOf(NSString* s,NSString* subString)
{
  return ([s rangeOfString:subString]).location;
}*/

static NSString* getURLQueryParameter(NSString* urlstr,NSString* param)
{
  NSURLComponents *urlC = [NSURLComponents componentsWithString:urlstr];
  NSPredicate *pred = [NSPredicate predicateWithFormat:@"name=%@", param];
  NSArray* arr=[urlC.queryItems
                filteredArrayUsingPredicate:pred];
  NSURLQueryItem *item = [arr firstObject];
  return item.value;
}

-(bool)sendHTTPError:(NSString*)error statusCode:(int)statusCode forRequest:(MWebCFHTTP*)request
{
  [request sendHTTPError:error statusCode:statusCode];
  return true;
}

- (bool)handleMWebCFHTTPRequest:(MWebCFHTTP *)request
{
  NSURL* url=request.URL;
  //NSString* addr=url.path;
  NSString* full=url.absoluteString;
  NSString* idStr=getURLQueryParameter(full,@"id");
  NSString* idProp=getURLQueryParameter(full,@"idprop");
  MPMediaItem* item=[self itemById:idStr idProperty:idProp];
  if (item==nil) {
    return [self sendHTTPError:@"Item not found" statusCode:400 forRequest:request];
  }
  NSData* data=[self artWorkDataFor:item];
  if (data==nil) {
    return [self sendHTTPError:@"Not artwork found" statusCode:400 forRequest:request];
  }
  [request sendDataResponse:data mimeType:@"image/png" headers:nil];
  NSLog(@"url:%@",url);
  return true;
}

static NSString* getDocumentDir()
{
  static NSString* docDir=nil;
  if (docDir!=nil) {
    return docDir;
  }
  NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  docDir = [path objectAtIndex:0];
  return docDir;
}
/*
static void createDir(NSString* dir)
{
  BOOL isDir;
  NSError* err=nil;
  NSFileManager *fm= [NSFileManager defaultManager];
  if(![fm fileExistsAtPath:dir isDirectory:&isDir]) {
    if(![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err] || err!=nil ) {
      NSLog(@"Error: createDir failed for:%@,err:%@", dir, err);
    }
  }
}*/

static NSString* getMyPath(NSString* prefix,NSString* strId,NSString* suffix)
{
  //NSString* tmp=NSTemporaryDirectory();
  NSString* tmp=getDocumentDir();
  NSString* fname=[tmp stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"%@%@.%@",prefix,strId,suffix]];
  return fname;
}

-(void) sendError:(NSString*)errStr callbackId:(NSString*)callbackId
{
  CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errStr];
  [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

static void musicCallback(Music* __weak m,NSString* callbackId,mediaBlock blk) {
  [MPMediaLibrary requestAuthorization:^(MPMediaLibraryAuthorizationStatus status){
    switch (status) {
      case MPMediaLibraryAuthorizationStatusNotDetermined: {
        [m sendError:@"MPMediaLibraryAuthorizationStatusNotDetermined" callbackId:callbackId];
        break;
      }
      case MPMediaLibraryAuthorizationStatusRestricted: {
        [m sendError:@"MPMediaLibraryAuthorizationStatusRestricted" callbackId:callbackId];
        break;
      }
      case MPMediaLibraryAuthorizationStatusDenied: {
        [m sendError:@"MPMediaLibraryAuthorizationStatusDenied" callbackId:callbackId];
        break;
      }
      case MPMediaLibraryAuthorizationStatusAuthorized: {
        if (![NSThread isMainThread]) {
          dispatch_async(dispatch_get_main_queue(),^{
            blk();
          });
        } else {
          blk();
        };
        break;
      }
      default: {
        [m sendError:@"MPMediaLibraryAuthorizationUnknown" callbackId:callbackId];
        break;
      }
    }
  }];
}

- (void)pickItems:(CDVInvokedUrlCommand*)command
{
    _callbackID = command.callbackId;
    NSString *msong = [command argumentAtIndex:0];
    NSString *iCloudItems = [command argumentAtIndex:1];
    NSString *pickerTitle = [command argumentAtIndex:2];

    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];

    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = [msong isEqualToString:@"true"];
    mediaPicker.showsCloudItems = [iCloudItems isEqualToString:@"true"];
    mediaPicker.prompt = NSLocalizedString (pickerTitle, "Prompt in media item picker");

    [self.viewController presentViewController:mediaPicker animated:YES completion:nil];
}
//extern void printDict(NSDictionary*);
- (void) mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{

    if (mediaItemCollection) {
        NSMutableArray* songsList = [[NSMutableArray alloc] init];

        NSArray *allSelectedSongs = [mediaItemCollection items];

        NSInteger selcount = [allSelectedSongs count];
        __block int completed = 0;

        for(MPMediaItem *song in allSelectedSongs)
        {
            BOOL artImageFound = NO;
            NSData *imgData;
            NSString *title = [song valueForProperty:MPMediaItemPropertyTitle];
            NSString *albumTitle = [song valueForProperty:MPMediaItemPropertyAlbumTitle];
            NSString *artist = [song valueForProperty:MPMediaItemPropertyArtist];
            NSURL *songurl = [song valueForProperty:MPMediaItemPropertyAssetURL];
        NSString* songId = [song valueForProperty:MPMediaItemPropertyPersistentID];
            MPMediaItemArtwork *artImage = [song valueForProperty:MPMediaItemPropertyArtwork];
            UIImage *artworkImage = [artImage imageWithSize:CGSizeMake(artImage.bounds.size.width, artImage.bounds.size.height)];
            if(artworkImage != nil){
                imgData = UIImagePNGRepresentation(artworkImage);
                artImageFound = YES;
            }

            NSLog(@"title = %@",title);
            NSLog(@"albumTitle = %@",albumTitle);
            NSLog(@"artist = %@",artist);
            NSLog(@"songurl = %@",songurl);

            // some songs are protected by DRM
            if(!songurl){
                NSString* err=@"This song is protected by Digital Rights Management (DRM) and cannot be accessed.";
                [self sendError:err callbackId:_callbackID];
                break;
            }

            NSNumber *duration = [song valueForProperty:MPMediaItemPropertyPlaybackDuration];
            NSString *genre = [song valueForProperty:MPMediaItemPropertyGenre];

            AVURLAsset *songURL = [AVURLAsset URLAssetWithURL:songurl options:nil];


            //NSLog(@"Compatible Preset for selected Song = %@", [AVAssetExportSession exportPresetsCompatibleWithAsset:songURL]);

            AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songURL presetName:AVAssetExportPresetAppleM4A];

            exporter.outputFileType = @"com.apple.m4a-audio";

            NSString *outputfile = getMyPath(@"song",songId,@"m4a");
            NSString *filename =[NSString stringWithFormat:@"file://%@",outputfile];
            //[self delSingleSong:outputfile];
            [[NSFileManager defaultManager] removeItemAtPath:outputfile error:nil];

            NSURL *exportURL = [NSURL fileURLWithPath:outputfile];

            exporter.outputURL  = exportURL;

            [exporter exportAsynchronouslyWithCompletionHandler:^{
                NSInteger exportStatus = exporter.status;
                completed++;
                CDVPluginResult* plresult=nil;
                switch (exportStatus) {
                    case AVAssetExportSessionStatusFailed:{
                        NSError *exportError = exporter.error;
                        NSLog(@"AVAssetExportSessionStatusFailed = %@",exportError);
                        NSString *errmsg = [exportError description];
                        plresult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errmsg];
                        break;
                    }
                    case AVAssetExportSessionStatusCompleted:{

                        NSURL *audioURL = exportURL;
                        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];

                        NSLog(@"AVAssetExportSessionStatusCompleted %@",audioURL);
                        if(title != nil) {
                            [songInfo setObject:title forKey:@"title"];
                        } else {
                            [songInfo setObject:@"No Title" forKey:@"title"];
                        }
                        if(albumTitle != nil) {
                            [songInfo setObject:albumTitle forKey:@"albumTitle"];
                        } else {
                            [songInfo setObject:@"No Album" forKey:@"albumTitle"];
                        }
                        if(artist !=nil) {
                            [songInfo setObject:artist forKey:@"artist"];
                        } else {
                            [songInfo setObject:@"No Artist" forKey:@"artist"];
                        }

                        [songInfo setObject:[songurl absoluteString] forKey:@"ipodurl"];
                        if (artImageFound) {
                          NSString* b64=[imgData base64EncodedStringWithOptions:
                                         NSDataBase64Encoding76CharacterLineLength];
                          NSUInteger paddedLen = b64.length + (4 - (b64.length % 4));
                          NSString* correct = [b64 stringByPaddingToLength:paddedLen withString:@"=" startingAtIndex:0];
                            [songInfo setObject:correct forKey:@"image"];
                        } else {
                            [songInfo setObject:@"No Image" forKey:@"image"];
                        }

                        [songInfo setObject:duration forKey:@"duration"];
                        if (genre != nil){
                          [songInfo setObject:genre forKey:@"genre"];
                        } else {
                          [songInfo setObject:@"No Genre" forKey:@"genre"];
                        }

                        [songInfo setObject:[audioURL absoluteString] forKey:@"exportedurl"];
                        [songInfo setObject:filename forKey:@"filename"];

                        [songsList addObject:songInfo];

                        //NSLog(@"Audio Data = %@",songsList);
                        NSLog(@"Export Completed = %d out of Total Selected = %ld",completed,(long)selcount);
                      //printDict(songInfo);
                        if (completed == selcount) {
                            CDVPluginResult* r = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:songsList];
                            [self.commandDelegate sendPluginResult:r callbackId:_callbackID];
                        }
                        break;
                    }
                    case AVAssetExportSessionStatusCancelled:{
                        NSLog(@"AVAssetExportSessionStatusCancelled");
                        plresult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Cancelled"];
                        break;
                    }
                    case AVAssetExportSessionStatusUnknown:{
                        NSLog(@"AVAssetExportSessionStatusCancelled");
                        plresult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unknown"];
                        break;
                    }
                    case AVAssetExportSessionStatusWaiting:{
                        NSLog(@"AVAssetExportSessionStatusWaiting");
                        plresult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Waiting"];
                        break;
                    }
                    case AVAssetExportSessionStatusExporting:{
                        NSLog(@"AVAssetExportSessionStatusExporting");
                        plresult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Exporting"];
                        break;
                    }

                    default:{
                        NSLog(@"Didnt get any status");
                        break;
                    }
                }
                if (plresult!=nil) {
                    [self.commandDelegate sendPluginResult:plresult callbackId:_callbackID];
                    plresult=nil;
                }
            }];
        }

    }

    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Selection cancelled"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackID];
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}


- (void)getPlaylists:(CDVInvokedUrlCommand*)command
{
  Music* __weak weakSelf=self;
  musicCallback(weakSelf,command.callbackId,^{
    //getAllPlaylists
    MPMediaQuery *myPlaylistsQuery = [MPMediaQuery playlistsQuery];
    NSArray *playlists = [myPlaylistsQuery collections];
    NSMutableArray* returnPlaylits = [NSMutableArray arrayWithCapacity:1];
    
    for (MPMediaPlaylist *playlist in playlists) {
        NSString *playListId = [NSString stringWithFormat:@"%@", [playlist valueForProperty: MPMediaPlaylistPropertyPersistentID]];
        NSString *playListName = [NSString stringWithFormat:@"%@", [playlist valueForProperty: MPMediaPlaylistPropertyName]];
        NSMutableDictionary* po = [NSMutableDictionary dictionaryWithCapacity:1];
        [po setObject: playListName forKey:@"name"];
        [po setObject: playListId forKey:@"id"];
        [returnPlaylits addObject:po];
    }
    NSLog(@"%@", returnPlaylits);
    
    CDVPluginResult* pluginResult = [CDVPluginResult
                                     resultWithStatus:CDVCommandStatus_OK
                                     messageAsArray:returnPlaylits];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  });
}

- (void)getSongs:(CDVInvokedUrlCommand*)command
{
  Music* __weak weakSelf=self;
  musicCallback(weakSelf,command.callbackId,^{
    //getAllSongs
    MPMediaQuery *mySongsQuery = [MPMediaQuery songsQuery];
    NSArray *songs = [mySongsQuery items];
    NSMutableArray* songsArray = [NSMutableArray array];
    for (MPMediaItem *song in songs) {
        NSString *songtId = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyPersistentID]];
        NSString *songName = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyTitle]];
        NSString *songArtist = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyArtist]];
        NSString *url = [NSString stringWithFormat:@"%@",[song valueForProperty:MPMediaItemPropertyAssetURL]];
        NSString *album = [NSString stringWithFormat:@"%@",[song valueForProperty:MPMediaItemPropertyAlbumTitle]];
        NSMutableDictionary* so = [NSMutableDictionary dictionaryWithCapacity:1];
        [so setObject: songName forKey:@"name"];
        [so setObject: songtId forKey:@"id"];
        [so setObject: songArtist forKey:@"artist"];
        [so setObject: url forKey:@"path"];
        [so setObject: album forKey:@"album"];
        [songsArray addObject:so];
    }
    NSLog(@"%@", songsArray);
    CDVPluginResult* pluginResult = [CDVPluginResult
                                     resultWithStatus:CDVCommandStatus_OK
                                     messageAsArray:songsArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  });
}

-(MPMediaItem*)itemById:(NSString*)idStr idProperty:(NSString*)idProperty
{
  MPMediaPropertyPredicate* predicate = [MPMediaPropertyPredicate predicateWithValue: idStr forProperty:idProperty];
  MPMediaQuery* q = [[MPMediaQuery alloc] init];
  [q addFilterPredicate: predicate];
  MPMediaItem* item=nil;
  if (q.items.count > 0) {
    item = [q.items objectAtIndex:0];
  }
  return item;
}

-(NSData*)artWorkDataFor:(MPMediaItem*)item
{
  UIImage *image = [[item valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(100, 100)];
  NSData *data = UIImagePNGRepresentation(image);
  return data;
}

-(NSString*)storeArtWork:(MPMediaItem*)item idProperty:(NSString*)idProperty
{
  NSString *strId = [NSString stringWithFormat:@"%@",[item valueForProperty:idProperty]];
  /*
   NSData *data =[self artWorkDataFor:item];
  //NSString *encodedString = [NSString stringWithFormat:@"data:image/png;base64,%@",[data base64Encoding]];
  NSString *artfile = getMyPath(@"art",strId,@"png");
  [data writeToFile:artfile atomically:TRUE];
   return artfile;
  */
  NSURL* url=[self urlForPath:[NSString stringWithFormat:@"artwork?id=%@&idprop=%@",strId,idProperty]];
  [self checkHTTPSrv];
  return url.absoluteString;
}

-(void)getAlbums:(CDVInvokedUrlCommand *)command{
  Music* __weak weakSelf=self;
  musicCallback(weakSelf,command.callbackId,^{
    NSMutableArray *allAlbums = [[NSMutableArray alloc] init];
    for (MPMediaItemCollection *collection in [[MPMediaQuery albumsQuery] collections]) {

        NSMutableDictionary *albumDictionary = [[NSMutableDictionary alloc] init];
        MPMediaItem *album = [collection representativeItem];
        NSString* artfile=[self storeArtWork:album idProperty:MPMediaItemPropertyAlbumPersistentID];
        NSString *albumId = [NSString stringWithFormat:@"%@",[album valueForProperty:MPMediaItemPropertyAlbumPersistentID]];
        /*UIImage *image = [[album valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(100, 100)];
        NSData *data = UIImagePNGRepresentation(image);
        
        NSString *artfile = getMyPath(@"art",albumId,@"png");
        [data writeToFile:artfile atomically:TRUE];
         */
        //NSString* artUrl=[NSString stringWithFormat:@"file://%@",artfile];
        NSString* artUrl=[NSString stringWithFormat:@"%@",artfile];
        NSString *albumTitle = [album valueForKey:MPMediaItemPropertyAlbumTitle];
        NSString *artistTitle = [NSString stringWithFormat:@"%@ ",[album valueForProperty: MPMediaItemPropertyArtist]];
        NSNumber *noOfSongs = [album valueForKey:MPMediaItemPropertyAlbumTrackCount];
        
        [albumDictionary setObject:albumId forKey:@"id"];
        [albumDictionary setObject:albumTitle forKey:@"displayName"];
        [albumDictionary setObject:artUrl forKey:@"image"];
        [albumDictionary setObject:artistTitle forKey:@"artist"];
        [albumDictionary setObject:noOfSongs forKey:@"noOfSongs"];
        [allAlbums addObject:albumDictionary];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[allAlbums copy]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  });
}

-(void)getArtists:(CDVInvokedUrlCommand *)command{
    NSMutableArray *allArtists = [[NSMutableArray alloc] init];
    for (MPMediaItemCollection *collection in [[MPMediaQuery artistsQuery] collections]) {
        NSMutableDictionary *artistDictionary = [[NSMutableDictionary alloc] init];
        MPMediaItem *artist = [collection representativeItem];
        NSString *artistId = [NSString stringWithFormat:@"%@",[artist valueForProperty:MPMediaItemPropertyArtistPersistentID]];
        NSString *artistTitle = [NSString stringWithFormat:@"%@ ",[artist valueForProperty: MPMediaItemPropertyArtist]];
        
        [artistDictionary setObject:artistId forKey:@"id"];
        [artistDictionary setObject:artistTitle forKey:@"artistName"];
        [allArtists addObject:artistDictionary];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[allArtists copy]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

static NSNumber* numberFromId(NSString* idStr)
{
  unsigned long long valueLongLong = strtoull([idStr UTF8String], NULL, 0);
  NSNumber *value = [NSNumber numberWithUnsignedLongLong:valueLongLong];
  return value;
}

-(void)addProperty:(NSString*)property key:(NSString*)key item:(MPMediaItem*)item dict:(NSMutableDictionary*)dict
{
  NSString *value = [NSString stringWithFormat:@"%@",[item valueForProperty:property]];
  [dict setObject:value forKey:key];
}

- (void)songsResultFromQuery:(MPMediaQuery*)query command:(CDVInvokedUrlCommand*)command
{
  NSArray *collectionList = [query collections];
  NSMutableArray* songsArray = [NSMutableArray array];
    
  if (collectionList.count > 0) {
    //song exists
    MPMediaItemCollection *collection = [collectionList objectAtIndex:0];
    NSArray *songs = [collection items];
    if (songs.count > 0) {
      NSLog(@"Songs Available:%ld",(long)songs.count);
      for (MPMediaItem *song in songs) {
        NSMutableDictionary* so = [NSMutableDictionary dictionary];
        [self addProperty:MPMediaItemPropertyPersistentID key:@"id" item:song dict:so];
        [self addProperty:MPMediaItemPropertyTitle key:@"title" item:song dict:so];
        [self addProperty:MPMediaItemPropertyArtist key:@"artist" item:song dict:so];
        [self addProperty:MPMediaItemPropertyAlbumPersistentID key:@"albumId" item:song dict:so];
        NSString* artfile=[self storeArtWork:song idProperty:MPMediaItemPropertyPersistentID];
        so[@"image"]=artfile;
        [songsArray addObject:so];
      }
    }
  }
  CDVPluginResult* pluginResult = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsArray:songsArray];
    
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)getSongsFromPlaylist:(CDVInvokedUrlCommand*)command
{
  Music* __weak weakSelf=self;
  musicCallback(weakSelf,command.callbackId,^{
    //getPlaylistById
    NSString *playlistId = [command.arguments objectAtIndex:0];
    NSNumber *value = numberFromId(playlistId);
    MPMediaPropertyPredicate *playlistIdPredicate =
    [MPMediaPropertyPredicate predicateWithValue:value
                                     forProperty:MPMediaItemPropertyPersistentID];
    MPMediaQuery *myPlaylistsQuery = [MPMediaQuery playlistsQuery];
    [myPlaylistsQuery addFilterPredicate:playlistIdPredicate];
    [self songsResultFromQuery:myPlaylistsQuery command:command];
  });
}

- (void)getSongsFromAlbum:(CDVInvokedUrlCommand*)command
{
  Music* __weak weakSelf=self;
  musicCallback(weakSelf,command.callbackId,^{
    NSString *albumId = [command.arguments objectAtIndex:0];
    NSNumber *value = numberFromId(albumId);
    MPMediaPropertyPredicate *predicate =
    [MPMediaPropertyPredicate predicateWithValue:value
                                     forProperty:MPMediaItemPropertyAlbumPersistentID];
    MPMediaQuery *albumsQuery = [MPMediaQuery albumsQuery];
    [albumsQuery addFilterPredicate:predicate];
    [self songsResultFromQuery:albumsQuery command:command];
  });
}


- (void)playSong:(CDVInvokedUrlCommand*)command
{
     [self.commandDelegate runInBackground:^{
    
    //getPlaylistById
    NSString *songId = [command.arguments objectAtIndex:0];
    NSLog(@"songId: %@", songId);
    
    MPMediaPropertyPredicate *songIdPredicate =
    [MPMediaPropertyPredicate predicateWithValue:songId
                                     forProperty:MPMediaItemPropertyPersistentID];
    
    MPMediaQuery *mySongQuery = [MPMediaQuery songsQuery];
    [mySongQuery addFilterPredicate:songIdPredicate];
    
    NSArray *songs = [mySongQuery items];
    
    NSString *songName;
    NSString *songid;
    if (songs.count > 0)
    {
        //song exists
        MPMediaItem *song = [songs objectAtIndex:0];
        songName= [song valueForProperty: MPMediaItemPropertyTitle];
        songid= [song valueForProperty: MPMediaItemPropertyPersistentID];
        NSURL *url = [song valueForProperty:MPMediaItemPropertyAssetURL];
        NSLog(@"songName: %@", songName);
        
        // Play the item using AVPlayer
        //AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:url];
        
        if (player != nil) {
            [player stop];
            player.currentTime=0.0f;
            player = nil;
            [NSThread sleepForTimeInterval:.5];

        }
        
        
        player = [[AVAudioPlayer alloc] initWithContentsOfURL: url
                                                                        error: nil];
        
            
        player.delegate = self;
        [player prepareToPlay];
        [player play];
    }
     }];
}

- (void)stopSong:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{

    if (player.playing) {
        NSLog(@"Stopping song");

        [player stop];
     }
        CDVPluginResult* pluginResult = [CDVPluginResult
                                         resultWithStatus:CDVCommandStatus_OK
                                         messageAsString: @"Audio Stopped"];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    
    }];

}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"audioPlayerDidFinishPlaying");

    NSString* jsString = nil;
    if (flag) {
        jsString = [NSString stringWithFormat:@"%@(\"%s\");", @"window.cordova.plugins.Music.onMessageFromNative", "Audio Completed"];
    } else {
        jsString = [NSString stringWithFormat:@"%@(\"%s\");", @"window.cordova.plugins.Music.onMessageFromNative", "Error"];
    }
    [self.commandDelegate evalJs:jsString];
}



@end

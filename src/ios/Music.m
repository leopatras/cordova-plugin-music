#import "Music.h"

@implementation Music

- (void)getPlaylists:(CDVInvokedUrlCommand*)command
{
     [self.commandDelegate runInBackground:^{
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
         }];
}

- (void)getSongs:(CDVInvokedUrlCommand*)command
{
  [self.commandDelegate runInBackground:^{
    //getAllSongs
    MPMediaQuery *mySongsQuery = [MPMediaQuery songsQuery];
    NSArray *songs = [mySongsQuery items];
    NSMutableArray* songsArray = [NSMutableArray arrayWithCapacity:1];
    
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
      }];
}

-(void)getAlbums:(CDVInvokedUrlCommand *)command{
    NSMutableArray *allAlbums = [[NSMutableArray alloc] init];
    for (MPMediaItemCollection *collection in [[MPMediaQuery albumsQuery] collections]) {

        NSMutableDictionary *albumDictionary = [[NSMutableDictionary alloc] init];
        MPMediaItem *album = [collection representativeItem];
        UIImage *image = [[album valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(100, 100)];
        NSData *data = UIImagePNGRepresentation(image);
        NSString *encodedString = [NSString stringWithFormat:@"data:image/png;base64,%@",[data base64Encoding]];
        NSString *albumId = [NSString stringWithFormat:@"%@",[album valueForProperty:MPMediaItemPropertyAlbumPersistentID]];
        NSString *albumTitle = [album valueForKey:MPMediaItemPropertyAlbumTitle];
        NSString *artistTitle = [NSString stringWithFormat:@"%@ ",[album valueForProperty: MPMediaItemPropertyArtist]];
        NSNumber *noOfSongs = [album valueForKey:MPMediaItemPropertyAlbumTrackCount];
        
        [albumDictionary setObject:albumId forKey:@"id"];
        [albumDictionary setObject:albumTitle forKey:@"displayName"];
        [albumDictionary setObject:encodedString forKey:@"image"];
        [albumDictionary setObject:artistTitle forKey:@"artist"];
        [albumDictionary setObject:noOfSongs forKey:@"noOfSongs"];
        [allAlbums addObject:albumDictionary];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[allAlbums copy]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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


- (void)getSongsFromPlaylist:(CDVInvokedUrlCommand*)command
{
     [self.commandDelegate runInBackground:^{
    //getPlaylistById
    NSString *playlistId = [command.arguments objectAtIndex:0];
    NSLog(@"PlaylistId: %@", playlistId);
    
    MPMediaPropertyPredicate *playlistIdPredicate =
    [MPMediaPropertyPredicate predicateWithValue:playlistId
                                     forProperty:MPMediaItemPropertyPersistentID];
    
    MPMediaQuery *myPlaylistsQuery = [MPMediaQuery playlistsQuery];
    [myPlaylistsQuery addFilterPredicate:playlistIdPredicate];
    
    NSArray *playlists = [myPlaylistsQuery collections];
    NSMutableArray* songsArray = [NSMutableArray arrayWithCapacity:1];
    
    NSString *playlistName;
    if (playlists.count > 0)
    {
        //song exists
        MPMediaPlaylist *playlist = [playlists objectAtIndex:0];
        NSArray *songs = [playlist items];
        
        if (songs.count > 0) {
            
            NSLog(@"Songs Availabe");
            
            for (MPMediaItem *song in songs) {
                NSString *songtId = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyPersistentID]];
                NSString *songName = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyTitle]];
                NSString *songArtist = [NSString stringWithFormat:@"%@", [song valueForProperty: MPMediaItemPropertyArtist]];
                
                NSMutableDictionary* so = [NSMutableDictionary dictionaryWithCapacity:1];
                
                [so setObject: songName forKey:@"name"];
                [so setObject: songtId forKey:@"id"];
                [so setObject: songArtist forKey:@"artist"];
                
                [songsArray addObject:so];
            }
        }
        playlistName= [playlist valueForProperty: MPMediaPlaylistPropertyName];
        NSLog(@"%@", playlistName);
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult
                                     resultWithStatus:CDVCommandStatus_OK
                                     messageAsArray:songsArray];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
          }];
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
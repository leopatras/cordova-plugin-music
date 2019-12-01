#import <Cordova/CDVPlugin.h>
#import <Cordova/CDV.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MPMediaPlaylist.h>

#import <AVFoundation/AVFoundation.h>

@interface Music : CDVPlugin <AVAudioPlayerDelegate,MPMediaPickerControllerDelegate>
{
    AVAudioPlayer  *player;
    NSString* _callbackID;
}

- (void) getPlaylists:(CDVInvokedUrlCommand*)command;

- (void) getSongs:(CDVInvokedUrlCommand*)command;

- (void) getSongsFromPlaylist:(CDVInvokedUrlCommand*)command;

- (void)stopSong:(CDVInvokedUrlCommand*)command;

- (void)playSong:(CDVInvokedUrlCommand*)command;

- (void)getAlbums:(CDVInvokedUrlCommand*)command;

- (void)getArtists:(CDVInvokedUrlCommand*)command;




@end

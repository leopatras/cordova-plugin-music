IMPORT FGL fgldialog
PUBLIC TYPE SongInfo RECORD
  id STRING,
  artist STRING,
  title STRING,
  albumTitle STRING,
  albumId STRING,
  ipodurl STRING,
  image STRING,
  duration FLOAT,
  genre STRING,
  exportedurl STRING,
  filename STRING
END RECORD

PUBLIC TYPE AlbumInfo RECORD
  id STRING,
  artist STRING,
  displayName STRING,
  image STRING,
  noOfSongs INT
END RECORD

PUBLIC TYPE PlaylistInfo RECORD
  name STRING,
  id STRING
END RECORD


FUNCTION pickItems() RETURNS (DYNAMIC ARRAY OF SongInfo,STRING)
  DEFINE result DYNAMIC ARRAY OF SongInfo
  DEFINE err STRING
  TRY
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","pickItems"],[result])
  CATCH
    LET err=err_get(status)
    CALL fgldialog.fgl_winMessage("Error",err,"error")
  END TRY
  RETURN result,err
END FUNCTION

FUNCTION getPlaylists() RETURNS (DYNAMIC ARRAY OF PlaylistInfo,STRING)
  DEFINE result DYNAMIC ARRAY OF PlaylistInfo
  DEFINE err STRING
  TRY
    CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getPlaylists"],[result])
  CATCH
    LET err=err_get(status)
    CALL fgldialog.fgl_winMessage("Error",err,"error")
  END TRY
  RETURN result,err
END FUNCTION

FUNCTION getSongs() RETURNS STRING
  DEFINE result STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getSongs"],[result])
  RETURN result
END FUNCTION

FUNCTION getAlbums() RETURNS (DYNAMIC ARRAY OF AlbumInfo,STRING)
  DEFINE result DYNAMIC ARRAY OF AlbumInfo
  DEFINE err STRING
  TRY
    CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getAlbums"],[result])
  CATCH
    LET err=err_get(status)
    CALL fgldialog.fgl_winMessage("Error",err,"error")
  END TRY
  RETURN result,err
END FUNCTION

FUNCTION getArtists() RETURNS STRING
  DEFINE result STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getArtists"],[result])
  RETURN result
END FUNCTION

FUNCTION getSongsFromPlaylist(id STRING) RETURNS DYNAMIC ARRAY OF SongInfo
  DEFINE result DYNAMIC ARRAY OF SongInfo
  DEFINE sresult STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getSongsFromPlaylist",id],[result])
  IF result.getLength()==0 THEN
    CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getSongsFromPlaylist",id],[sresult])
    CALL fgldialog.fgl_winMessage("getSongsFromPlaylist",sfmt("sresult:%1",sresult),"info")
  END IF
  RETURN result
END FUNCTION

FUNCTION getSongsFromAlbum(id STRING) RETURNS DYNAMIC ARRAY OF SongInfo
  DEFINE result DYNAMIC ARRAY OF SongInfo
  DEFINE sresult STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getSongsFromAlbum",id],[result])
  IF result.getLength()==0 THEN
    CALL ui.Interface.frontCall("cordova","call",
                             ["Music","getSongsFromAlbum",id],[sresult])
    CALL fgldialog.fgl_winMessage("getSongsFromAlbum",sfmt("sresult:%1",sresult),"info")
  END IF
  RETURN result
END FUNCTION

FUNCTION playSong() RETURNS STRING
  DEFINE result STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","playSong"],[result])
  RETURN result
END FUNCTION

FUNCTION stopSong() RETURNS STRING
  DEFINE result STRING
  CALL ui.Interface.frontCall("cordova","call",
                             ["Music","stopSong"],[result])
  RETURN result
END FUNCTION

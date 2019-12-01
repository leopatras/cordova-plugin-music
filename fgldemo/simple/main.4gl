IMPORT util
IMPORT os
IMPORT FGL fgldialog
IMPORT FGL fglcdvMusic

DEFINE m_duration FLOAT
DEFINE m_position FLOAT
DEFINE m_state INT
DEFINE m_FastTimer STRING
DEFINE m_IsRecording BOOLEAN
DEFINE m_ch base.Channel
DEFINE t2 DYNAMIC ARRAY OF RECORD
  text STRING,
  detailText STRING
END RECORD

DEFINE t3 DYNAMIC ARRAY OF RECORD
  image STRING,
  text STRING,
  detailText STRING
END RECORD

CONSTANT LOGNAME = "Music.log"
MAIN
  DEFINE isPlaying, isPaused, playFromCommandLine, seekOnPlay, validRecExt
    BOOLEAN
  DEFINE recname, extension STRING
  DEFINE recduration INTERVAL MINUTE TO SECOND
  DEFINE fduration, prevpos DOUBLE PRECISION
  DEFINE starttime DATETIME HOUR TO SECOND
  DEFINE slider, prevState INT
  DEFINE err STRING
  DEFINE songs DYNAMIC ARRAY OF fglcdvMusic.SongInfo
  --OPEN FORM f FROM "main"
  --DISPLAY FORM f
  --CALL log("started log")
  MENU
    COMMAND "Pick Items"
      CALL fglcdvMusic.pickItems() RETURNING songs, err
      IF songs.getLength() > 0 THEN
        ERROR "Title:", songs[1].title, ",Url:", songs[1].exportedurl
      END IF
    COMMAND "Albums"
      CALL showAlbums()
    COMMAND "Playlists"
      CALL showPlaylists()
    COMMAND "Exit"
      EXIT MENU
  END MENU
END MAIN

FUNCTION showAlbums()
  DEFINE albums DYNAMIC ARRAY OF fglcdvMusic.AlbumInfo
  DEFINE err STRING
  DEFINE i INT
  CALL fglcdvMusic.getAlbums() RETURNING albums, err
  IF err IS NOT NULL THEN
    RETURN
  END IF
  CALL t3.clear()
  FOR i = 1 TO albums.getLength()
    CALL albumInfo2ListItem(i, albums[i].*)
  END FOR
  OPEN WINDOW albums WITH FORM "table2img"
  DISPLAY ARRAY t3
    TO t3.*
    ATTRIBUTE(ACCEPT = FALSE,
      ACCESSORYTYPE = DISCLOSUREINDICATOR,
      DOUBLECLICK = detail)
    ON ACTION detail
      DISPLAY "currAlbum:", albums[arr_curr()].id
      CALL showSongsFromAlbum(albums[arr_curr()].id)
  END DISPLAY
  CLOSE WINDOW albums
END FUNCTION

FUNCTION showPlaylists()
  DEFINE playlists DYNAMIC ARRAY OF fglcdvMusic.PlaylistInfo
  DEFINE err STRING
  CALL fglcdvMusic.getPlaylists() RETURNING playlists, err
  IF err IS NOT NULL THEN
    RETURN
  END IF
  OPEN WINDOW playlists WITH FORM "playlists"
  DISPLAY ARRAY playlists
    TO sr.*
    ATTRIBUTE(ACCEPT = FALSE,
      ACCESSORYTYPE = DISCLOSUREINDICATOR,
      DOUBLECLICK = detail)
    ON ACTION detail
      CALL showSongsFromPlaylist(playlists[arr_curr()].id)
  END DISPLAY
  CLOSE WINDOW playlists
END FUNCTION

FUNCTION showSongsFromAlbum(id STRING)
  DEFINE songlist DYNAMIC ARRAY OF fglcdvMusic.SongInfo
  CALL fglcdvMusic.getSongsFromAlbum(id) RETURNING songlist
  DISPLAY util.JSON.stringify(songlist)
  CALL showSongs(songlist, FALSE)
END FUNCTION

FUNCTION showSongsFromPlaylist(id STRING)
  DEFINE songlist DYNAMIC ARRAY OF fglcdvMusic.SongInfo
  CALL fglcdvMusic.getSongsFromPlaylist(id) RETURNING songlist
  CALL showSongs(songlist, TRUE)
END FUNCTION

FUNCTION showSongs(
  songlist DYNAMIC ARRAY OF fglcdvMusic.SongInfo, showImage BOOLEAN)
  DEFINE i INT
  DEFINE f STRING
  DISPLAY util.JSON.stringify(songlist)
  IF showImage THEN
    CALL t3.clear()
    LET f = "table2img"
  ELSE
    CALL t2.clear()
    LET f = "table2"
  END IF
  FOR i = 1 TO songlist.getLength()
    CALL songInfo2ListItem(i, showImage, songlist[i].*)
  END FOR
  OPEN WINDOW songs WITH FORM f
  IF showImage THEN
    DISPLAY ARRAY t3 TO t3.* ATTRIBUTE(ACCEPT = FALSE)
  ELSE
    DISPLAY ARRAY t2 TO t2.* ATTRIBUTE(ACCEPT = FALSE)
  END IF
  CLOSE WINDOW songs
END FUNCTION

FUNCTION log(s STRING)
  DEFINE bg INT
  CALL ui.Interface.frontCall("standard", "feinfo", ["isInBackground"], [bg])
  CALL m_ch.writeLine(SFMT("%1: %2 bg:%3", CURRENT, s, bg))
END FUNCTION

FUNCTION showlog()
  DEFINE t TEXT
  DEFINE s STRING
  CALL log("showlog")
  LOCATE t IN FILE LOGNAME
  LET s = t
  OPEN WINDOW log WITH FORM "showlog"
  DISPLAY s TO txt
  MENU
    ON ACTION cancel
      EXIT MENU
  END MENU
  CLOSE WINDOW log
END FUNCTION

FUNCTION songInfo2ListItem(
  idx INT, showImage BOOLEAN, song fglcdvMusic.SongInfo)
  IF showImage THEN
    LET t3[idx].image = song.image
    LET t3[idx].text = song.title
    LET t3[idx].detailText = song.artist
  ELSE
    LET t2[idx].text = song.title
    LET t2[idx].detailText = song.artist
  END IF
END FUNCTION

FUNCTION albumInfo2ListItem(idx INT, album fglcdvMusic.AlbumInfo)
  LET t3[idx].image = album.image
  LET t3[idx].text = album.displayName
  LET t3[idx].detailText = album.artist
END FUNCTION

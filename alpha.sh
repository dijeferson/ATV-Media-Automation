#!/bin/bash 

# ATV Automation
# By Jeferson Santos
# @dijeferson / dijeferson@gmail.com

# Inicio das variaveis
movie=$1
echo $movie
h264file=$movie".264"
dtsfile=$movie".dts"
ac3file=$movie".ac3"
aacfile=$movie".aac"
aac6file=$movie".6.aac"
moviem4v=$movie".m4v"


# Grava dados do video
/Applications/Mkvtoolnix.app/Contents/MacOS/mkvinfo $movie > .mediainfo
mediainforesult=$(tail .mediainfo)

# Extrai trilha de video
#echo 'Extracting Video...'
#/Applications/Mkvtoolnix.app/Contents/MacOS/mkvextract tracks $movie 0:$h264file
#echo 'Video Extracted [Ok]'

# Faz as conversoes 
if [ "$mediainforesult" = "(MKVInfo) No EBML head found." ]; then
    echo 'Converting to AAC Stereo HQ'
    ffmpeg -i $movie -acodec copy $aac6file
    faad -d -o $aacfile.tmp $aac6file
    ffmpeg -i $aacfile.tmp -acodec libfaac $aacfile
    echo 'Finished Converted'
else
    # Obtem trilha de DTS/AC3
    trackDTS=$(more .mediainfo 2>&1 | grep -B3 A_DTS | awk '{print substr($0,index($0,"mkvextract:")+12,1)}' | head -n 1)
    trackAC3=$(more .mediainfo 2>&1 | grep -B3 A_AC3 | awk '{print substr($0,index($0,"mkvextract:")+12,1)}' | head -n 1)

    # Se houver trilha dts entao extraia
    if [ ! -z "$trackDTS" ]; then
        echo 'Extracting DTS...'
        /Applications/Mkvtoolnix.app/Contents/MacOS/mkvextract tracks $movie $trackDTS:$dtsfile
        echo 'DTS Extracted [Ok]'
        
        echo 'Converting DTS to AC3'
        dcadec -o wavall $dtsfile | aften - $ac3file
        echo 'Convertion completed [Ok]'

    else

        # Se houver trilha ac3 entao extraia
        if [ ! -z "$trackAC3" ]; then
            echo 'Extracting AC3...'
            /Applications/Mkvtoolnix.app/Contents/MacOS/mkvextract tracks $movie $trackAC3:$ac3file
            echo 'AC3 Extracted [Ok]'
        fi
    fi
    
    # Convertendo de AC3 5.1 para AAC Stereo HQ
    echo 'Converting AC3 to AAC Stereo HQ'
    #ffmpeg -i $ac3file -acodec libfaac -ac 2 -ar 48000 -ab 192k $aacfile
    ffmpeg -i $ac3file -acodec libfaac $aacfile
    echo 'Convertion AC3 to AAC Stereo HQ [Ok]'
fi

# Obtendo legendas en-us, pt-br, es-es
echo 'Getting Subtitles in English, Portugues, and Spanish'
/Applications/FileBot.app/Contents/MacOS/filebot -get-subtitles $movie --lang pb --output srt --encoding utf8 -non-strict
/Applications/FileBot.app/Contents/MacOS/filebot -get-subtitles $movie --lang en --output srt --encoding utf8 -non-strict
/Applications/FileBot.app/Contents/MacOS/filebot -get-subtitles $movie --lang es --output srt --encoding utf8 -non-strict
echo 'Subtitltes [Ok]'

#Remuxando MKV->MP4
#ffmpeg -i $movie -vcodec copy $moviem4v

echo 'Remuxing...'
if [ ! -z ls $ac3file ]; then
    echo ffmpeg -i $movie -i $ac3file -i $aacfile -vcodec copy -acodec copy -acodec copy $moviem4v -map 0.0 -map 1.0 -map 2.0 -newaudio -threads 4
    ffmpeg -i $movie -i $ac3file -i $aacfile -vcodec copy -acodec copy -acodec copy $moviem4v -map 0.0 -map 1.0 -map 2.0 -newaudio -threads 4
else
    echo ffmpeg -i $movie -i $aacfile -vcodec copy -acodec copy $moviem4v -map 0.0 -map 1.0 -threads 4
    ffmpeg -i $movie -i $aacfile -vcodec copy -acodec copy $moviem4v -map 0.0 -map 1.0 -threads 4
fi
echo 'Finished remuxing!'

echo 'Getting Metadata'


#python -c 'import json,sys;obj=sys.stdin;print obj[0:obj.index("720")].replace("."," ")'

#curl http://www.imdbapi.com/?t="$movie" > .imdbinfo

#title=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Title"]')
#year=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Year"]')
#rated=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Rated"]')
#released=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Released"]')
#genre=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Genre"]')
#director=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Director"]')
#writer=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Writer"]')
#actors=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Actors"]')
#plot=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Plot"]')
#poster=$(more .imdbinfo | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["Poster"]')

#curl $poster > .poster.jpg

SublerCLI -source $movie.pb.srt -language "Portuguese" -remove -dest $moviem4v
SublerCLI -source $movie.en.srt -language "English"  -dest $moviem4v.m4v 
SublerCLI -source $movie.spa.srt -language "Spanish" -dest $moviem4v.m4v -optimize

echo 'Metadata gathered'

echo 'Adding movie to your iTunes Library'
echo osascript -e 'tell application "iTunes" to add file "' $moviem4v '" to playlist "Library" of source "Library"'
echo 'Movie added to iTunes Library [Ok]'

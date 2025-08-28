function ytm
    set url $argv[1]
    if test -z "$url"
        echo "Usage: ytm <youtube-music-url>"
        return 1
    end

    yt-dlp \
        -f "bestaudio[acodec^=mp4a]/bestaudio" \
        -o "~/Music/%(title)s.%(ext)s" \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 320K \
        --embed-thumbnail \
        --add-metadata \
        --embed-metadata \
        --progress \
        --cookies-from-browser chrome \
        "$url"
end

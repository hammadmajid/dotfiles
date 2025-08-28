function yt
    set url $argv[1]
    if test -z "$url"
        echo "Usage: yt <youtube-url>"
        return 1
    end

    mkdir -p ~/Videos/YouTube

    yt-dlp \
        -f "bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/best[height<=720][vcodec^=avc1]" \
        -o "~/Videos/YouTube/%(title)s - %(channel)s.%(ext)s" \
        --merge-output-format mp4 \
        --progress \
        --embed-thumbnail \
        --sub-lang en \
        --write-auto-subs \
        --embed-subs \
        --embed-metadata \
        --concurrent-fragments 8 \
        --cookies-from-browser chrome \
        "$url"
end

#! /usr/bin/env nix-shell
#! nix-shell -i zsh -p jq curl imagemagick ghostscript file zsh

OUTDIR="${0:a:h}"

while getopts f o
do	case "$o" in
	f)	FORCE="yes";
	esac
done

EPISODES=("${(@f)$(jq -r '.[]' episodes.json)}")
LANGUAGES=("${(@f)$(jq -r '.[]' languages.json)}")

function download() {
    EPISODE=$1
    NUMBER="${(l:2::0:)2}"
    LANGUAGE=$3
    i=0
    while
        FILE="${LANGUAGE}_Pepper-and-Carrot_by-David-Revoy_E${NUMBER}P${(l:2::0:)i}.jpg"
        
        URL="https://www.peppercarrot.com/0_sources/ep${NUMBER}_${EPISODE}/hi-res/${FILE}"
        STATUSCODE=$(curl --silent --remote-name --write-out "%{http_code}" $URL)

        if [ $STATUSCODE -ne 200 ] || ! [[ $(file -b $FILE) =~ JPEG ]]; then
            URL="https://www.peppercarrot.com/0_sources/ep${NUMBER}_${EPISODE}/low-res/${FILE}"
            STATUSCODE=$(curl --silent --remote-name --write-out "%{http_code}" $URL)
        fi
    
        if ! [[ $(file -b $FILE) =~ JPEG ]]; then
            rm $FILE
        fi

        (( i = i + 1 ))
        
        [ $STATUSCODE -eq 200 ]
    do :; done
}

function build() {
    NUMBER="${(l:2::0:)1}"
    LANGUAGE=$2

    convert -rotate 270 -extent 1240x1753 -units PixelsPerInch  \
        -density 150x150 -gravity center *P00.jpg title-page.pdf

    convert *P<1-99>.jpg -compress jpeg -resize 1240x1753 \
              -extent 1240x1753 -gravity center \
              -units PixelsPerInch -density 150x150 story.pdf

    mkdir -p "${OUTDIR}/$LANGUAGE"

    gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite \
       -sOutputFile="${OUTDIR}/$LANGUAGE/episode-${NUMBER}.pdf" \
       title-page.pdf story.pdf
}


for ((lang = 1; lang <= $#LANGUAGES; lang++)); do
    echo "Language: ${LANGUAGES[lang]}"
    for ((ep = 1; ep <= $#EPISODES; ep++)); do
        echo -n "Episode: ${EPISODES[ep]}"

        if [ -z $FORCE ] && [ -f "${LANGUAGES[lang]}/episode-${(l:2::0:)ep}.pdf" ]; then
           echo -n " exists, skipping ..."
        else
            tempDir=$(mktemp -d)
            cd $tempDir
        
            download "${EPISODES[ep]}" $ep "${LANGUAGES[lang]}"
            build $ep "${LANGUAGES[lang]}"

            cd -
            rm -rf $tempDir
        fi
        echo
    done
done

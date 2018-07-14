#! /bin/bash

### Console Google Translate 
### Example usage:
### gttranslate <source_lng> <new_lng> <your text>
### This bash script is combine of this scripts https://gist.github.com/elFua/3342075 and https://gist.github.com/ayubmalik/149e2c7f28104f61cc1c862fe9834793
### Updated by Anodev https://github.com/OPHoperHPO/
USAGE="
Example usage: '$0 <source_lng> <new_lng> <your text>'
Usage: '$0 en ru text'
Some language codes: en|fr|de|ru|nl|it|es|ja|la|pl|bo|ru
All language codes:
https://cloud.google.com/translate/docs/languages"

# Check curl installation
if [[ ! $(curl -V) ]]
then
        echo -e "ERROR!"
        echo -e "To run this script, you need install 'curl'"
        echo -e "To install curl run this command: 
        'sudo pacman -S curl' # For Arch Linux based distro
        'sudo yum install curl' # For Fedora/Red Hat Enterprise Linux etc
        'sudo apt install curl' #For Debian-based distro like Ubuntu, Debian, etc "
        exit 1
fi
# Print USAGE if parse wrong arguments
if [ "$#" == "0" ]; then
    echo "$USAGE"
    exit 1
fi

FROM_LNG=$1
TO_LNG=$2

shift 2
QUERY=$*
# Send text and language to google translate api
base_url="https://translate.googleapis.com/translate_a/single?client=gtx&sl=${FROM_LNG}&tl=${TO_LNG}&dt=t&q="
ua='Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'
qry=$( echo $@ | sed -E 's/\s{1,}/\+/g' )
full_url=${base_url}${qry}
response=$(curl -sA "${ua}" "${full_url}")
# Print only first translation from JSON
translated=`echo ${response} | sed 's/","/\n/g' | sed -E 's/\[|\]|"//g' | head -1`
echo $translated

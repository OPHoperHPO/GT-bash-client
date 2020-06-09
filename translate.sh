#! /bin/bash
# Console Google Translate
# License: MIT
# Repository URL: https://github.com/OPHoperHPO/GT-bash-client
# Updated by Anodev https://github.com/OPHoperHPO/
# Example usage: translate.sh <source_lng> <new_lng> <your text>
# This bash script is combine of this scripts:
# https://gist.github.com/elFua/3342075
# https://github.com/dominictarr/JSON.sh (License MIT)
# https://gist.github.com/ayubmalik/149e2c7f28104f61cc1c862fe9834793
# The JSON.sh script has been slightly modified for tight integration with my code.


USAGE="
Console Google Translate!
License: MIT
Repository url: https://github.com/OPHoperHPO/GT-bash-client
Example usage: '$0 <source_lng> <new_lng> <your text>'
Usage: '$0 en ru text'
Some language codes: en|fr|de|ru|nl|it|es|ja|la|pl|bo|ru|auto
All language codes: https://cloud.google.com/translate/docs/languages"

# Check curl installation
if [[ ! $(curl -V) ]]
then
        echo -e "ERROR!"
        echo -e "To run this script, you need install 'curl'"
        echo -e "To install curl run this command: 
        'sudo pacman -S curl' # For Arch Linux based distro
        'sudo dnf install curl' # For Fedora/Red Hat Enterprise Linux etc
        'sudo apt install curl' #For Debian-based distro like Ubuntu, Debian, etc "
        exit 1
fi
# Print USAGE if parse wrong arguments
if [ "$#" == "0" ]; then
    echo "$USAGE"
    exit 1
fi

# Code from JSON.sh https://github.com/dominictarr/JSON.sh
throw() {
  echo "$*" >&2
  exit 1
}

BRIEF=0
LEAFONLY=0
PRUNE=0
NO_HEAD=0
NORMALIZE_SOLIDUS=0

usage() {
  echo
  echo "Usage: JSON.sh [-b] [-l] [-p] [-s] [-h]"
  echo
  echo "-p - Prune empty. Exclude fields with empty values."
  echo "-l - Leaf only. Only show leaf nodes, which stops data duplication."
  echo "-b - Brief. Combines 'Leaf only' and 'Prune empty' options."
  echo "-n - No-head. Do not show nodes that have no path (lines that start with [])."
  echo "-s - Remove escaping of the solidus symbol (straight slash)."
  echo "-h - This help text."
  echo
}

awk_egrep () {
  local pattern_string=$1

  gawk '{
    while ($0) {
      start=match($0, pattern);
      token=substr($0, start, RLENGTH);
      print token;
      $0=substr($0, start+RLENGTH);
    }
  }' pattern="$pattern_string"
}

tokenize () {
  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | egrep -ao --color=never "test" >/dev/null 2>&1
  then
    GREP='egrep -ao --color=never'
  else
    GREP='egrep -ao'
  fi

  if echo "test string" | egrep -o "test" >/dev/null 2>&1
  then
    ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=awk_egrep
    ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\\\]'
  fi

  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'

  # Force zsh to expand $A into multiple words
  local is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
  if [ $is_wordsplit_disabled != 0 ]; then setopt shwordsplit; fi
  $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | egrep -v "^$SPACE$"
  if [ $is_wordsplit_disabled != 0 ]; then unsetopt shwordsplit; fi
}

parse_array () {
  local index=0
  local ary=''
  read -r token
  case "$token" in
    ']') ;;
    *)
      while :
      do
        parse_value "$1" "$index"
        index=$((index+1))
        ary="$ary""$value"
        read -r token
        case "$token" in
          ']') break ;;
          ',') ary="$ary," ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  [ "$BRIEF" -eq 0 ] && value=$(printf '[%s]' "$ary") || value=
  :
}

parse_object () {
  local key
  local obj=''
  read -r token
  case "$token" in
    '}') ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') key=$token ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        parse_value "$1" "$key"
        obj="$obj$key:$value"
        read -r token
        case "$token" in
          '}') break ;;
          ',') obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  [ "$BRIEF" -eq 0 ] && value=$(printf '{%s}' "$obj") || value=
  :
}
function has_substring() {
   [[ "$1" != "${2/$1/}" ]]
}
parse_value () {
  local jpath="${1:+$1,}$2" isleaf=0 isempty=0 print=0
  case "$token" in
    '{') parse_object "$jpath" ;;
    '[') parse_array  "$jpath" ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *) value=$token
       # if asked, replace solidus ("\/") in json strings with normalized value: "/"
       [ "$NORMALIZE_SOLIDUS" -eq 1 ] && value=$(echo "$value" | sed 's#\\/#/#g')
       isleaf=1
       [ "$value" = '""' ] && isempty=1
       ;;
  esac
  [ "$value" = '' ] && return
  [ "$NO_HEAD" -eq 1 ] && [ -z "$jpath" ] && return

  [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && [ $PRUNE -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 1 ] && [ "$isempty" -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && \
    [ $PRUNE -eq 1 ] && [ $isempty -eq 0 ] && print=1
  :
  # Fixed issue #5 Multi-string text input https://github.com/OPHoperHPO/GT-bash-client/issues/5
  if echo "[$jpath]" | grep -q '\[0,[0-9]*,0\]'; then   # We are only looking for translated text
      value=${value:1:-1}  # Delete double quotes on each line
      value=${value//'\n'}  # Delete "\n" at the end of each line if a line with the number of lines >1 was input
      printf "%s\n" "$value"
  fi
}
parse () {
  read -r token
  parse_value
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF GOT $token" ;;
  esac
}
# The code from JSON.sh is over

# Parse arguments to vars
FROM_LNG=$1
TO_LNG=$2

# Fixed text encoding issue. Issue URL: https://github.com/OPHoperHPO/GT-bash-client/issues/1
urlencode() {
  # Code was copyied from https://gist.github.com/zhangkaiyulw/8793cd8641d270f1461a
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      *) printf "$c" | xxd -p -c1 |
               while read x;
               do printf "%%%s" "$(echo "$x" | tr "[:lower:]" "[:upper:]" )";
               done
    esac
  done
}
shift 2
# Parse arguments to vars
qry=$(  urlencode "$*" ) # Get query from arguments and encode it to URL encoding
# Define utility variables
ua='Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36' #  User Agent
url="https://translate.googleapis.com/translate_a/single?client=gtx&sl=${FROM_LNG}&tl=${TO_LNG}&dt=t&q=${qry}" # Google Translate url
# Send encoded text and language to google translate api
response=$(curl --tr-encoding  -sA "${ua}" "${url}")
# We execute the request, parse the json response, display all the translated text
translated=$(echo "${response}" | tokenize | parse )
echo "$translated"

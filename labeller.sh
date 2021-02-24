#!/opt/pkg/bin/zsh

# see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail
#set -x

SCRIPT_NAME=$(basename "$0")

#trap "do something" SIGHUP SIGINT SIGTERM
trap 'catch $? $LINENO' EXIT
catch(){
  if ! [ "$1" = 0 ]; then
    # leave stuff around if debugging
    #cleanup
  # else
    echo "${SCRIPT_NAME} error: ${1:-'Unknown Error'}" 1>&2
  fi
}

# trap cleanup 1 2 3 6
# 
# cleanup(){
#   if [ -n "${tmpdir:-}" ]; then rm -rf "$tmpdir"; fi
# }


save() {
  LC_ALL=C awk -v q=\' '
    BEGIN{
      for (i=1; i<ARGC; i++) {
        gsub(q, q "\\" q q, ARGV[i])
        printf "%s ", q ARGV[i] q
      }
      print ""
    }' "$@"
}

#LABEL_DATA should be a file holding an array of JSON
#even if only one item

long_help=$(cat <<'EOF'
Usage: ${SCRIPT_NAME} (options) [<LABEL_DATA>...]
Update issue labels on Github.
OPTIONS
  -h, --help            Show this help
  -o, --owner=NAME      The repo owner e.g. yb66        [required]
  -r, --repo=NAME       Name of the repo e.g. labeller  [required]
  -t, --auth-token      The API auth token              [required]

If LABEL_DATA is a single dash ('-') then standard input is read.
EOF
)

short_help=$(cat <<'EOF'
Usage: ${SCRIPT_NAME} (options) [<LABEL_DATA>...]
Update issue labels on Github.
OPTIONS
  -h        Show this help
  -o        The repo owner e.g. yb66        [required]
  -r        Name of the repo e.g. labeller  [required]
  -t        The API auth token              [required]

If LABEL_DATA is a single dash ('-') then standard input is read.
EOF
)

HAS_GNU_ENHANCED_GETOPT=
if getopt -T >/dev/null; then :
else
  if [ $? -eq 4 ]; then
    HAS_GNU_ENHANCED_GETOPT=yes
  fi
fi

SOPTS="ho:r:t:"
LOPTS="help,owner:,repo:,auth_token:"
original_at=$(save "$@")

if [ -n "$HAS_GNU_ENHANCED_GETOPT" ]; then
  # Use GNU enhanced getopt
  if ! getopt --name "$SCRIPT_NAME" --long $LOPTS --options $SOPTS -- "$@" >/dev/null; then
    echo "$SCRIPT_NAME: usage error (use -h or --help for help)" >&2
    exit 2
  fi
  our_options=$(getopt -o "$SOPTS" --long "$LOPTS" -n "$SCRIPT_NAME" -- "$@")
else
  # Use original getopt (no long option names, no whitespace, no sorting)
  if ! getopt $SOPTS "$@" >/dev/null; then
    echo "$SCRIPT_NAME: usage error (use -h for help)" >&2
    exit 2
  fi
  our_options=$(getopt $SOPTS "$@")
fi

eval set -- "$our_options"

show_help(){
  if [ -n "$HAS_GNU_ENHANCED_GETOPT" ]
    then echo "$long_help";
    else echo "$short_help";
  fi
}

if [ "$#" -eq 0 ]; then show_help; exit 0; fi

main(){
  # It's difficult to get curl to accept JSON data 
  # as an argument and it's difficult to stop the 
  # shell messing around with quotes and newlines 
  # etc, so the best thing to do is to stick the 
  # JSON in a temp file and get curl to read the 
  # file. Hence this roundabout way to call curl:
  while read -r line; do
    local jsontmp=$(mktemp)
    echo "$1" > "$jsontmp"
cat <<CMD
  curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary @$jsontmp \
    "https://api.github.com/repos/${OWNER}/${REPO}/labels"
CMD
  done < <(jq -c '.[]' "$1")
}

while true; do
  case "$1" in
    -h|--help)        show_help;      exit 0;;
    -o|--owner)       OWNER=$2;       shift;;
    -r|--repo)        REPO=$2;        shift;;
    -t|--auth-token)  AUTH_TOKEN=$2;  shift;;
    --) shift; break;;
    -*) echo "unknown option: $1" ;   exit 1 ;;
     *) break ;;
  esac
  shift
done


while [ "$#" -gt 0 ]; do
  LABEL_DATA=""
  case "$1" in
    -) shift; set -- /dev/stdin;;
    *) LABEL_DATA="$1"; shift;;
  esac
  
  if [ -n "$LABEL_DATA" ]; then
		main "$LABEL_DATA"
	fi
done


#LABEL_DATA=$4
#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# Source the config
# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

action-preprocess() {
  local dest_file
  case "$SRC_FILE" in
    *.mustache)
        dest_file="$DEST_DIR/${SRC_FILE%.*}"
        echo "In $SRC_FILE_DIR: preprocess $FILE_BN -> $dest_file"
        mo < "$SRC_FILE" > "$dest_file"
        ;;
    *)
       fatal "Unknown file extension $FILE_EXT in $SRC_FILE"
       ;;
  esac
}

action-copy-file() {
  echo "In $SRC_FILE_DIR: copy $FILE_BN -> $DEST_DIR/$SRC_FILE"
  cp -a "$SRC_FILE" "$DEST_DIR/$SRC_FILE"
}

if [[ -z "$TEMPLATE_DEST_DIR" ]]; then
  fatal "TEMPLATE_DEST_DIR variable is not set"
fi

dest_dir=$(abspath "$TEMPLATE_DEST_DIR")
echo "Create template destination directory $dest_dir"
mkdir -p "$dest_dir"

echo "Rendering templates in $TEMPLATE_SRC_DIR ..."
cd "$TEMPLATE_SRC_DIR";
while IFS= read -r -d '' file
do
  # Ignore source directory
  if [[ "$file" = "." ]]; then
    continue
  fi

  # Create directory
  if [[ -d "$file" ]]; then
    if [[ ! -d "$dest_dir/$file" ]]; then
      echo "Create directory $dest_dir/$file"
      mkdir -p "$dest_dir/$file"
    fi
    continue
  fi

  file_action=
  case "$file" in
    *.mustache) file_action="action-preprocess";;
    *) file_action="action-copy-file";;
  esac

  file_to_match=${file#"."}
  for ((i=0;i<${#TEMPLATE_FILE_ACTIONS[@]};i+=2)); do
    pat=${TEMPLATE_FILE_ACTIONS[$i]}
    action=${TEMPLATE_FILE_ACTIONS[$i+1]}
    if [[ -n "$pat" ]]; then
      # shellcheck disable=SC2053
      if [[ "$file_to_match" = $pat ]]; then
        case "$action" in
          ignore) file_action="";;
          copy) file_action="action-copy-file";;
          preprocess) file_action="action-preprocess";;
          *) fatal "Unknown file action $action in TEMPLATE_FILE_ACTIONS variable";;
        esac
        break
      fi
    fi
  done

  SRC_FILE=$file
  DEST_DIR=$dest_dir
  SRC_FILE_DIR=$( (cd "$(dirname -- "$SRC_FILE")" && pwd -P) )
  FILE_BN=$(basename -- "$SRC_FILE")
  FILE_EXT=${FILE_BN##*.}
  # shellcheck disable=SC2034
  FILE_FN="${FILE_BN%.*}"

  if [[ -n "$file_action" ]]; then
    "$file_action"
  fi

  #dir=$( (cd "$(dirname -- "$file")" && pwd -P) )
  #bn=$(basename -- "$file")
  ##ext=${bn##*.}
  #fn="${bn%.*}"
  #echo "In $dir: $bn -> $fn"
  #mo < "$file" > "$dir/$fn"
done < <(find "." -print0)

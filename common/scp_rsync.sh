#############################################
# Machine SCP/RSYNC Shortcuts
# To add a new machine transfer, do:
#
# NEW_HOST="user@new-machine"
# scp-from-new() { data_transfer "from" "${NEW_HOST}" "$@"; }
# scp-to-new()   { data_transfer "to" "${NEW_HOST}" "$@"; }
#############################################

# Helper: prepend ~/ if path is not absolute or already starts with ~
_to_home_path() {
  local path="$1"
  if [[ "$path" != /* && "$path" != ~* ]]; then
    echo "~/${path}"
  else
    echo "$path"
  fi
}

# Helper: resolve local path to absolute
_to_abs_path() {
  local path="$1"
  realpath -m "$path" 2>/dev/null || echo "$path"
}

# Helper: run rsync with progress bar and timing
_rsync_progress() {
  local src_display="$1"
  local dst_display="$2"
  shift 2
  local start=$SECONDS
  echo "${src_display} -> ${dst_display}"
  if rsync -az --info=progress2 --no-inc-recursive "$@"; then
    local elapsed=$((SECONDS - start))
    echo "✓ done (${elapsed}s)"
    echo
  else
    echo "✗ FAILED"
    return 1
  fi
}

# Core transfer function
# Usage: data_transfer <direction> <host> <paths...>
#   direction: "from" or "to"
#   host: remote host string (user@host)
#   paths: source path(s) followed by destination
data_transfer() {
  local direction="$1"
  local host="$2"
  shift 2

  if [ "$#" -lt 2 ]; then
    if [ "$direction" = "from" ]; then
      echo "Usage: scp-from-<machine> <remote_path1> [remote_path2 ...] <local_destination>"
    else
      echo "Usage: scp-to-<machine> <local_path1> [local_path2 ...] <remote_destination>"
    fi
    return 1
  fi

  local destination="${@: -1}"
  local sources=("${@:1:$#-1}")
  local conflicts=()
  local expanded_sources=()

  local local_dest_abs
  local _src _basename _target

  if [ "$direction" = "from" ]; then
    local_dest_abs=$(_to_abs_path "$destination")
    echo "rsync from ${host} -> ${local_dest_abs}"

    # Expand wildcards on remote and get actual paths
    echo "Remote paths to copy:"
    for _src in "${sources[@]}"; do
      _src=$(_to_home_path "$_src")
      # Get expanded paths from remote
      while IFS= read -r expanded_path; do
        if [ -n "$expanded_path" ]; then
          echo "  ${expanded_path}"
          expanded_sources+=("$expanded_path")
        fi
      done < <(ssh "${host}" "ls -d ${_src} 2>/dev/null")
    done

    if [ ${#expanded_sources[@]} -eq 0 ]; then
      echo "  [NO MATCHES FOUND]"
      return 1
    fi

    # Check for local conflicts using expanded paths
    for _src in "${expanded_sources[@]}"; do
      _basename=$(basename "$_src")
      _target="${local_dest_abs}/${_basename}"
      if [ -e "$_target" ]; then
        conflicts+=("$_target")
      fi
    done
  else
    destination=$(_to_home_path "$destination")
    echo "rsync to ${host}:${destination}"
    echo "Local paths to copy:"
    for _src in "${sources[@]}"; do
      # Expand local wildcards
      for expanded_path in $_src; do
        if [ -e "$expanded_path" ]; then
          local abs_path=$(_to_abs_path "$expanded_path")
          echo "  ${abs_path}"
          expanded_sources+=("$expanded_path")
        fi
      done
    done

    if [ ${#expanded_sources[@]} -eq 0 ]; then
      echo "  [NO MATCHES FOUND]"
      return 1
    fi

    # Check for remote conflicts
    for _src in "${expanded_sources[@]}"; do
      _basename=$(basename "$_src")
      _target="${destination}/${_basename}"
      if ssh "${host}" "test -e ${_target}" 2>/dev/null; then
        conflicts+=("${host}:${_target}")
      fi
    done
  fi

  # Show conflicts if any
  if [ ${#conflicts[@]} -gt 0 ]; then
    echo "Conflicts (already exist):"
    for conflict in "${conflicts[@]}"; do
      echo "  ⚠ ${conflict}"
    done
  fi

  read -p "Proceed? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    return 1
  fi

  local total_start=$SECONDS
  local src_display dst_display src_abs

  # Use expanded_sources for actual transfer
  for _src in "${expanded_sources[@]}"; do
    if [ "$direction" = "from" ]; then
      _basename=$(basename "$_src")
      _target="${local_dest_abs}/${_basename}"
      src_display="${host}:${_src}"
      dst_display="${_target}"

      if [ -e "$_target" ]; then
        read -p "'${_target}' exists. [r]eplace, [s]kip, [a]bort? " -n 1 -r
        echo
        case $REPLY in
          r|R) _rsync_progress "${src_display}" "${dst_display}" "${host}:${_src}" "${local_dest_abs}/" ;;
          s|S) echo "Skipped ${_src}"; echo ;;
          *) echo "Aborted."; return 1 ;;
        esac
      else
        _rsync_progress "${src_display}" "${dst_display}" "${host}:${_src}" "${local_dest_abs}/"
      fi
    else
      src_abs=$(_to_abs_path "$_src")
      _basename=$(basename "$_src")
      _target="${destination}/${_basename}"
      src_display="${src_abs}"
      dst_display="${host}:${_target}"

      if ssh "${host}" "test -e ${_target}" 2>/dev/null; then
        read -p "'${_target}' exists on remote. [r]eplace, [s]kip, [a]bort? " -n 1 -r
        echo
        case $REPLY in
          r|R) _rsync_progress "${src_display}" "${dst_display}" "${src_abs}" "${host}:${destination}/" ;;
          s|S) echo "Skipped ${_src}"; echo ;;
          *) echo "Aborted."; return 1 ;;
        esac
      else
        _rsync_progress "${src_display}" "${dst_display}" "${src_abs}" "${host}:${destination}/"
      fi
    fi
  done

  local total_elapsed=$((SECONDS - total_start))
  echo "Total time: ${total_elapsed}s"
}

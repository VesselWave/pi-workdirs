function __pi_display_label --argument-names dir
    set -l label (__pi_meta_value "$dir" label)

    if test -n "$label"
        printf '%s\n' "$label"
        return
    end

    set -l args_preview (__pi_meta_value "$dir" args)

    if test -n "$args_preview"
        printf '%s\n' "$args_preview"
        return
    end

    printf '%s\n' '-'
end

function __pi_display_created --argument-names dir
    set -l created (__pi_meta_value "$dir" created_at)

    if test -n "$created"
        printf '%s\n' "$created"
        return
    end

    date -r "$dir" '+%Y-%m-%d %H:%M:%S' 2>/dev/null
end

function __pi_display_label_list --argument-names dir
    set -l label (__pi_display_label "$dir")
    set -l width 21

    if test (string length -- "$label") -gt "$width"
        printf '%s…\n' (string sub -s 1 -l (math "$width - 1") -- "$label")
    else
        printf '%s\n' "$label"
    end
end

function __pi_session_state --argument-names dir
    set -l session_name (__pi_session_name "$dir")

    if tmux has-session -t "$session_name" 2>/dev/null
        printf '%s\n' live
        return
    end

    set -l content_count (__pi_content_count "$dir")

    if test "$content_count" -gt 0
        printf '%s\n' used
    else if test -f (__pi_metadata_path "$dir")
        printf '%s\n' meta
    else
        printf '%s\n' empty
    end
end

function __pi_list_sessions
    set -l dirs (__pi_session_dirs)

    if test (count $dirs) -eq 0
        echo 'No managed pi sessions.'
        return 1
    end

    printf '%-4s %-6s %-19s %-21s %s\n' ID STATE CREATED LABEL PATH

    set -l idx 1
    for dir in $dirs
        printf '%-4s %-6s %-19s %-21s %s\n' \
            "$idx" \
            (__pi_session_state "$dir") \
            (__pi_display_created "$dir") \
            (__pi_display_label_list "$dir") \
            "$dir"
        set idx (math "$idx + 1")
    end
end

function __pi_resolve_target --argument-names selector
    set -l dirs (__pi_session_dirs)

    if test (count $dirs) -eq 0
        echo 'No managed pi sessions.' >&2
        return 1
    end

    if test -z "$selector"
        set -l last_file (__pi_last_session_file)
        if test -f "$last_file"
            set -l last_dir (cat "$last_file")
            if test -d "$last_dir"
                printf '%s\n' "$last_dir"
                return
            end
        end

        printf '%s\n' "$dirs[1]"
        return
    end

    if string match -qr '^[0-9]+$' -- "$selector"
        set -l idx "$selector"
        if test "$idx" -ge 1 -a "$idx" -le (count $dirs)
            printf '%s\n' "$dirs[$idx]"
            return
        end

        echo "Bad session id: $selector" >&2
        return 1
    end

    set -l matches
    for dir in $dirs
        set -l haystack "$dir "(basename "$dir")" "(__pi_display_label "$dir")" "(__pi_meta_value "$dir" args)
        if printf '%s\n' "$haystack" | grep -F -qi -- "$selector"
            set matches $matches "$dir"
        end
    end

    if test (count $matches) -eq 1
        printf '%s\n' "$matches[1]"
        return
    end

    if test (count $matches) -gt 1
        echo "Ambiguous session selector: $selector" >&2
        for dir in $matches
            printf '  %s  %s\n' (__pi_display_created "$dir") "$dir" >&2
        end
        return 1
    end

    echo "No session match: $selector" >&2
    return 1
end

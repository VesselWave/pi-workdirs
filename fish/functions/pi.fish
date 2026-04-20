function __pi_cache_dir
    printf '%s\n' "$HOME/.cache/pi"
end

function __pi_last_session_file
    printf '%s/last_session_dir\n' (__pi_cache_dir)
end

function __pi_work_root
    printf '%s\n' "$HOME/repos/test"
end

function __pi_metadata_path --argument-names dir
    printf '%s/.pi-session\n' "$dir"
end

function __pi_card_path --argument-names dir
    printf '%s/SESSION.md\n' "$dir"
end

function __pi_now
    date '+%Y-%m-%d %H:%M:%S'
end

function __pi_join_args
    if test (count $argv) -eq 0
        return
    end

    string join ' ' -- $argv
end

function __pi_preview_text --argument-names text
    set -l clean (string replace -a \n ' ' -- "$text")
    set clean (string replace -a \t ' ' -- "$clean")
    set clean (string replace -a -r '\s+' ' ' -- "$clean")
    set clean (string trim -- "$clean")

    if test -z "$clean"
        return
    end

    if test (string length -- "$clean") -gt 80
        printf '%s…\n' (string sub -s 1 -l 79 -- "$clean")
    else
        printf '%s\n' "$clean"
    end
end

function __pi_slugify --argument-names text
    set -l clean (__pi_preview_text "$text")
    set clean (string lower -- "$clean")
    set clean (string replace -a -r '[^a-z0-9]+' '-' -- "$clean")
    set clean (string trim -c '-' -- "$clean")

    if test -z "$clean"
        return
    end

    if test (string length -- "$clean") -gt 32
        set clean (string sub -s 1 -l 32 -- "$clean")
        set clean (string trim -c '-' -- "$clean")
    end

    printf '%s\n' "$clean"
end

function __pi_session_name --argument-names cwd
    set -l session_base (basename "$cwd")
    set -l session_slug (string replace -a -r '[^A-Za-z0-9]+' '-' -- $session_base)
    set session_slug (string trim -c '-' -- $session_slug)

    if test -z "$session_slug"
        set session_slug cwd
    end

    set -l session_hash (printf '%s' "$cwd" | sha1sum | cut -c1-8)
    printf 'pi-%s-%s\n' "$session_slug" "$session_hash"
end

function __pi_meta_value --argument-names dir key
    set -l meta (__pi_metadata_path "$dir")

    if not test -f "$meta"
        return 1
    end

    set -l line (grep -m1 "^$key	" "$meta" 2>/dev/null)

    if test -z "$line"
        return 1
    end

    string replace -r '^[^\t]*\t' '' -- "$line"
end

function __pi_write_metadata --argument-names dir source_cwd label
    set -l pi_args $argv[4..-1]
    set -l meta (__pi_metadata_path "$dir")
    set -l card (__pi_card_path "$dir")
    set -l now (__pi_now)
    set -l created_at (__pi_meta_value "$dir" created_at)
    set -l saved_source (__pi_meta_value "$dir" source_cwd)
    set -l saved_label (__pi_meta_value "$dir" label)
    set -l saved_args (__pi_meta_value "$dir" args)
    set -l session_name (__pi_session_name "$dir")
    set -l args_preview (__pi_preview_text (__pi_join_args $pi_args))

    if test -z "$created_at"
        set created_at "$now"
    end

    if test -z "$source_cwd"
        set source_cwd "$saved_source"
    end

    if test -z "$source_cwd"
        set source_cwd "$dir"
    end

    if test -z "$label"
        set label "$saved_label"
    end

    if test -z "$label"
        set label "$args_preview"
    end

    if test -z "$args_preview"
        set args_preview "$saved_args"
    end

    printf 'created_at\t%s\nlast_used_at\t%s\nsource_cwd\t%s\nsession_name\t%s\nlabel\t%s\nargs\t%s\n' \
        "$created_at" \
        "$now" \
        "$source_cwd" \
        "$session_name" \
        "$label" \
        "$args_preview" > "$meta"

    printf '# Pi Session\n\n- Created: %s\n- Last used: %s\n- Source cwd: `%s`\n- Session dir: `%s`\n- Tmux session: `%s`\n- Label: %s\n- Initial prompt: %s\n' \
        "$created_at" \
        "$now" \
        "$source_cwd" \
        "$dir" \
        "$session_name" \
        (test -n "$label"; and printf '`%s`' "$label"; or printf '_none_') \
        (test -n "$args_preview"; and printf '`%s`' "$args_preview"; or printf '_none_') > "$card"
end

function __pi_content_count --argument-names dir
    find "$dir" -mindepth 1 -maxdepth 1 ! -name '.pi-session' ! -name 'SESSION.md' | wc -l | string trim
end

function __pi_session_dirs
    set -l root (__pi_work_root)

    if not test -d "$root"
        return
    end

    find "$root" -mindepth 1 -maxdepth 1 -type d -name 'work-*' | sort -r
end

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

function __pi_save_last_session --argument-names dir
    set -l cache_dir (__pi_cache_dir)
    mkdir -p "$cache_dir"
    printf '%s\n' "$dir" > (__pi_last_session_file)
end

function __pi_launch_in_tmux --argument-names cwd
    set -l pi_args $argv[2..-1]

    __pi_save_last_session "$cwd"

    if set -q TMUX
        command pi $pi_args
        return
    end

    set -l session_name (__pi_session_name "$cwd")
    set -l pi_cmd (string join ' ' -- command pi (string escape -- $pi_args))

    if tmux has-session -t "$session_name" 2>/dev/null
        tmux attach-session -t "$session_name"
    else
        tmux new-session -c "$cwd" -s "$session_name" "$pi_cmd; exec fish"
    end
end

function __pi_clean_candidates --argument-names days
    set -l now (date +%s)
    set -l threshold (math "$days * 86400")

    for dir in (__pi_session_dirs)
        if test (__pi_content_count "$dir") -gt 0
            continue
        end

        if test (__pi_session_state "$dir") = live
            continue
        end

        set -l last_used (__pi_meta_value "$dir" last_used_at)
        set -l stamp

        if test -n "$last_used"
            set stamp (date -d "$last_used" +%s 2>/dev/null)
        end

        if test -z "$stamp"
            set stamp (stat -c %Y "$dir" 2>/dev/null)
        end

        if test -z "$stamp"
            continue
        end

        if test (math "$now - $stamp") -ge "$threshold"
            printf '%s\n' "$dir"
        end
    end
end

function __pi_update_if_needed
    set -l last_check_dir (__pi_cache_dir)
    set -l last_check_file "$last_check_dir/updater_last_check"
    set -l today (date '+%Y-%m-%d')
    set -l last_check

    mkdir -p "$last_check_dir"

    if test -f "$last_check_file"
        set last_check (cat "$last_check_file")
    end

    if test "$last_check" != "$today"
        set -l update_check (npm outdated -g -p @mariozechner/pi-coding-agent 2>/dev/null)

        if test -n "$update_check"
            echo 'Update found! Updating @mariozechner/pi-coding-agent...'
            npm update -g @mariozechner/pi-coding-agent
        end

        echo "$today" > "$last_check_file"
    end
end

function pi
    switch "$argv[1]"
        case help -h --help
            echo 'pi help'
            echo '  pi [--name NAME] [prompt...]'
            echo '  pi new NAME [-- prompt...]   # named managed dir + launch'
            echo '  pi sessions                  # list managed dirs'
            echo '  pi cd [id|query]             # cd into managed dir'
            echo '  pi resume [id|query]         # cd + attach/start session'
            echo '  pi last                      # resume last used managed dir'
            echo '  pi clean [days] [--yes]      # prune old meta-only dirs'
            return
        case sessions ls
            __pi_list_sessions
            return
        case cd
            set -l target (__pi_resolve_target "$argv[2]")
            or return 1
            cd "$target"
            printf '%s\n' "$target"
            return
        case resume
            set -l target (__pi_resolve_target "$argv[2]")
            or return 1
            cd "$target"
            __pi_write_metadata "$target" ""
            __pi_launch_in_tmux "$target"
            return
        case last
            set -l target (__pi_resolve_target)
            or return 1
            cd "$target"
            __pi_write_metadata "$target" ""
            __pi_launch_in_tmux "$target"
            return
        case clean
            set -l days 14
            set -l do_delete 0

            for arg in $argv[2..-1]
                switch "$arg"
                    case --yes
                        set do_delete 1
                    case '*'
                        if string match -qr '^[0-9]+$' -- "$arg"
                            set days "$arg"
                        else
                            echo "Bad clean arg: $arg" >&2
                            return 1
                        end
                end
            end

            set -l victims (__pi_clean_candidates "$days")

            if test (count $victims) -eq 0
                echo "No stale meta-only sessions older than $days days."
                return
            end

            if test "$do_delete" -ne 1
                echo "Dry run. Add --yes to delete:"
                printf '%s\n' $victims
                return
            end

            for dir in $victims
                if test (__pi_content_count "$dir") -eq 0
                    rm -rf "$dir"
                    echo "Deleted $dir"
                end
            end
            return
        case new
            set -l explicit_name "$argv[2]"
            if test -z "$explicit_name"
                echo 'Usage: pi new NAME [-- prompt...]' >&2
                return 1
            end

            set -l pi_args $argv[3..-1]
            if test "$pi_args[1]" = --
                set pi_args $pi_args[2..-1]
            end

            set argv --name "$explicit_name" $pi_args
        case '*'
    end

    __pi_update_if_needed

    set -l explicit_name
    set -l pi_args
    set -l idx 1

    while test $idx -le (count $argv)
        switch "$argv[$idx]"
            case -n --name
                set idx (math "$idx + 1")
                if test $idx -gt (count $argv)
                    echo 'Missing value for --name' >&2
                    return 1
                end
                set explicit_name "$argv[$idx]"
            case --
                set pi_args $argv[(math "$idx + 1")..-1]
                break
            case '*'
                set pi_args $argv[$idx..-1]
                break
        end
        set idx (math "$idx + 1")
    end

    set -l home (realpath ~)
    set -l work_root (__pi_work_root)
    set -l source_cwd (pwd -P)
    set -l cwd "$source_cwd"

    if test "$cwd" = "$home"
        mkdir -p "$work_root"

        set -l label_text "$explicit_name"
        if test -z "$label_text"
            set label_text (__pi_preview_text (__pi_join_args $pi_args))
        end

        set -l dir "$work_root/work-"(date +%Y-%m-%d-%H%M%S)
        set -l label_slug (__pi_slugify "$label_text")
        if test -n "$label_slug"
            set dir "$dir-$label_slug"
        end

        mkdir -p "$dir"
        cd "$dir"
        set cwd (pwd -P)
        __pi_write_metadata "$cwd" "$source_cwd" "$label_text" $pi_args
    else if string match -q "$work_root/*" -- "$cwd"
        __pi_write_metadata "$cwd" "" "$explicit_name" $pi_args
    end

    __pi_launch_in_tmux "$cwd" $pi_args
end

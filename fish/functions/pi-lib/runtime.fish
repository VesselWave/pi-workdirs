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

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

    set -l line (grep -m1 "^$key\t" "$meta" 2>/dev/null)

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

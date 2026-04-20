set __pi_fn_dir (dirname (status filename))
source "$__pi_fn_dir/pi-lib/common.fish"
source "$__pi_fn_dir/pi-lib/listing.fish"
source "$__pi_fn_dir/pi-lib/runtime.fish"
set -e __pi_fn_dir

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

function envs --description 'Back up .env files to Infisical: envs push|pull|diff [env], envs doppler <project> <config> [env] [path]'
    set -l cmd $argv[1]
    set -e argv[1]
    set -l root (git rev-parse --show-toplevel 2>/dev/null); or set root $PWD
    set -l tmp $XDG_RUNTIME_DIR/envs
    mkdir -p -m 700 $tmp # secret values only ever touch tmpfs

    switch "$cmd"
        case push pull diff
            set -l env dev
            test -n "$argv[1]"; and set env $argv[1]
            set -l pid (_envs_project $root); or return 1
            set -l files (_envs_files $root)
            if test (count $files) -eq 0
                echo "no .env files under $root" >&2
                return 1
            end
            if test $cmd = pull
                read -l -P "overwrite "(count $files)" .env file(s) from Infisical $env? [y/N] " yn
                test "$yn" = y -o "$yn" = Y; or return 1
            end
            set -l rc 0
            for f in $files
                set -l path (_envs_path $root $f)
                set -l rel (string replace $root/ '' $f)
                set -l t $tmp/(string replace -a / _ $rel)
                switch $cmd
                    case push
                        envdiff strip $f $t
                        _envs_mkdirs $pid $env $path
                        if infisical secrets set --file $t --env $env --path $path --projectId $pid --silent >/dev/null 2>$tmp/err
                            printf '%-24s %-14s %s keys pushed\n' $rel $path (grep -cvE '^\s*(#|$)' $t)
                        else
                            printf '%-24s %-14s FAILED: %s\n' $rel $path (sed -E 's/=.*//' $tmp/err | head -1)
                            set rc 1
                        end
                    case diff
                        infisical export --env $env --path $path --projectId $pid --format dotenv --silent >$t 2>/dev/null
                        printf '%-24s %-14s ' $rel $path
                        envdiff $f $t local infisical; or set rc 1
                    case pull
                        if infisical export --env $env --path $path --projectId $pid --format dotenv --silent >$t 2>/dev/null
                            cp -p $f $f.bak; and mv $t $f; and chmod 600 $f
                            printf '%-24s %-14s pulled, previous copy in %s.bak\n' $rel $path $rel
                        else
                            printf '%-24s %-14s FAILED\n' $rel $path
                            set rc 1
                        end
                end
                rm -f $t
            end
            return $rc
        case doppler
            if test (count $argv) -lt 2
                echo 'usage: envs doppler <doppler-project> <config> [env] [path]' >&2
                return 1
            end
            set -l env dev; test -n "$argv[3]"; and set env $argv[3]
            set -l path /; test -n "$argv[4]"; and set path $argv[4]
            set -l pid (_envs_project $root); or return 1
            set -l t $tmp/doppler.$argv[1].$argv[2]
            doppler secrets download --no-file --format env -p $argv[1] -c $argv[2] >$t.raw; or return 1
            envdiff strip $t.raw $t
            rm -f $t.raw
            _envs_mkdirs $pid $env $path
            if infisical secrets set --file $t --env $env --path $path --projectId $pid --silent >/dev/null
                echo "doppler $argv[1]/$argv[2] -> infisical $env $path: "(grep -cvE '^\s*(#|$)' $t)" keys"
            end
            rm -f $t
        case list
            set -l pid (_envs_project $root); or return 1
            echo "project $pid"
            for f in (_envs_files $root)
                printf '  %-24s -> %s\n' (string replace $root/ '' $f) (_envs_path $root $f)
            end
        case '*'
            echo 'envs push [env]      push every .env in this repo to Infisical (root -> /, apps/x -> /apps/x)'
            echo 'envs diff [env]      compare local .env files with Infisical by key and value hash'
            echo 'envs pull [env]      overwrite local .env files from Infisical (keeps .env.bak)'
            echo 'envs doppler <project> <config> [env] [path]   import a Doppler config into this project'
            echo 'envs list            show which file maps to which Infisical path'
            echo 'env defaults to dev. Project comes from .infisical.json in the repo root (infisical init creates it).'
    end
end

function _envs_project --argument-names root
    set -l f $root/.infisical.json
    if not test -r $f
        echo "no $f; run 'infisical init' in the repo root first" >&2
        return 1
    end
    string match -rq '"workspaceId"\s*:\s*"(?<id>[^"]+)"' <$f; and echo $id
end

function _envs_files --argument-names root
    find $root -name .env -type f -not -path '*/node_modules/*' -not -path '*/.git/*' | sort
end

# apps/api/.env -> /apps/api ; .env at root -> /
function _envs_path --argument-names root f
    set -l d (string replace $root '' (dirname $f))
    test -n "$d"; and echo $d; or echo /
end

function _envs_mkdirs --argument-names pid env path
    set -l cur /
    for seg in (string split -n / $path)
        infisical secrets folders create --name $seg --path $cur --env $env --projectId $pid --silent >/dev/null 2>&1
        set cur (string replace -r '/$' '' $cur)/$seg
    end
end

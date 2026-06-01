function rm
    # Store the current working directory into a local variable `current_dir`
    # `pwd` prints the current directory path
    set -l current_dir (pwd)

    # Set the path to the monitored directory (Code base directory)
    # `$HOME` expands to the current user's home directory
    set -l code_dir "$HOME/Code"

    # Set the path to the trash directory inside ~/Code
    set -l trash_dir "$code_dir/.trash"

    # Check if the current directory path starts with "$HOME/Code"
    # `string match -q "$code_dir*"` tests for a prefix match silently (-q = quiet)
    if string match -q "$code_dir*" "$current_dir"

        # Ensure the trash directory exists; if not, create it
        # `mkdir -p` creates parent directories as needed without error if already exists
        mkdir -p "$trash_dir"

        # Loop through all arguments passed to the `rm` function
        # `$argv` holds all the arguments passed to the function
        for f in $argv

            # Check if the file or directory specified by `f` actually exists
            # `test -e` returns true if `f` exists (file or directory)
            if test -e "$f"

                # Extract the file or directory name from the full path
                # `basename` strips directory and returns only the final component
                set -l base (basename "$f")

                # Get a timestamp in the format YYYYMMDDHHMMSS (e.g., 20250803153021)
                # `date "+%Y%m%d%H%M%S"` returns a compact, sortable timestamp
                set -l ts (date "+%Y%m%d%H%M%S")

                # Construct the destination path in the trash folder with timestamp appended
                # This avoids name collisions and preserves the deletion time
                set -l target "$trash_dir/$base.$ts"

                # Move the file or directory to the constructed trash path
                # `mv` performs the actual move operation
                mv "$f" "$target"

            end
        end

    else
        # If not in ~/Code, fall back to regular rm command
        # Use `command rm` to explicitly call the real rm and avoid recursion
        command rm $argv
    end
end

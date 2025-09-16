# Copy this file to $XDG_CONFIG_HOME/fish/completions

# Helper function to list existing sandboxes
function __fish_sbx_sandboxes
    set -q XDG_CONFIG_HOME || set XDG_CONFIG_HOME $HOME/.config
    path filter -d $XDG_CONFIG_HOME/sandbubble/* | path basename
end

# Common options
complete -x -c sbx -s h -l help -d 'Display help and exit'
complete -x -c sbx -s v -l verbose -d 'Enable verbose logging' -n __fish_is_first_arg

# Subcommands
complete -x -c sbx -n __fish_use_subcommand -a create -d 'Create a new sandbox'
complete -x -c sbx -n __fish_use_subcommand -a delete -d 'Delete an existing sandbox'
complete -x -c sbx -n __fish_use_subcommand -a edit -d 'Edit sandbox config'
complete -x -c sbx -n __fish_use_subcommand -a list -d 'List existing sandboxes'
complete -x -c sbx -n __fish_use_subcommand -a list-rules -d 'List available rules'
complete -x -c sbx -n __fish_use_subcommand -a reconfig -d 'Reconfigure an existing sandbox'
complete -x -c sbx -n __fish_use_subcommand -a run -d 'Run an existing sandbox'
complete -x -c sbx -n __fish_use_subcommand -a show -d 'Print sandbox config and exit'

# Options for 'create' subcommand
complete -f -c sbx -n '__fish_seen_subcommand_from create' -s c -l config -d 'Override the default config file'
complete -f -c sbx -n '__fish_seen_subcommand_from create' -s r -l rule -d 'Rule or rules to apply instead of the default rules'

# Options for 'delete' subcommand
complete -f -c sbx -n '__fish_seen_subcommand_from delete' -s f -l force -d 'Delete without asking'

# Options for 'list-rules' subcommand
complete -f -c sbx -n '__fish_seen_subcommand_from list-rules' -s c -l config -d 'Override the default config file'

# Options for 'reconfig' subcommand
complete -f -c sbx -n '__fish_seen_subcommand_from reconfig' -s c -l config -d 'Override the default config file'
complete -f -c sbx -n '__fish_seen_subcommand_from reconfig' -s r -l rule -d 'Rule or rules to apply instead of the default rules'

# Options for 'run' subcommand
complete -f -c sbx -n '__fish_seen_subcommand_from run' -s C -l command -d 'Override the sandbox command'

# Subcommands that take a sandbox name
for cmd in delete edit reconfig run show
    complete -x -c sbx -n "__fish_seen_subcommand_from $cmd" -a "(__fish_sbx_sandboxes)" -d Sandbox
end

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# set -x _JAVA_OPTIONS '-Dsun.java2d.uiScale=1.25'

zoxide init fish | source

if test -f $HOME/.sdkman/bin/sdkman-init.sh
    bass source $HOME/.sdkman/bin/sdkman-init.sh
end

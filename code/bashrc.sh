# ---- .bashrc ----
# renzh@mail2.sysu.edu.cn
#-------------------

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

#-------------------
# Personnal Aliases
#-------------------
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
# File size: human-readable
alias df='df -h'
alias du='du -h'
alias disk='du -h --max-depth=1'

#-------------------------------------------------------------
# Greeting, motd etc. ...
#-------------------------------------------------------------
# Normal Colors
Blod='\e[1m'
ULine='\e[4m'
Blank='\e[5m'

Black='\e[30m'        # Black
Red='\e[31m'          # Red
Green='\e[32m'        # Green
Yellow='\e[33m'       # Yellow
Blue='\e[34m'         # Blue
Purple='\e[35m'       # Purple
Cyan='\e[36m'         # Cyan
White='\e[37m'        # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# Bold
BBlack=${Blod}${Black}      # Black
BRed=${Blod}${Red}          # Red
BGreen=${Blod}${Green}      # Green
BYellow=${Blod}${Yellow}    # Yellow
BBlue=${Blod}${Blue}        # Blue
BPurple=${Blod}${Purple}    # Purple
BCyan=${Blod}${Cyan}        # Cyan
BWhite=${Blod}${White}      # White

NC='\e[m'               # Color Reset

ALERT=${BWhite}${On_Red} # Bold White on red background
ServerColor=${Blod}${On_White}

#--------------------
# Test connection type:
if [ -n "${SSH_CONNECTION}" ]; then
    CNX=${ServerColor}             # Connected on remote machine, via ssh (good).
elif [[ "${DISPLAY%%:0*}" != "" ]]; then
    CNX=${ALERT}                   # Connected on remote machine, not via ssh (bad).
else
    CNX=${On_White}${BBlue}        # Connected on local machine.
fi
# Test user type:
if [[ ${USER} == "root" ]]; then
    SU=${Red}              # User is root.
elif [[ ${USER} != $(logname) ]]; then
    SU=${BYellow}          # User is not login user.
else
    SU=${ServerColor}      # User is normal (well ... most of us are).
fi
# Returns system load as percentage, i.e., '40' rather than '0.40)'.
NCPU=$(grep -c 'processor' /proc/cpuinfo)    # Number of CPUs
SLOAD=$(( 100*${NCPU} ))        # Small load
MLOAD=$(( 200*${NCPU} ))        # Medium load
XLOAD=$(( 300*${NCPU} ))        # Xlarge load
function load()
{
    local SYSLOAD=$(cut -d " " -f1 /proc/loadavg | tr -d '.')
    # System load of the current host.
    echo $((10#$SYSLOAD))       # Convert to decimal.
}
#--------------------
# Returns a color indicating system load.
function load_color()
{
    local SYSLOAD=$(load)
    if [ ${SYSLOAD} -gt ${XLOAD} ]; then
        echo -en ${ALERT}
    elif [ ${SYSLOAD} -gt ${MLOAD} ]; then
        echo -en ${BRed}
    elif [ ${SYSLOAD} -gt ${SLOAD} ]; then
        echo -en ${BYellow}
    else
        echo -en ${White}
    fi
}
# Returns a color according to free disk space in $PWD.
function disk_color()
{
    if [ ! -w "${PWD}" ] ; then
        echo -en ${Yellow}
        # No 'write' privilege in the current directory.
    elif [ -s "${PWD}" ] ; then
        local used=$(command df -P "$PWD" |
                   awk 'END {print $5} {sub(/%/,"")}')
        if [ ${used} -gt 95 ]; then
            echo -en ${ALERT}           # Disk almost full (>95%).
        elif [ ${used} -gt 80 ]; then
            echo -en ${BRed}            # Free disk space almost gone.
        else
            echo -en ${BBlue}           # Free disk space is ok.
        fi
    else
        echo -en ${Cyan}
        # Current directory is size '0' (like /proc, /sys etc).
    fi
}
# Returns a color according to running/suspended jobs.
function job_color()
{
    if [ $(jobs -s | wc -l) -gt "0" ]; then
        echo -en ${BRed}
    elif [ $(jobs -r | wc -l) -gt "0" ] ; then
        echo -en ${BCyan}
    fi
}
#--------------------
# Adds some text in the terminal frame (if applicable).
# Construct the prompt.
case ${TERM} in
  *term | rxvt | linux | xterm-256color)
        # PS1="\[\$(load_color)\][\A\[${NC}\] "
        # Time of day (with load info):
        PS1="\[\$(load_color)\]\A\[${NC}\] "
        # User@Host (with connection type info):
        PS1=${PS1}"[\[${SU}\]\u\[${NC}\]\[${CNX}\]@\h\[${NC}\] "
        # PWD (with 'disk space' info):
        PS1=${PS1}"\[\$(disk_color)\]\W\[${NC}\]]"
        # Prompt (with 'job' info):
        PS1=${PS1}"\[\$(job_color)\]$\[${NC}\] "
        # Set title of current xterm:
        PS1=${PS1}"\[\e]0;\u@\h:\w\a\]"
        ;;
    *)
        PS1="(\A \u@\h \W) " # --> PS1="(\A \u@\h \w) > "
                             # --> Shows full pathname of current dir.
        ;;
esac
#---- part end ----

#-------------------
# Format
#-------------------
# 设置历史记录文件位置
export HISTFILE=~/.bash_history
# 设置历史记录的大小
export HISTSIZE=10000
export HISTFILESIZE=20000
# 保证历史记录在每次 shell 退出时保存到文件
shopt -s histappend  # 追加到历史文件而不是覆盖
PROMPT_COMMAND='history -a'  # 保存每个命令到历史文件
export TIMEFORMAT=$'\nreal %3R\tuser %3U\tsys %3S\tpcpu %P\n'
export HISTIGNORE="&:bg:fg:ll:h"
export HISTTIMEFORMAT="$(echo -e ${BCyan})[%d/%m %H:%M:%S]$(echo -e ${NC}) "
export HISTCONTROL=ignoredups
export HOSTFILE=$HOME/.hosts    # Put a list of remote hosts in ~/.hosts

#-------------------------------------------------------------
# The 'ls' family
#-------------------------------------------------------------
# Add colors for filetype and  human-readable sizes by default on 'ls':
alias ls='ls -h --color'
alias l='ls -CFt'
alias lx='ls -lXB'         #  Sort by extension.
alias lk='ls -lSr'         #  Sort by size, biggest last.
alias lt='ls -ltr'         #  Sort by date, most recent last.
alias lc='ls -ltcr'        #  Sort by/show change time,most recent last.
alias lu='ls -ltur'        #  Sort by/show access time,most recent last.
# The ubiquitous 'll': directories first, with alphanumeric sorting:
alias ll="ls -lv --group-directories-first"
alias lm='ll |more'        #  Pipe through 'more'
alias lr='ll -R'           #  Recursive ls.
alias la='ll -A'           #  Show hidden files.
alias tree='tree -Csuh'    #  Nice alternative to 'recursive ls' ...
#-------------------------------------------------------------
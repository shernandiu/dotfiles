CURRENT_BG='NONE'

NUMBER_LINES_DOWN=-1

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac


# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="c.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\uE0BC'
  SEGMENT_END=$'\ue0b0'
  SEGMENT_END_RIGHT=$'\ue0b2'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"   # set backgroung
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"   # set foreground
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then 
    [[ $RIGHT -eq 1 ]] && echo -n " "
    echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    PROMPT_WIDTH=$(( PROMPT_WIDTH + 2 ))
  else
    [[ -n $3 && $RIGHT -eq 1 && $1 != 'NONE' ]] && echo -n "%{%F{$1}%}$SEGMENT_END_RIGHT"
    echo -n "%{$bg%}%{$fg%} "
    PROMPT_WIDTH=$(( PROMPT_WIDTH + 1 ))
  fi
  CURRENT_BG=$1
  if [[ -n $3 ]]; then
    echo -n $3
    printed=${3//\%?}
    PROMPT_WIDTH=$(( PROMPT_WIDTH + $(echo -n $printed|wc -m) ))
    # PROMPT_WIDTH=$(( PROMPT_WIDTH + $(echo -n $printed | grep -Po -c "[\x{1f300}-\x{1f5ff}\x{1f900}-\x{1f9ff}\x{1f600}-\x{1f64f}\x{1f680}-\x{1f6ff}\x{2600}-\x{26ff}\x{2700}-\x{27bf}\x{1f1e6}-\x{1f1ff}\x{1f191}-\x{1f251}\x{1f004}\x{1f0cf}\x{1f170}-\x{1f171}\x{1f17e}-\x{1f17f}\x{1f18e}\x{3030}\x{2b50}\x{2b55}\x{2934}-\x{2935}\x{2b05}-\x{2b07}\x{2b1b}-\x{2b1c}\x{3297}\x{3299}\x{303d}\x{00a9}\x{00ae}\x{2122}\x{23f3}\x{24c2}\x{23e9}-\x{23ef}\x{25b6}\x{23f8}-\x{23fa}]") ))

  fi
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_END"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  PROMPT_WIDTH=$((PROMPT_WIDTH+3))
  CURRENT_BG='NONE'
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\uf418'         # 
  }
  local ref dirty mode repo_path
  local bg fg
  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      bg=yellow 
      fg=black
    else
      bg=green 
      fg=$CURRENT_FG
    fi  

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '±'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    prompt_segment $bg $fg "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_bzr() {
  (( $+commands[bzr] )) || return

  # Test if bzr repository in directory hierarchy
  local dir="$PWD"
  while [[ ! -d "$dir/.bzr" ]]; do
    [[ "$dir" = "/" ]] && return
    dir="${dir:h}"
  done

  local bzr_status status_mod status_all revision
  if bzr_status=$(bzr status 2>&1); then
    status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m)
    status_all=$(echo -n "$bzr_status" | head -n1 | wc -m)
    revision=${$(bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%}
    if [[ $status_mod -gt 0 ]] ; then
      prompt_segment yellow black "bzr@$revision ✚"
    else
      if [[ $status_all -gt 0 ]] ; then
        prompt_segment yellow black "bzr@$revision"
      else
        prompt_segment green black "bzr@$revision"
      fi
    fi
  fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev st branch
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red 15
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green $CURRENT_FG
      fi
      echo -n ${$(hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green $CURRENT_FG
      fi
      echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  local ok
  local directory="${PWD/#$HOME/~}"
  [[ $RETVAL -ne 0 ]] && ok=1 || ok=6
  [[ $PWD == "/mnt/c" || $PWD == "/mnt/c/"* ]] && directory=${PWD/\/mnt\/c/C:}
  prompt_segment $ok 15 $directory
}

# Virtualenv: current working virtualenv
export VIRTUAL_ENV_DISABLE_PROMPT=1
prompt_virtualenv() {
  # if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
  if [[ -n "$VIRTUAL_ENV" ]]; then
    prompt_segment blue black "\ue73c ${VIRTUAL_ENV:t:gs/%/%%}"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols
  local jobsNumber=$(jobs -l | wc -l)

  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  if [[ $jobsNumber -ge 1 ]] then
    [[ $jobsNumber -eq 1 ]] && symbols+="%{%F{cyan}%}\uf013" || symbols+="%{%F{cyan}%}\uf085"
  fi

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols "
}

#AWS Profile:
# - display current AWS_PROFILE name
# - displays yellow on red if profile name contains 'production' or
#   ends in '-prod'
# - displays black on green otherwise
prompt_aws() {
  [[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
  case "$AWS_PROFILE" in
    *-prod|*production*) prompt_segment red yellow  "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
    *) prompt_segment green black "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
  esac
}

prompt_time() {
  prompt_segment $1 $2 "%D{%H:%M:%S} \uf017"
}

get_os(){
  if [[ $(uname -s) == 'Darwin' ]]; then
      CUR_OS='\uf302'
      return
  fi
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release

  case $ID in
    'apple')
    CUR_OS='\uf302';;
    'arch')
    CUR_OS='\uf303';;
    'centos')
    CUR_OS='\uf304';;
    'debian')
    CUR_OS='\uf306';;
    'fedora')
    CUR_OS='\uf30a';;
    'fedora')
    CUR_OS='\uf30a';;
    'linuxmint')
    CUR_OS='\uf30e';;
    'majaro')
    CUR_OS='\uf312';;
    'opensuse')
    CUR_OS='\uf314';;
    'slackware')
    CUR_OS='\uf318';;
    'ubuntu')
    CUR_OS='\uf31b';;
    'pop_os')
    CUR_OS='\uf32a';;

    *)
    CUR_OS='\nf17c'
    ;;
esac
  else
    CUR_OS='\nf17c'
  fi
}

prompt_os(){
  local os
  if [[ $PWD == "/mnt/"* ]] then
    [[ $PWD == "/mnt/c" || $PWD == "/mnt/c/"* ]] && os='\ue70f' || os='\uf0a0'
  else
    os=$CUR_OS
  fi
  prompt_segment 15 black "$os "
}


# Print segment if current shell process is under other shell
prompt_original_shell() {
  if [ -n "$SSH_CLIENT" ]; then
    prompt_segment 22 254 "%B$USER" 
    prompt_segment 34 254 "$HOST%b" 
  fi
  if [[ ! $(ps -p $PPID -o comm) =~ "(Relay)|(sshd)|(login)" ]]; then
  # elif [[ $(ps -p $PPID -o comm) =~ "sh" ]]; then
    prompt_segment 3 236 ""
  fi
}


prompt_conda() {
  if [[ -n $CONDA_DEFAULT_ENV ]]; then
    prompt_segment 77 white "🐍 $CONDA_DEFAULT_ENV"
  fi
}


## Main prompt
build_prompt() {
  RETVAL=$?

  RIGHT=0
  PROMPT_WIDTH=0

  prompt_os
  prompt_original_shell
  prompt_status
  prompt_virtualenv
  prompt_aws
  prompt_conda
  prompt_dir
  prompt_git
  prompt_bzr
  prompt_hg
  prompt_end

  echo -n 0 > /tmp/dontbuiltright
  if [[ $(($PROMPT_WIDTH * 100 / $COLUMNS)) -gt 30 ]] ;then
    RP=$(build_Rprompt)
    local zero='%([BSUbfksu]|([FK]|){*})'
    FOOLENGTH=${#${(S%%)RP//$~zero/}}
    for i in {1..$(( $COLUMNS - $PROMPT_WIDTH - $FOOLENGTH - 2 ))} ; do echo -n " "; done
    echo $RP
    echo -n "%{%F{6}%} ❯%f "
    echo -n 1 > /tmp/dontbuiltright
  fi

  echo -n $RETVAL > /tmp/RETVAL   # export RETVAL
}


get_os

build_Rprompt() {
  [[ $(cat /tmp/dontbuiltright) -eq 1 ]] && return
  RIGHT=1
  prompt_time 15 black
  echo -n ' %f%k'
}


build_old_prompt(){
  local ok
  local directory='%~'
  [[ $RETVAL -ne 0 ]] && ok=1 || ok=6
  [[ $PWD == "/mnt/c" || $PWD == "/mnt/c/"* ]] && directory=${PWD/\/mnt\/c/C:}
  prompt_segment nonw $ok "$directory ❯ "  
  echo -n "%f%k"
}

build_old_rprompt(){
  RIGHT=1
  CURRENT_BG='NONE'
  prompt_time NONE white
  echo -n ' %f%k'
}

del-prompt-accept-line(){
  # actualizar si no hat nada escrito
  # NO SE SI ME GUSTA
  if [[ ! -n $BUFFER ]]; then   
    zle reset-prompt
    return
  fi

  OLD_PROMPT="$PROMPT"
  OLD_RPROMPT="$RPROMPT"
  RETVAL=$(cat /tmp/RETVAL)
  PROMPT="%{%f%b%k%}$(build_old_prompt)" 
  RPROMPT="%{%f%b%k%}$(build_old_rprompt)" 
  zle reset-prompt
  PROMPT="$OLD_PROMPT"
  RPROMPT="$OLD_RPROMPT"
  zle accept-line
}

PROMPT='%{%f%b%k%}$(build_prompt) '
RPROMPT='%{%f%b%k%}$(build_Rprompt)'  

# change prompt on enter
zle -N del-prompt-accept-line
bindkey -M main "^M" del-prompt-accept-line

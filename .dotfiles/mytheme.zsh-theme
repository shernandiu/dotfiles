CURRENT_BG='NONE'

NUMBER_LINES_DOWN=-1

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac


# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
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
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    [[ $RIGHT -eq 0 ]] && echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} " || echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    [[ -n $3 && $RIGHT -eq 1 ]] && echo -n "%{%F{$1}%}$SEGMENT_END_RIGHT"
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  if [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_END"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
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

   if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green $CURRENT_FG
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
    echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
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
  local directory='%~'
  [[ $RETVAL -ne 0 ]] && ok=1 || ok=6
  [[ $PWD == "/mnt/c" || $PWD == "/mnt/c/"* ]] && directory=${PWD/\/mnt\/c/C:}
  prompt_segment $ok 15 $directory
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    prompt_segment blue black "(${VIRTUAL_ENV:t:gs/%/%%})"
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
  prompt_segment 15 black "%D{%H:%M:%S} \uf017"
}

get_os(){
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

# bindkey | grep '\^M'
# "^M" zle accept-line

del-prompt-accept-line() {
    zle accept-line
    
    local OLD_PROMPT="$PROMPT"
    local OLD_RPROMPT="$RPROMPT"
    # echo "$RETVAL"
    [[ $1 -ne 0 ]] && PROMPT="%{%F{6}%}❯%f " || PROMPT="%{%F{1}%}❯%f "
    # echo
    # RPROMPT=${RPROMPT//\%K//\%P}
    # echo $RPROMPT
    # RPROMPT=$(sed 's/F\{*zz}//g'<<<$RPROMPT)
    # echo $RPROMPT
    # RPROMPT=${RPROMPT//\%P//\%F}
    # echo $RPROMPT
    zle reset-prompt
    PROMPT="$OLD_PROMPT"
    RPROMPT="$OLD_RPROMPT"
}

zle -N del-prompt-accept-line 
bindkey "^M" del-prompt-accept-line  

# Print segment if current shell process is under other shell
prompt_original_shell() {
  if [[ $(ps -p $PPID -o comm) != *"Relay("* ]]; then
    prompt_segment 3 8 ""
  fi
}

## Main prompt
build_prompt() {
  RETVAL=$?

  RIGHT=0

  prompt_os
  prompt_original_shell
  prompt_status
  prompt_virtualenv
  prompt_aws
  prompt_dir
  prompt_git
  prompt_bzr
  prompt_hg
  prompt_end

  if [[ ${#${PWD##/home/shernandi}} -gt 20 ]] ;then
    echo -n "\n%{%F{6}%}❯%f "
  fi
  echo -n "%E"
}


get_os

build_Rprompt() {
  RIGHT=1
  # [[ ${#${PWD##/home/shernandi}} -gt 20 ]] && NUMBER_LINES_DOWN=1||NUMBER_LINES_DOWN=0

  # [[ $NUMBER_LINES_DOWN -gt 0 ]] && echotc UP $NUMBER_LINES_DOWN
  prompt_time
  # prompt_segment  green white '%d'
  # prompt_segment  magenta white $PWD

  echo -n ' %f%k'
  # [[ $NUMBER_LINES_DOWN -gt 0 ]] && echotc DO $NUMBER_LINES_DOWN
}
# setopt PROMPT_SUBST


BUILD_PROMPT="%{%f%b%k%}$(build_prompt)"
BUILD_RPROMPT="%{%f%b%k%}$(build_Rprompt)"

RPROMPT='%{%f%b%k%}$(build_Rprompt)'  
PROMPT='%{%f%b%k%}$(build_prompt) '

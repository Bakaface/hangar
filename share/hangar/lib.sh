trap "exit 1" TERM
export TOP_PID=$$

# Parsed by hangar bindings generator
shortcut() { :; }

if [[ "$TERM" =~ "screen".* ]]; then
  echo 'Already inside a tmux session!'
  exit 0
fi

new() {
  if [ -z ${path+x} ]; then
    eval "tmux new-window -t $session:$1 -n '$2'"
  else
    eval "tmux new-window -t $session:$1 -c ${path} -n '$2'"
  fi
  current_window=$2
  if type before &> /dev/null; then
    before
  fi
}

rename() {
  tmux rename-window -t $1 $2
  current_window=$2
}

send() {
  tmux send-keys -t "$current_window" "$1" C-m
}

vsplit() {
  if [ -z ${path+x} ]; then
    tmux split-window -h
  else
    eval "tmux split-window -h -c $path"
  fi
}

init() {
  tmux has-session -t $session 2>/dev/null
  if [ $? != 0 ]; then
    if [ -z ${path+x} ]; then
      eval "tmux new -d -s $session"
    else
      eval "tmux new -d -s $session -c $path"
    fi
  else
    echo 'Session is running'
    kill -s TERM $TOP_PID
  fi
}

init_vim() {
  rename 0 'vim'
  if type before &> /dev/null; then
    before
  fi
  send 'nvim $(pwd)'
}

init_gitui() {
  new 8 'gitui'
  send 'gitui'
}

init_project() {
  init_vim
  init_gitui
}

init_basic() {
  init
  init_vim
  new 9 'bash'
}

attach() {
  [ "$1" = "a" ] && tmux a -t $session:0
}

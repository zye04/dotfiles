# --- Plugins ---
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- Relace ---
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=default'
ZSH_HIGHLIGHT_STYLES[command]='fg=default'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=default'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=default'
ZSH_HIGHLIGHT_STYLES[function]='fg=default'
ZSH_HIGHLIGHT_STYLES[alias]='fg=default'
ZSH_HIGHLIGHT_STYLES[path]='fg=default'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=default'

# --- Histórico ---
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS        # ignora comandos repetidos seguidos
setopt HIST_IGNORE_ALL_DUPS    # remove duplicados antigos
setopt SHARE_HISTORY           # partilha histórico entre terminais abertos
setopt INC_APPEND_HISTORY      # grava imediatamente

# --- Autocompletar ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select                        # menu navegável com setas
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'    # ignora maiúsculas/minúsculas

# --- Os teus aliases (o ficheiro que já criaste!) ---
[ -f ~/.aliases ] && source ~/.aliases

# --- dirétorio cor ---
export LS_COLORS="di=33"   # di = diretório, 33 = amarelo

# --- Prompt Starship (tem de ser a última linha) ---
eval "$(starship init zsh)"

# --- zoxide (cd inteligente) ---
eval "$(zoxide init zsh)"

# --- fzf (Ctrl+R e Ctrl+T turbinados) ---
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh
export PATH="$HOME/.local/bin:$PATH"

# --- Function para ajuste de handshake ethernet ---
handshake() {
  local iface="enp5s0"
  case "$1" in
    1000|gbit|gig)
      sudo ethtool -s "$iface" autoneg on advertise 0x020
      echo "→ a anunciar apenas 1000baseT/Full (sem fallback)"
      ;;
    all|auto|100)
      sudo ethtool -s "$iface" autoneg on advertise 0x03f
      echo "→ a anunciar 10/100/1000 (auto-negociação normal)"
      ;;
    status|"")
      echo "speed: $(cat /sys/class/net/$iface/speed) Mb/s"
      sudo ethtool "$iface" | grep -A4 "Advertised link modes"
      ;;
    *)
      echo "uso: handshake [1000|all|status]"
      return 1
      ;;
  esac
}
alias obsidian-theme='code /home/zye/vault/.obsidian/snippets/theme.css'
# local-suite: unload the local LLM (frees VRAM; recovers a stuck/garbage model).
# The next sidebar message loads it again. See ~/Projects/dev/local-suite/docs/plan.md
alias llm-reset='curl -fsS -X POST http://127.0.0.1:8080/api/models/unload >/dev/null && echo "local model unloaded"'

# --- VOX (voice-layer) ---
# Keep codex as the native CLI; use `vox codex` for its voice interface.
unalias codex 2>/dev/null
unalias vox 2>/dev/null
function vox {
  if [[ ${1-} == codex ]]; then
    shift
    command uv run --project ~/Projects/dev/voice-layer voice-layer --provider codex "$@"
  else
    command uv run --project ~/Projects/dev/voice-layer voice-layer "$@"
  fi
}

# --- JOBIFY (jobflow) ---
# Open the browser workspace by default; `jobify tui` and other CLI args pass through.
unalias jobify 2>/dev/null
unfunction jobify 2>/dev/null
alias jobify="/home/zye/Projects/dev/jobify/scripts/jobify"

# cmatrix paints palette color0 as cell bg; map it to #000000 so kitty's
# transparent_background_colors keeps it translucent, then restore the theme.
cmatrix() {
  printf '\e]4;0;#000000\e\\'
  command cmatrix "$@"
  printf '\e]104;0\e\\'
}

#!/bin/bash
# ============================================================
#  鼠标光标工坊  ——  光标主题 + 拖尾/点击特效 管理面板
#  双击本文件即可在终端里运行
# ============================================================
set -u

LIB="$(cd "$(dirname "$0")" && pwd)"
SUP="$HOME/Library/Application Support/CursorKit"
CONF="$SUP/config.txt"
BIN="$SUP/bin"
UID_="$(id -u)"
AGENT_CURSOR="local.cursorkit.cursor"
AGENT_FX="local.cursorkit.effects"
AGENT_THEME="local.cursorkit.theme"

# ---------------- 配色方案 ----------------
PAL_KEYS="gray neon sunset cosmic sakura aurora custom"
PAL_NAME_gray="黑白灰";     PAL_COLORS_gray="#FFFFFF,#D0D0D0,#9A9A9A"
PAL_NAME_neon="霓虹紫青";   PAL_COLORS_neon="#00E5FF,#7C4DFF,#FF3DDA"
PAL_NAME_sunset="落日橙粉"; PAL_COLORS_sunset="#FFB86B,#FF7A59,#FF4D6D"
PAL_NAME_cosmic="星尘金蓝"; PAL_COLORS_cosmic="#FFD166,#8ECAE6,#4A7CFF"
PAL_NAME_sakura="樱花粉白"; PAL_COLORS_sakura="#FFFFFF,#FFC2D1,#FF8FAB"
PAL_NAME_aurora="极光青绿"; PAL_COLORS_aurora="#6BFFB8,#38D9A9,#1E9E7A"
PAL_NAME_custom="自定义"

STYLE_TRAIL_afterimage="残影拖尾"; STYLE_TRAIL_stardust="粒子星尘"; STYLE_TRAIL_streak="流光"
STYLE_CLICK_burst="粒子爆炸";      STYLE_CLICK_wave="冲击波";      STYLE_CLICK_spark="星芒"
INT_light="轻微"; INT_medium="中等"; INT_fancy="炫"

# ---------------- 默认值 ----------------
D_CURSOR_ENABLED=1; D_CURSOR_SET=""
D_TRAIL_ENABLED=0;  D_TRAIL_STYLE=afterimage; D_TRAIL_PALETTE=gray
D_CLICK_ENABLED=0;  D_CLICK_STYLE=burst;      D_CLICK_PALETTE=gray
D_CUSTOM_COLORS="#FFFFFF,#00E5FF,#FF3DDA"
D_INTENSITY=medium; D_AUTOSTART=1
D_THEME_AUTO=0; D_THEME_LIGHT=""; D_THEME_DARK=""

cfg_get() { [ -f "$CONF" ] && sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -1; }
cfg_get_or() { local v; v="$(cfg_get "$1")"; [ -n "$v" ] && echo "$v" || echo "$2"; }

load_cfg() {
  CURSOR_ENABLED="$(cfg_get_or cursor.enabled $D_CURSOR_ENABLED)"
  CURSOR_SET="$(cfg_get_or cursor.set "$D_CURSOR_SET")"
  TRAIL_ENABLED="$(cfg_get_or trail.enabled $D_TRAIL_ENABLED)"
  TRAIL_STYLE="$(cfg_get_or trail.style $D_TRAIL_STYLE)"
  TRAIL_PALETTE="$(cfg_get_or trail.palette $D_TRAIL_PALETTE)"
  CLICK_ENABLED="$(cfg_get_or click.enabled $D_CLICK_ENABLED)"
  CLICK_STYLE="$(cfg_get_or click.style $D_CLICK_STYLE)"
  CLICK_PALETTE="$(cfg_get_or click.palette $D_CLICK_PALETTE)"
  CUSTOM_COLORS="$(cfg_get_or custom.colors "$D_CUSTOM_COLORS")"
  INTENSITY="$(cfg_get_or intensity $D_INTENSITY)"
  AUTOSTART="$(cfg_get_or autostart $D_AUTOSTART)"
  THEME_AUTO="$(cfg_get_or theme.auto $D_THEME_AUTO)"
  THEME_LIGHT="$(cfg_get_or theme.light.set "$D_THEME_LIGHT")"
  THEME_DARK="$(cfg_get_or theme.dark.set "$D_THEME_DARK")"
  # 旧配置里的 trail.colors / click.colors 保留兼容
  TRAIL_COLORS="$(palette_colors "$TRAIL_PALETTE")"
  CLICK_COLORS="$(palette_colors "$CLICK_PALETTE")"
}

palette_colors() {
  case "$1" in
    gray) echo "$PAL_COLORS_gray";;
    neon) echo "$PAL_COLORS_neon";;
    sunset) echo "$PAL_COLORS_sunset";;
    cosmic) echo "$PAL_COLORS_cosmic";;
    sakura) echo "$PAL_COLORS_sakura";;
    aurora) echo "$PAL_COLORS_aurora";;
    custom) echo "$CUSTOM_COLORS";;
    *) echo "$PAL_COLORS_gray";;
  esac
}

palette_name() {
  local v="PAL_NAME_$1"
  eval "echo \${$v:-未知}"
}

save_cfg() {
  mkdir -p "$SUP"
  {
    echo "cursor.enabled=$CURSOR_ENABLED"
    echo "cursor.set=$CURSOR_SET"
    echo "trail.enabled=$TRAIL_ENABLED"
    echo "trail.style=$TRAIL_STYLE"
    echo "trail.palette=$TRAIL_PALETTE"
    echo "trail.colors=$(palette_colors "$TRAIL_PALETTE")"
    echo "click.enabled=$CLICK_ENABLED"
    echo "click.style=$CLICK_STYLE"
    echo "click.palette=$CLICK_PALETTE"
    echo "click.colors=$(palette_colors "$CLICK_PALETTE")"
    echo "custom.colors=$CUSTOM_COLORS"
    echo "intensity=$INTENSITY"
    echo "autostart=$AUTOSTART"
    echo "theme.auto=$THEME_AUTO"
    echo "theme.light.set=$THEME_LIGHT"
    echo "theme.dark.set=$THEME_DARK"
  } > "$CONF"
}

# ---------------- 颜色解析（智能识别 # 有无、3 位缩写） ----------------
parse_hex() {
  local s="$1"
  s="$(echo "$s" | tr 'A-Z' 'a-z' | tr -d ' \t')"
  s="${s#\#}"; s="${s#0x}"
  case "$s" in
    *[!0-9a-f]*) return 1;;
  esac
  if [ ${#s} -eq 3 ]; then
    s="$(echo "$s" | sed 's/\(.\)\(.\)\(.\)/\1\1\2\2\3\3/')"
  fi
  [ ${#s} -eq 6 ] || return 1
  echo "#$(echo "$s" | tr 'a-z' 'A-Z')"
}

# ---------------- 套装 ----------------
set_has_cursors() {
  [ -n "$(find "$1" -maxdepth 3 \( -iname '*.cur' -o -iname '*.ani' -o -iname '*.cape' -o -iname '*.zip' \) -print -quit 2>/dev/null)" ]
}

list_sets() {
  local d
  SETS=()
  for d in "$LIB"/*/; do
    [ -d "$d" ] || continue
    local base; base="$(basename "$d")"
    case "$base" in .*|_*) continue;; esac
    set_has_cursors "$d" || continue
    SETS+=("$base")
  done
}

ensure_cape() {
  local name="$1" dir="$LIB/$1" cape="$SUP/capes/$1.cape"
  mkdir -p "$SUP/capes"
  if [ -f "$cape" ] && [ -z "$(find "$dir" -newer "$cape" -type f -print -quit 2>/dev/null)" ]; then
    return 0
  fi
  echo "  正在转换「${name}」…"
  local out
  out="$(/usr/bin/python3 "$BIN/convert.py" "$dir" "$cape" --name "$name" 2>&1)"
  echo "$out" | sed 's/^/    /'
  [ -f "$cape" ]
}

apply_cape() {
  local name="$1"
  local cape="$SUP/capes/$name.cape"
  [ -f "$cape" ] || { echo "  ✗ 找不到主题文件"; return 1; }
  "$BIN/mousecloak" --apply "$cape" >/dev/null 2>&1
  "$BIN/mousecloak" --dump "$SUP/.check.cape" >/dev/null 2>&1
  local want got
  want="$(plutil -extract 'Cursors.com\.apple\.coregraphics\.Arrow.PointsWide' raw -o - "$cape" 2>/dev/null | cut -d. -f1)"
  got="$(plutil -extract 'Cursors.com\.apple\.coregraphics\.Arrow.PointsWide' raw -o - "$SUP/.check.cape" 2>/dev/null | cut -d. -f1)"
  rm -f "$SUP/.check.cape"
  if [ -n "$want" ] && [ "$got" = "$want" ]; then return 0; fi
  echo "  ! 第一次没有完全生效，重试一次…"
  "$BIN/mousecloak" --apply "$cape" >/dev/null 2>&1
  return 0
}

restore_stock() {
  [ -f "$SUP/backup/stock.cape" ] || { echo "  ✗ 缺少系统备份"; return 1; }
  "$BIN/mousecloak" --apply "$SUP/backup/stock.cape" >/dev/null 2>&1
  "$BIN/mousecloak" --dump "$SUP/.check.cape" >/dev/null 2>&1
  local got
  got="$(plutil -extract 'Cursors.com\.apple\.coregraphics\.Arrow.PointsWide' raw -o - "$SUP/.check.cape" 2>/dev/null | cut -d. -f1)"
  rm -f "$SUP/.check.cape"
  [ "$got" = "28" ] && return 0
  return 0
}

# ---------------- 特效进程 ----------------
fx_running() { pgrep -f "CursorKit/bin/cursoreffects" >/dev/null 2>&1; }

fx_start() {
  fx_running && return 0
  if agent_loaded "$AGENT_FX"; then
    launchctl kickstart "gui/$UID_/$AGENT_FX" >/dev/null 2>&1
  else
    mkdir -p "$SUP/logs"
    nohup "$BIN/cursoreffects" --now >>"$SUP/logs/effects.log" 2>&1 &
  fi
  sleep 1
}

fx_stop() {
  pkill -f "CursorKit/bin/cursoreffects" >/dev/null 2>&1
}

agent_loaded() { launchctl print "gui/$UID_/$1" >/dev/null 2>&1; }

agent_load() {
  agent_loaded "$1" || launchctl bootstrap "gui/$UID_" "$HOME/Library/LaunchAgents/$1.plist" >/dev/null 2>&1
}

agent_unload() {
  agent_loaded "$1" && launchctl bootout "gui/$UID_/$1" >/dev/null 2>&1
}

# 让「开/关」在重启后依然有效（disable/enable 会被 launchd 记录）
agent_enable()  { launchctl enable  "gui/$UID_/$1" >/dev/null 2>&1; }
agent_disable() { launchctl disable "gui/$UID_/$1" >/dev/null 2>&1; }

# ---------------- 支持文件（自动修复 / 升级用） ----------------
ensure_support() {
  mkdir -p "$SUP/logs" "$SUP/capes" "$HOME/Library/LaunchAgents"

  cat > "$SUP/apply-cursor.sh" <<'EOS'
#!/bin/sh
# 应用光标：若开启「自动适应深浅主题」，则按当前外观选择对应套装
BASE="$HOME/Library/Application Support/CursorKit"
CONF="$BASE/config.txt"
get() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -1; }
[ "$(get cursor.enabled)" = "1" ] || exit 0
slug="$(get cursor.set)"
if [ "$(get theme.auto)" = "1" ]; then
  if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then
    t="$(get theme.dark.set)"
  else
    t="$(get theme.light.set)"
  fi
  [ -n "$t" ] && slug="$t"
fi
[ -n "$slug" ] || exit 0
cape="$BASE/capes/$slug.cape"
[ -f "$cape" ] || exit 0
want=$(plutil -extract 'Cursors.com\.apple\.coregraphics\.Arrow.PointsWide' raw -o - "$cape" 2>/dev/null | cut -d. -f1)
i=1
while [ "$i" -le 4 ]; do
  "$BASE/bin/mousecloak" --apply "$cape" >/dev/null 2>&1
  "$BASE/bin/mousecloak" --dump "$BASE/.check.cape" >/dev/null 2>&1
  got=$(plutil -extract 'Cursors.com\.apple\.coregraphics\.Arrow.PointsWide' raw -o - "$BASE/.check.cape" 2>/dev/null | cut -d. -f1)
  if [ -n "$want" ] && [ "$got" = "$want" ]; then rm -f "$BASE/.check.cape"; exit 0; fi
  i=$((i + 1))
  sleep 4
done
rm -f "$BASE/.check.cape"
exit 1
EOS
  chmod 755 "$SUP/apply-cursor.sh"

  cat > "$SUP/theme-watch.sh" <<'EOS'
#!/bin/sh
# 监视 macOS 浅色/深色外观，变化时自动切换到对应的光标套装
BASE="$HOME/Library/Application Support/CursorKit"
CONF="$BASE/config.txt"
LOG="$BASE/logs/theme.log"
get() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -1; }
mode_now() {
  if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then echo dark; else echo light; fi
}
mkdir -p "$BASE/logs"
last=""
while :; do
  if [ "$(get theme.auto)" = "1" ] && [ "$(get cursor.enabled)" = "1" ]; then
    m="$(mode_now)"
    if [ "$m" != "$last" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') appearance=${m}" >> "$LOG"
      # 日志只保留最后 400 行
      if [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 400 ]; then
        tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
      fi
      /bin/sh "$BASE/apply-cursor.sh" >> "$LOG" 2>&1
      last="$m"
    fi
  else
    last=""
  fi
  sleep 3
done
EOS
  chmod 755 "$SUP/theme-watch.sh"

  cat > "$HOME/Library/LaunchAgents/$AGENT_THEME.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_THEME</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>$HOME/Library/Application Support/CursorKit/theme-watch.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$HOME/Library/Application Support/CursorKit/logs/theme.log</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Application Support/CursorKit/logs/theme.log</string>
</dict>
</plist>
EOF
}

theme_agent_start() { ensure_support; agent_enable "$AGENT_THEME"; agent_load "$AGENT_THEME"; }
theme_agent_stop()  { agent_unload "$AGENT_THEME"; agent_disable "$AGENT_THEME"; }

# 按当前外观立刻应用一次
theme_apply_now() { /bin/sh "$SUP/apply-cursor.sh" >/dev/null 2>&1; }

# ---------------- 界面 ----------------
line() { printf '%s\n' "────────────────────────────────────────────────────────"; }

show_status() {
  local cset="${CURSOR_SET:-未设置}"
  local tstyle="关闭"; [ "$TRAIL_ENABLED" = "1" ] && tstyle="$(palette_name_style trail "$TRAIL_STYLE")（$(palette_name "$TRAIL_PALETTE")）"
  local cstyle="关闭"; [ "$CLICK_ENABLED" = "1" ] && cstyle="$(palette_name_style click "$CLICK_STYLE")（$(palette_name "$CLICK_PALETTE")）"
  local auto="开"; [ "$AUTOSTART" != "1" ] && auto="关"
  local theme="关"
  if [ "$THEME_AUTO" = "1" ]; then
    local tl="${THEME_LIGHT:-未设置}" td="${THEME_DARK:-未设置}"
    theme="开（浅 ${tl} · 深 ${td}）"
  fi
  echo "  光标：$cset      强度：$(palette_name_style int "$INTENSITY")"
  echo "  拖尾：$tstyle"
  echo "  点击：$cstyle"
  echo "  自动适应深浅主题：$theme"
  echo "  开机自启：$auto    特效进程：$(fx_running && echo 运行中 || echo 未运行)"
}

palette_name_style() {
  case "$1:$2" in
    trail:afterimage) echo "$STYLE_TRAIL_afterimage";;
    trail:stardust)   echo "$STYLE_TRAIL_stardust";;
    trail:streak)     echo "$STYLE_TRAIL_streak";;
    click:burst)      echo "$STYLE_CLICK_burst";;
    click:wave)       echo "$STYLE_CLICK_wave";;
    click:spark)      echo "$STYLE_CLICK_spark";;
    int:light)        echo "$INT_light";;
    int:medium)       echo "$INT_medium";;
    int:fancy)        echo "$INT_fancy";;
    *) echo "$2";;
  esac
}

rd() {  # 读一行；输入结束（EOF）就退出，避免死循环
  local __name="$1"
  if ! IFS= read -r "$__name"; then
    echo
    echo "  （输入结束，退出）"
    exit 0
  fi
}

pause_key() { echo; printf '  按回车返回…'; rd _; }

# ---------------- 子菜单：设置光标 ----------------
menu_cursor() {
  while true; do
    load_cfg
    clear
    line; echo "  设置光标"; line
    list_sets
    if [ ${#SETS[@]} -eq 0 ]; then
      echo "  （「${LIB}」里还没有光标套装）"
      echo "  把网上下载的光标文件夹放进这个目录即可。"
    else
      local i=1
      for s in "${SETS[@]}"; do
        local mark=""; [ "$s" = "$CURSOR_SET" ] && mark="  ← 当前"
        echo "  $i) $s$mark"
        i=$((i + 1))
      done
    fi
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
    esac
    case "$ans" in
      *[!0-9]*) continue;;
    esac
    [ "$ans" -ge 1 ] && [ "$ans" -le ${#SETS[@]} ] || continue
    local pick="${SETS[$((ans - 1))]}"
    echo
    if ensure_cape "$pick"; then
      echo "  正在应用「${pick}」…"
      apply_cape "$pick"
      CURSOR_ENABLED=1; CURSOR_SET="$pick"
      save_cfg
      echo "  ✓ 已应用「${pick}」"
    else
      echo "  ✗ 转换失败，这个套装里可能没有可识别的光标文件"
    fi
    pause_key
  done
}

# ---------------- 子菜单：配色 ----------------
menu_palette() {
  local which="$1"   # trail | click
  while true; do
    load_cfg
    clear
    line; echo "  配色（$( [ "$which" = "trail" ] && echo 拖尾 || echo 点击 )）"; line
    local cur; [ "$which" = "trail" ] && cur="$TRAIL_PALETTE" || cur="$CLICK_PALETTE"
    local i=1
    for k in $PAL_KEYS; do
      local mark=""; [ "$k" = "$cur" ] && mark="  ← 当前"
      printf '  %d) %-8s %s%s\n' "$i" "$(palette_name "$k")" "$(palette_colors "$k")" "$mark"
      i=$((i + 1))
    done
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in 0|"") return;; esac
    case "$ans" in *[!0-9]*) continue;; esac
    local idx=1 key=""
    for k in $PAL_KEYS; do
      [ "$ans" -eq "$idx" ] && key="$k"
      idx=$((idx + 1))
    done
    [ -n "$key" ] || continue
    if [ "$key" = "custom" ]; then
      custom_palette "$which" || continue
    else
      if [ "$which" = "trail" ]; then TRAIL_PALETTE="$key"; else CLICK_PALETTE="$key"; fi
      save_cfg
    fi
    fx_start
    echo "  ✓ 配色已设为「$(palette_name "$key")」"
    pause_key
  done
}

custom_palette() {
  local which="$1"
  clear
  line; echo "  自定义配色"; line
  echo "  输入 1-8 个颜色，支持 #RRGGBB、RRGGBB、#RGB，带不带 # 都可以"
  echo "  例如： #00E5FF  ff7a59  #abc"
  echo
  printf '  要几个颜色？（直接回车取消）：'; rd n
  case "$n" in ""|0) return 1;; esac
  case "$n" in *[!0-9]*) echo "  请输入数字"; sleep 1; return 1;; esac
  if [ "$n" -lt 1 ] || [ "$n" -gt 8 ]; then echo "  只能是 1-8"; sleep 1; return 1; fi
  local out="" i=1 v hex
  while [ "$i" -le "$n" ]; do
    while true; do
      printf '  第 %d 个颜色：' "$i"; rd v
      if [ -z "$v" ]; then echo "  （已取消）"; return 1; fi
      if hex="$(parse_hex "$v")"; then break; fi
      echo "  解析不了「${v}」，请输入类似 #00E5FF 或 00e5ff 的值"
    done
    if [ -z "$out" ]; then out="$hex"; else out="$out,$hex"; fi
    i=$((i + 1))
  done
  CUSTOM_COLORS="$out"
  if [ "$which" = "trail" ]; then TRAIL_PALETTE="custom"; else CLICK_PALETTE="custom"; fi
  save_cfg
  echo "  ✓ 自定义配色：$out"
  return 0
}

# ---------------- 子菜单：拖尾 ----------------
menu_trail() {
  while true; do
    load_cfg
    clear
    line; echo "  设置拖尾"; line
    echo "  1) 关闭"
    echo "  2) 残影拖尾（跟着光标的一串残影）"
    echo "  3) 粒子星尘（沿路径洒下的光点）"
    echo "  4) 流光（一条会消散的光带）"
    echo "  5) 配色      当前：$(palette_name "$TRAIL_PALETTE")"
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
      1) TRAIL_ENABLED=0; save_cfg; fx_stop_if_all_off; echo "  ✓ 已关闭拖尾"; pause_key;;
      2) TRAIL_ENABLED=1; TRAIL_STYLE=afterimage; save_cfg; fx_start; echo "  ✓ 拖尾：残影拖尾"; pause_key;;
      3) TRAIL_ENABLED=1; TRAIL_STYLE=stardust; save_cfg; fx_start; echo "  ✓ 拖尾：粒子星尘"; pause_key;;
      4) TRAIL_ENABLED=1; TRAIL_STYLE=streak; save_cfg; fx_start; echo "  ✓ 拖尾：流光"; pause_key;;
      5) menu_palette trail;;
    esac
  done
}

# ---------------- 子菜单：点击 ----------------
menu_click() {
  while true; do
    load_cfg
    clear
    line; echo "  设置点击"; line
    echo "  1) 关闭"
    echo "  2) 粒子爆炸（向外炸开的小粒子）"
    echo "  3) 冲击波（扩散的圆环）"
    echo "  4) 星芒（八向闪光）"
    echo "  5) 配色      当前：$(palette_name "$CLICK_PALETTE")"
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
      1) CLICK_ENABLED=0; save_cfg; fx_stop_if_all_off; echo "  ✓ 已关闭点击特效"; pause_key;;
      2) CLICK_ENABLED=1; CLICK_STYLE=burst; save_cfg; fx_start; echo "  ✓ 点击：粒子爆炸"; pause_key;;
      3) CLICK_ENABLED=1; CLICK_STYLE=wave;  save_cfg; fx_start; echo "  ✓ 点击：冲击波"; pause_key;;
      4) CLICK_ENABLED=1; CLICK_STYLE=spark; save_cfg; fx_start; echo "  ✓ 点击：星芒"; pause_key;;
      5) menu_palette click;;
    esac
  done
}

fx_stop_if_all_off() {
  if [ "$TRAIL_ENABLED" != "1" ] && [ "$CLICK_ENABLED" != "1" ]; then fx_stop; fi
}

# ---------------- 自动适应深浅主题 ----------------
pick_set() {   # 从套装列表里选一个，结果放在 CHOSEN
  local title="$1"
  while true; do
    clear
    line; echo "  ${title}"; line
    list_sets
    if [ ${#SETS[@]} -eq 0 ]; then
      echo "  （「${LIB}」里还没有光标套装）"
      echo
      printf '  按回车返回…'; rd _; CHOSEN=""; return 1
    fi
    local i=1
    for s in "${SETS[@]}"; do
      local mark=""; [ "$s" = "$CURSOR_SET" ] && mark="  ← 当前"
      echo "  $i) $s$mark"
      i=$((i + 1))
    done
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in 0|"") CHOSEN=""; return 1;; esac
    case "$ans" in *[!0-9]*) continue;; esac
    [ "$ans" -ge 1 ] && [ "$ans" -le ${#SETS[@]} ] || continue
    CHOSEN="${SETS[$((ans - 1))]}"
    return 0
  done
}

theme_setup() {
  load_cfg
  local l d
  if ! pick_set "自动适应 · ① 浅色外观下用哪套光标？"; then return; fi
  l="$CHOSEN"
  if ! pick_set "自动适应 · ② 深色外观下用哪套光标？"; then return; fi
  d="$CHOSEN"
  clear
  line; echo "  自动适应 · 准备套装"; line
  echo "  正在准备「${l}」…"
  if ! ensure_cape "$l"; then echo "  ✗ 「${l}」转换失败"; pause_key; return; fi
  echo "  正在准备「${d}」…"
  if ! ensure_cape "$d"; then echo "  ✗ 「${d}」转换失败"; pause_key; return; fi
  THEME_LIGHT="$l"
  THEME_DARK="$d"
  CURSOR_ENABLED=1
  [ -z "$CURSOR_SET" ] && CURSOR_SET="$l"
  save_cfg
  echo
  echo "  ✓ 已保存：浅色 → ${l} ，深色 → ${d}"
  if [ "$THEME_AUTO" = "1" ]; then
    theme_agent_start
    theme_apply_now
    echo "  ✓ 已按当前外观立即应用"
  else
    echo "  （自动适应现在是「关」，回到上一级按 1 打开即可生效）"
  fi
  pause_key
}

theme_toggle() {
  load_cfg
  if [ "$THEME_AUTO" = "1" ]; then
    THEME_AUTO=0
    save_cfg
    theme_agent_stop
    echo "  ✓ 已关闭自动适应（光标保持当前样式，不再随系统外观切换）"
  else
    if [ -z "$THEME_LIGHT" ] || [ -z "$THEME_DARK" ]; then
      echo "  还没有设置浅色/深色的光标，请先进入「2) 设置」。"
      pause_key
      return
    fi
    THEME_AUTO=1
    CURSOR_ENABLED=1
    [ -z "$CURSOR_SET" ] && CURSOR_SET="$THEME_LIGHT"
    save_cfg
    theme_agent_start
    theme_apply_now
    echo "  ✓ 已开启自动适应"
    echo "    浅色外观 → ${THEME_LIGHT}"
    echo "    深色外观 → ${THEME_DARK}"
    echo "    现在就按当前外观生效，之后随系统切换。"
  fi
  pause_key
}

menu_theme() {
  while true; do
    load_cfg
    clear
    line; echo "  自动适应深浅主题"; line
    local auto="关"; [ "$THEME_AUTO" = "1" ] && auto="开"
    echo "  当前：$auto"
    echo "    浅色外观 → ${THEME_LIGHT:-未设置}"
    echo "    深色外观 → ${THEME_DARK:-未设置}"
    echo
    echo "  跟随 macOS 的浅色/深色自动切换光标，切换后立刻生效。"
    echo
    echo "  1) 开/关"
    echo "  2) 设置（分别选择浅色 / 深色下的光标）"
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
      1) theme_toggle;;
      2) theme_setup;;
    esac
  done
}

# ---------------- 强度 ----------------
menu_intensity() {
  while true; do
    load_cfg
    clear
    line; echo "  设置强度"; line
    echo "  1) 轻微"
    echo "  2) 中等（默认）"
    echo "  3) 炫"
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
      1) INTENSITY=light;;
      2) INTENSITY=medium;;
      3) INTENSITY=fancy;;
      *) continue;;
    esac
    save_cfg; fx_start
    echo "  ✓ 强度：$(palette_name_style int "$INTENSITY")"
    pause_key
  done
}

# ---------------- 开机自启 ----------------
menu_autostart() {
  while true; do
    load_cfg
    clear
    line; echo "  开机自动启动"; line
    local auto="开"; [ "$AUTOSTART" != "1" ] && auto="关"
    echo "  当前：$auto"
    echo
    echo "  1) 开（登录后自动应用光标主题和特效）"
    echo "  2) 关（登录后保持系统默认，本次运行不受影响）"
    echo "  0) 返回"
    echo
    printf '  请选择：'; rd ans
    case "$ans" in
      0|"") return;;
      1) AUTOSTART=1; save_cfg; ensure_support
         agent_enable "$AGENT_CURSOR"; agent_load "$AGENT_CURSOR"
         agent_enable "$AGENT_FX"; agent_load "$AGENT_FX"
         if [ "$THEME_AUTO" = "1" ]; then theme_agent_start; else theme_agent_stop; fi
         echo "  ✓ 已开启开机自启（下次登录会自动应用，重启也不会丢）"; pause_key;;
      2) AUTOSTART=0; save_cfg
         agent_unload "$AGENT_CURSOR"; agent_disable "$AGENT_CURSOR"
         agent_unload "$AGENT_FX"; agent_disable "$AGENT_FX"
         theme_agent_stop
         echo "  ✓ 已关闭开机自启（登录后不再自动应用；本次运行仍然有效）"; pause_key;;
    esac
  done
}

# ---------------- 还原 ----------------
menu_reset() {
  clear
  line; echo "  还原系统默认配置"; line
  echo "  会做这些事："
  echo "    · 光标恢复成 macOS 默认"
  echo "    · 关闭拖尾和点击特效"
  echo "    · 关闭自动适应深浅主题"
  echo "    · 关闭开机自动启动"
  echo "    · 清空面板里的设置记录"
  echo "  （文件夹里的光标套装和生成的缓存都会保留）"
  echo
  printf '  确定吗？输入 y 回车确认：'; rd ans
  case "$ans" in y|Y) ;; *) return;; esac
  echo
  echo "  正在还原光标…"
  restore_stock
  fx_stop
  CURSOR_ENABLED=0; CURSOR_SET=""
  TRAIL_ENABLED=0; CLICK_ENABLED=0
  THEME_AUTO=0; THEME_LIGHT=""; THEME_DARK=""
  AUTOSTART=0
  TRAIL_STYLE=afterimage; TRAIL_PALETTE=gray
  CLICK_STYLE=burst; CLICK_PALETTE=gray
  INTENSITY=medium
  save_cfg
  agent_unload "$AGENT_CURSOR"; agent_disable "$AGENT_CURSOR"
  agent_unload "$AGENT_FX"; agent_disable "$AGENT_FX"
  theme_agent_stop
  echo "  ✓ 已还原成系统默认配置"
  pause_key
}

# ---------------- 主菜单 ----------------
load_cfg
ensure_support
if [ "$THEME_AUTO" = "1" ]; then theme_agent_start; else theme_agent_stop; fi

trap 'echo; echo "  已退出"; exit 0' INT
while true; do
  load_cfg
  clear
  line
  echo "  鼠标光标工坊      $LIB"
  line
  show_status
  line
  echo "  1) 设置光标"
  echo "  2) 设置拖尾"
  echo "  3) 设置点击"
  echo "  4) 设置强度"
  echo "  5) 一键开启特效（拖尾 + 点击）"
  echo "  6) 一键关闭特效"
  echo "  7) 开机自动启动"
  echo "  8) 自动适应深浅主题"
  echo "  9) 还原系统默认配置"
  echo "  0) 退出"
  line
  printf '  请选择：'; rd ans
  case "$ans" in
    1) menu_cursor;;
    2) menu_trail;;
    3) menu_click;;
    4) menu_intensity;;
    5) TRAIL_ENABLED=1; [ -z "${TRAIL_STYLE:-}" ] && TRAIL_STYLE=afterimage
       CLICK_ENABLED=1; [ -z "${CLICK_STYLE:-}" ] && CLICK_STYLE=burst
       save_cfg; fx_start
       echo "  ✓ 已开启拖尾（$(palette_name_style trail "$TRAIL_STYLE")）+ 点击（$(palette_name_style click "$CLICK_STYLE")）"
       pause_key;;
    6) TRAIL_ENABLED=0; CLICK_ENABLED=0; save_cfg; fx_stop
       echo "  ✓ 已关闭全部特效"; pause_key;;
    7) menu_autostart;;
    8) menu_theme;;
    9) menu_reset;;
    0) clear; echo "  已退出"; exit 0;;
  esac
done

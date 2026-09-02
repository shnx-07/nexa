import datetime
import glob
from kitty.fast_data_types import Screen, add_timer, get_boss
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    draw_tab_with_powerline,
)

def as_rgb(x: int) -> int:
    return (x << 8) | 2

# Catppuccin / WezTerm matched colors
COLOR_DATE = as_rgb(0xfab387)       # Peach
COLOR_SEP = as_rgb(0x74c7ec)        # Sapphire / Cyan
COLOR_BATTERY = as_rgb(0xf9e2af)    # Yellow

CHARGING_ICONS = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
DISCHARGING_ICONS = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

timer_initialized = False

def update_timer(timer_id: int) -> None:
    boss = get_boss()
    if boss:
        boss.refresh_active_tab_bar()

def get_battery_info() -> tuple[str, str]:
    chargers = glob.glob("/sys/class/power_supply/BAT*")
    if not chargers:
        return "100%", "󰂅"
    bat = chargers[0]
    try:
        with open(f"{bat}/capacity") as f:
            cap = int(f.read().strip())
        with open(f"{bat}/status") as f:
            status = f.read().strip().lower()
    except Exception:
        return "100%", "󰂅"
    
    charging = status in ("charging", "full")
    idx = max(0, min(9, (cap - 1) // 10))
    icon = CHARGING_ICONS[idx] if charging else DISCHARGING_ICONS[idx]
    return f"{cap}%", icon

def draw_right_status(draw_data: DrawData, screen: Screen) -> None:
    now = datetime.datetime.now()
    date_str = now.strftime("%a %H:%M:%S")
    date_icon = " "
    
    sep_str = " — "
    
    bat_pct, bat_icon = get_battery_info()
    bat_str = f"{bat_icon} {bat_pct}"
    
    # Calculate visible length
    total_len = len(date_icon) + len(date_str) + len(sep_str) + len(bat_str) + 1
    
    rem_space = screen.columns - screen.cursor.x
    if rem_space > total_len:
        # Fill gap
        padding = rem_space - total_len
        screen.cursor.bg = as_rgb(int(draw_data.default_bg))
        screen.cursor.fg = as_rgb(int(draw_data.default_bg))
        screen.cursor.bold = False
        screen.draw(" " * padding)
        
        # Draw Date
        screen.cursor.bold = True
        screen.cursor.fg = COLOR_DATE
        screen.draw(date_icon + date_str)
        
        # Draw Separator
        screen.cursor.bold = False
        screen.cursor.fg = COLOR_SEP
        screen.draw(sep_str)
        
        # Draw Battery
        screen.cursor.bold = True
        screen.cursor.fg = COLOR_BATTERY
        screen.draw(bat_str + " ")

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global timer_initialized
    if not timer_initialized:
        timer_initialized = True
        add_timer(update_timer, 1.0, True)

    end = draw_tab_with_powerline(
        draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
    )
    if is_last:
        draw_right_status(draw_data, screen)
    return end

# nifi-config
中科大源：  
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch  
cn源：  
[archlinuxcn]  
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch  

kitty firefox waypaper pipewire-pulse pavucontrol swayidle swww swaylock-effects libnotify mako polkit-gnome  

输入法  
fcitx5-im  fcitx5-chinese-addons  
字体  
ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji  

查看字体家族  
fc-list : family | sort -u  
刷新字体缓存  
fc-cache -fv  

查看僵尸进程  
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/ {print}'  

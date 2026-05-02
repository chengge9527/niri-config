# nifi-config
中科大源：  
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch  
cn源：  
[archlinuxcn]  
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch  

kitty intel-ucode vulkan-radeon firefox waypaper pipewire-pulse pavucontrol swayidle swww swaylock-effects libnotify mako polkit-gnome  

输入法  
fcitx5-im  fcitx5-chinese-addons  
字体  
ttf-dejavu ttf-jetbrains-mono-nerd noto-fonts-cjk noto-fonts-emoji (noto-fonts adobe-source-han-sans-otc-fonts)  
截图软件  
grim swappy slurp  

查看字体家族  
fc-list : family | sort -u  
刷新字体缓存  
fc-cache -fv  

清理孤包  
sudo pacman -Rns $(pacman -Qdtq)  

查看僵尸进程  
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/ {print}'  

重启网卡  
nmcli device disconnect eno1  
nmcli device connect eno1 

lutris
  魔兽争霸 中文输入法环境变量
  LANG=zh_CN.UTF-8
  PROTON_ENABLE_WAYLAND=1

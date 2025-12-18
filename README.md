# nifi-config
中科大源：  
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch  
cn源：  
[archlinuxcn]  
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch  

挂载硬盘 fstab:  
/dev/sdc:  
UUID=5abf737b-a4a6-439a-9b2d-89a7d2c15787       /home/monkey/hdd-500g   ext4   rw,relatime   0 2  


kitty firefox waypaper pipewire-pulse pavucontrol swayidle swww swaylock-effects libnotify mako polkit-gnome  
输入法 fcitx5-im  fcitx5-chinese-addons  
字体   ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji  

查看字体家族  
fc-list : family | sort -u  
刷新字体缓存  
fc-cache -fv  

查看僵尸进程  
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/ {print}'  

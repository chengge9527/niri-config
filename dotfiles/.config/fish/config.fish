function fish_prompt
    # 获取完整路径
    set fullpath (pwd)

    # 如果路径在 $HOME 下，把前缀替换成 ~
    set display_path (string replace -r "^$HOME" "~" $fullpath)

    # 第一行：显示路径（不缩写）
    set_color cyan
    echo $display_path

    # 第二行：提示符
    set_color green
    echo -n "❯ "
    set_color normal
end

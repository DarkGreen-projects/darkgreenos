# Build DarkgreenOS inside WSL (use this from PowerShell on Windows)
$Project = (wsl wslpath -a $PSScriptRoot).Trim()
wsl -e bash -lc "cd '$Project' && make $args"

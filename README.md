# linux 环境初始化

_该项目仅为方便本人配置服务器使用，并不保证兼容_

## 此仓库用于快速初始化一台Linux

* `tasklist.txt` 是脚本列表，记录配置名称和对应脚本路径（可以完整的 `url` ）。

* `scripts` 目录存放本地脚本。

* 主脚本自动拉取 `tasklist.txt` 和任务脚本，也可以使用本地的 `tasklist.txt`。

### 国内使用

1. **常规使用**

    ```bash
    curl -OJ https://gitee.com/bytesharky/server-init/raw/main/server-init.sh

    chmod +x server-init.sh

    ./server-init.sh
    ```

2. **中文乱码时使用**

    ```bash
    curl -OJ https://gitee.com/bytesharky/server-init/raw/main/server-init-en.sh

    chmod +x server-init-en.sh

    ./server-init-en.sh
    ```

### 国外使用

1. **常规使用**

    ```bash
    curl -OJ https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/server-init.sh

    chmod +x server-init.sh

    ./server-init.sh
    ```

2. **中文乱码时使用**

    ```bash
    curl -OJ https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/server-init-en.sh

    chmod +x server-init-en.sh

    ./server-init-en.sh
    ```

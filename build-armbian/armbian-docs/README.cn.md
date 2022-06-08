# Armbian 构建及使用方法

查看英文说明 | [View English description](README.md)

Github Actions 是 Microsoft 推出的一项服务，它提供了性能配置非常不错的虚拟服务器环境，基于它可以进行构建、测试、打包、部署项目。对于公开仓库可免费无时间限制地使用，且单次编译时间长达 6 个小时，这对于编译 Armbian 来说是够用的（我们一般在3小时左右可以完成一次编译工作）。分享只是为了交流经验，不足的地方请大家理解，请不要在网络上发起各种不好的攻击行为，也不要恶意使用 GitHub Actions。

# 目录

- [Armbian 构建及使用方法](#armbian-构建及使用方法)
- [目录](#目录)
  - [1. 注册自己的 Github 的账户](#1-注册自己的-github-的账户)
  - [2. 设置隐私变量 GITHUB_TOKEN](#2-设置隐私变量-github_token)
  - [3. Fork 仓库并设置 GH_TOKEN](#3-fork-仓库并设置-gh_token)
  - [4. 个性化 Armbian 固件定制文件说明](#4-个性化-armbian-固件定制文件说明)
  - [5. 编译固件](#5-编译固件)
    - [5.1 手动编译](#51-手动编译)
    - [5.2 定时编译](#52-定时编译)
  - [6. 保存固件](#6-保存固件)
  - [7. 下载固件](#7-下载固件)
  - [8. 安装 Armbian 到 EMMC](#8-安装-armbian-到-emmc)
  - [9. 编译 Armbian 内核](#9-编译-armbian-内核)
  - [10. 更新 Armbian 内核](#10-更新-armbian-内核)
  - [11. 常见问题](#11-常见问题)
    - [11.1 每个盒子的 dtb 和 u-boot 对应关系表](#111-每个盒子的-dtb-和-u-boot-对应关系表)
    - [11.2 LED 屏显示控制说明](#112-led-屏显示控制说明)
    - [11.3 如何恢复原安卓 TV 系统](#113-如何恢复原安卓-tv-系统)
      - [11.3.1 使用 armbian-ddbr 备份恢复](#1131-使用-armbian-ddbr-备份恢复)
      - [11.3.2 使用 Amlogic 刷机工具恢复](#1132-使用-amlogic-刷机工具恢复)
    - [11.4 设置盒子从 USB/TF/SD 中启动](#114-设置盒子从-usbtfsd-中启动)
    - [11.5 禁用红外接收器](#115-禁用红外接收器)
    - [11.6 启动引导文件的选择](#116-启动引导文件的选择)

## 1. 注册自己的 Github 的账户

注册自己的账户，以便进行固件个性化定制的继续操作。点击 github.com 网站右上角的 `Sign up` 按钮，根据提示注册自己的账户。

## 2. 设置隐私变量 GITHUB_TOKEN

设置 Github 隐私变量 `GITHUB_TOKEN` 。在固件编译完成后，我们需要上传固件到 Releases ，我们根据 Github 官方的要求设置这个变量，方法如下：
Personal center: Settings > Developer settings > Personal access tokens > Generate new token ( Name: GITHUB_TOKEN, Select: public_repo )。其他选项根据自己需要可以多选。提交保存，复制系统生成的加密 KEY 的值，先保存到自己电脑的记事本，下一步会用到这个值。图示如下：

<div style="width:100%;margin-top:40px;margin:5px;">
<img src=https://user-images.githubusercontent.com/68696949/109418474-85032b00-7a03-11eb-85a2-759b0320cc2a.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/109418479-8b91a280-7a03-11eb-8383-9d970f4fffb6.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/109418483-90565680-7a03-11eb-8320-0df1174b0267.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/109418493-9815fb00-7a03-11eb-862e-deca4a976374.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/109418485-93514700-7a03-11eb-848d-36de784a4438.jpg width="300" />
</div>

## 3. Fork 仓库并设置 GH_TOKEN

现在可以 Fork 仓库了，打开仓库 https://github.com/ophub/amlogic-s9xxx-armbian ，点击右上的 Fork 按钮，复制一份仓库代码到自己的账户下，稍等几秒钟，提示 Fork 完成后，到自己的账户下访问自己仓库里的 amlogic-s9xxx-armbian 。在右上角的 `Settings` > `Secrets` > `Actions` > `New repostiory secret` ( Name: `GH_TOKEN`, Value: `填写刚才GITHUB_TOKEN的值` )，保存。并在左侧导航栏的 `Actions` > `General` > `Workflow permissions` 下选择 `Read and write permissions` 并保存。图示如下：

<div style="width:100%;margin-top:40px;margin:5px;">
<img src=https://user-images.githubusercontent.com/68696949/109418568-0eb2f880-7a04-11eb-81c9-194e32382998.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/163203032-f044c63f-d113-4076-bf94-41f86c7dd0ce.png width="300" />
<img src=https://user-images.githubusercontent.com/68696949/109418573-15417000-7a04-11eb-97a7-93973d7479c2.jpg width="300" />
<img src=https://user-images.githubusercontent.com/68696949/167579714-fdb331f3-5198-406f-b850-13da0024b245.png width="300" />
<img src=https://user-images.githubusercontent.com/68696949/167585338-841d3b05-8d98-4d73-ba72-475aad4a95a9.png width="300" />
</div>

## 4. 个性化 Armbian 固件定制文件说明

固件编译的流程在 [.github/workflows/build-armbian.yml](../../.github/workflows/build-armbian.yml) 文件里控制，在 workflows 目录下还有其他 .yml 文件，实现其他不同的功能。编译固件时采用了 Armbian 官方的当前代码进行实时编译，相关参数可以查阅官方文档。

```yaml
- name: Compile Armbian [ ${{ env.ARMBIAN_BOARD }} ]
  id: compile
  run: |
    cd build/
    sudo chmod +x compile.sh
    sudo ./compile.sh BRANCH=${{ env.ARMBIAN_BRANCH }} RELEASE=${{ env.ARMBIAN_RELEASE }} BOARD=${{ env.ARMBIAN_BOARD }} \
                      BUILD_MINIMAL=no BUILD_DESKTOP=no HOST=armbian KERNEL_ONLY=no KERNEL_CONFIGURE=no \
                      CLEAN_LEVEL=make,debs COMPRESS_OUTPUTIMAGE=sha
    echo "::set-output name=status::success"
```

## 5. 编译固件

固件编译的方式很多，可以设置定时编译，手动编译，或者设置一些特定事件来触发编译。我们先从简单的操作开始。

### 5.1 手动编译

在自己仓库的导航栏中，点击 Actions 按钮，再依次点击 Build armbian > Run workflow > Run workflow ，开始编译，等待大约 3 个小时，全部流程都结束后就完成编译了。图示如下：

<div style="width:100%;margin-top:40px;margin:5px;">
<img src=https://user-images.githubusercontent.com/68696949/163203938-e7762b09-e6b8-4cf5-b1f1-9c67c1a29953.png width="300" />
<img src=https://user-images.githubusercontent.com/68696949/163204044-9c7a7429-47ee-4fce-b7dd-e217bebf6133.png width="300" />
<img src=https://user-images.githubusercontent.com/68696949/163204127-6b16b558-7e78-4c22-a28a-7b37b5a34fa3.png width="300" />
</div>

### 5.2 定时编译

在 [.github/workflows/build-armbian.yml](../../.github/workflows/build-armbian.yml) 文件里，使用 Cron 设置定时编译，5 个不同位置分别代表的意思为 分钟 (0 - 59) / 小时 (0 - 23) / 日期 (1 - 31) / 月份 (1 - 12) / 星期几 (0 - 6)(星期日 - 星期六)。通过修改不同位置的数值来设定时间。系统默认使用 UTC 标准时间，请根据你所在国家时区的不同进行换算。

```yaml
schedule:
  - cron: '0 17 * * *'
```

## 6. 保存固件

固件保存的设置也在 [.github/workflows/build-armbian.yml](../../.github/workflows/build-armbian.yml) 文件里控制。我们将编译好的固件通过脚本自动上传到 github 官方提供的 Releases 里面。

```yaml
- name: Upload Armbian Firmware to Release
  uses: ncipollo/release-action@main
  if: steps.build.outputs.status == 'success' && env.UPLOAD_RELEASE == 'true' && !cancelled()
  with:
    tag: Armbian_${{ env.FILE_DATE }}
    artifacts: ${{ env.FILEPATH }}/*
    allowUpdates: true
    token: ${{ secrets.GH_TOKEN }}
    body: |
      This is Armbian firmware for Amlogic s9xxx TV Boxes
      * Firmware information
      Default username: root
      Default password: 1234
```

## 7. 下载固件

从仓库首页右下角的 Release 版块进入，选择和自己盒子型号对应的固件。图示如下：

<div style="width:100%;margin-top:40px;margin:5px;">
<img src=https://user-images.githubusercontent.com/68696949/163204798-0d98524c-73df-4876-8912-fcae2845fbba.png width="300" />
<img src=https://user-images.githubusercontent.com/68696949/163204879-4898babf-fa00-4e63-89ea-235129e2ce1d.png width="300" />
</div>

## 8. 安装 Armbian 到 EMMC

登录 Armbian 系统 (默认用户: root, 默认密码: 1234) → 输入命令：

```yaml
armbian-install
```

默认将安装主线 u-boot，以便支持 5.10 及以上内核的使用。如果选择不安装，请在第 `1` 个输入参数中指定，如 `armbian-install no`

## 9. 编译 Armbian 内核

支持在 Ubuntu20.04/22.04 或 Armbian 系统中编译内核。支持本地编译，也支持使用 GitHub Actions 云编译，具体方法详见 [内核编译说明](../../compile-kernel/README.cn.md)。

## 10. 更新 Armbian 内核

登录 Armbian 系统 → 输入命令：

```yaml
# 使用 root 用户运行 (sudo -i)
# 如果不指定其他参数，以下更新命令将更新到当前同系列内核的最新版本。
armbian-update
```

如果当前目录下有成套的内核文件，将使用当前目录的内核进行更新（更新需要的 4 个内核文件是 `header-xxx.tar.gz`, `boot-xxx.tar.gz`, `dtb-amlogic-xxx.tar.gz`, `modules-xxx.tar.gz`。其他内核文件不需要，如果同时存在也不影响更新，系统可以准确识别需要的内核文件）。如果当前目录没有内核文件，将从服务器查询并下载同系列的最新内核进行更新。你也可以查询[可选内核](https://github.com/ophub/kernel/tree/main/pub/stable)版本，进行指定版本更新：`armbian-update 5.10.100`。在设备支持的可选内核里可以自由更新，如从 5.10.100 内核更新为 5.15.25 内核。内核更新时，默认从 [stable](https://github.com/ophub/kernel/tree/main/pub/stable) 内核版本分支下载，如果下载其他 [版本分支](https://github.com/ophub/kernel/tree/main/pub) 的内核，请在第 `2` 个参数中根据分支文件夹名称指定，如 `armbian-update 5.7.19 dev` 。默认会自动安装主线 u-boot，这对使用 5.10 以上版本的内核有更好的支持，如果选择不安装，请在第 `3` 个输入参数中指定，如 `armbian-update 5.10.100 stable no`

内核中的 `headers` 文件默认安装在 `/use/local/include` 目录下。

## 11. 常见问题

在 Armbian 的使用中，一些可能遇到的常见问题汇总如下。

### 11.1 每个盒子的 dtb 和 u-boot 对应关系表

请查阅[说明](amlogic_model_database.md)

### 11.2 LED 屏显示控制说明

请查阅[说明](led_screen_display_control.md)

### 11.3 如何恢复原安卓 TV 系统

通常使用 armbian-ddbr 备份恢复，或者使用 Amlogic 刷机工具恢复原安卓 TV 系统。

#### 11.3.1 使用 armbian-ddbr 备份恢复

建议您在全新的盒子里安装 Armbian 系统前，先对当前盒子自带的原安卓 TV 系统进行备份，以便在需要恢复系统时使用。请从 `TF/SD/USB` 启动 Armbian 系统，输入 `armbian-ddbr` 命令，然后根据提示输入 `b` 进行系统备份，备份文件的存放路径为 `/ddbr/BACKUP-arm-64-emmc.img.gz` ，请下载保存。在需要恢复安卓 TV 系统时，将之前备份的文件上传至 `TF/SD/USB` 设备的相同路径下，输入 `armbian-ddbr` 命令，然后根据提示输入 `r` 进行系统恢复。

#### 11.3.2 使用 Amlogic 刷机工具恢复

- 一般情况下，重新插入电源，如果可以从 USB 中启动，只要重新安装即可，多试几次。

- 如果接入显示器后，屏幕是黑屏状态，无法从 USB 启动，就需要进行盒子的短接初始化了。先将盒子恢复到原来的安卓系统，再重新刷入 Armbian 系统。首先下载 [amlogic_usb_burning_tool](https://github.com/ophub/kernel/releases/tag/tools) 系统恢复工具并安装好。准备一条 [USB 双公头数据线](https://user-images.githubusercontent.com/68696949/159267576-74ad69a5-b6fc-489d-b1a6-0f8f8ff28634.png)，准备一个 [曲别针](https://user-images.githubusercontent.com/68696949/159267790-38cf4681-6827-4cb6-86b2-19c7f1943342.png)。

- 以 x96max+ 为例，在盒子的主板上确认 [短接点](https://user-images.githubusercontent.com/68696949/110590933-67785300-81b3-11eb-9860-986ef35dca7d.jpg) 的位置，下载盒子的 [Android TV 固件包](https://github.com/ophub/kernel/releases/tag/tools)。其他常见设备的安卓 TV 系统固件及对应的短接点示意图也可以在此[下载查看](https://github.com/ophub/kernel/releases/tag/tools)。

```
操作方法：

1. 打开刷机软件 USB Burning Tool:
   [ 文件 → 导入固件包 ]: X96Max_Plus2_20191213-1457_ATV9_davietPDA_v1.5.img
   [ 选择 ]：擦除 flash
   [ 选择 ]：擦除 bootloader
   点击 [ 开始 ] 按钮
2. 使用 [ 曲别针 ] 将盒子主板上的 [ 两个短接点进行短接连接 ]，
   并同时使用 [ USB 双公头数据线 ] 将 [ 盒子 ] 与 [ 电脑 ] 进行连接。
3. 当看到 [ 进度条开始走动 ] 后，拿走曲别针，不再短接。
4. 当看到 [ 进度条 100% ], 则刷机完成，盒子已经恢复成 Android TV 系统。
   点击 [ 停止 ] 按钮, 拔掉 [ 盒子 ] 和 [ 电脑 ] 之间的 [ USB 双公头数据线] 。
5. 如果以上某个步骤失败，就再来一次，直至成功。
   如果进度条没有走动，可以尝试插入电源。通长情况下不用电源支持供电，只 USB 双公头的供电即可满足刷机要求。
```

当完成恢复出厂设置，盒子已经恢复成 Android TV 系统，其他安装 Armbian 系统的操作，就和你之前第一次安装系统时的要求一样了，再来一遍即可。

### 11.4 设置盒子从 USB/TF/SD 中启动

- 把刷好固件的 USB/TF/SD 插入盒子。
- 开启开发者模式: 设置 → 关于本机 → 版本号 (如: X96max plus...), 在版本号上快速连击 5 次鼠标左键, 看到系统显示 `开启开发者模式` 的提示。
- 开启 USB 调试模式: 系统 → 高级选选 → 开发者选项 (设置 `开启USB调试` 为启用)。启用 `ADB` 调试。
- 安装 ADB 工具：下载 [adb](https://github.com/ophub/kernel/releases/tag/tools) 并解压，将 `adb.exe`，`AdbWinApi.dll`，`AdbWinUsbApi.dll` 三个文件拷⻉到 `c://windows/` 目录下的 `system32` 和 `syswow64` 两个文件夹内，然后打开 `cmd` 命令面板，使用 `adb --version` 命令，如果有显示就表示可以使用了。
- 进入 `cmd` 命令模式。输入 `adb connect 192.168.1.137` 命令（其中的 ip 根据你的盒子修改，可以到盒子所接入的路由器设备里查看），如果链接成功会显示 `connected to 192.168.1.137:5555`
- 输入 `adb shell reboot update` 命令，盒子将重启并从你插入的 USB/TF/SD 启动，从浏览器访问固件的 IP 地址，或者 SSH 访问即可进入固件。

### 11.5 禁用红外接收器

默认情况下启用对红外接收器的支持，但如果您将电视盒用作服务器，那么您可能希望禁用 IR 内核模块以防止错误地关闭您的盒子。 要完全禁用 IR，请添加以下行：

```yaml
blacklist meson_ir
```

至 `/etc/modprobe.d/blacklist.conf` 并重启。

### 11.6 启动引导文件的选择

一般情况下，使用 /boot/uEnv.txt 即可。个别设备需要使用 `/bootfs/extlinux/extlinux.conf` 文件，如 T95（s905x） / T95Z-Plus（s912）等设备。如果需要，将固件自带的 `/boot/extlinux/extlinux.conf.bak` 文件名称中的 `.bak` 删除即可使用。当写入 eMMC 时 `armbian-install` 会自动检查，如果存在 `extlinux.conf` 文件，会自动创建。


# 相关文件说明

查看英文说明 | [View English description](README.md)

在相关目录中存储了编译 Armbian 所需的文件。

## amlogic-armbian

这里存放的文件是打包 Armbian 时需要使用的相关文件。

## amlogic-kernel

在 `amlogic-kernel` 目录下存放的是编译 Armbian 需要的内核文件，使用方法见 [amlogic-kernel/README.md](amlogic-kernel/README.md)

## amlogic-u-boot

当你使用 5.10 内核的 Armbian 时，需要将 overload 目录下对应的 u-boot 文件复制为 `u-boot.ext` ，在 EMMC 中使用时，需要将 u-boot 文件复制为 `u-boot.emmc` 。一些设备需要写入对应的 bootloader 文件。这些复制工作在仓库的打包和安装/升级脚本中均已自动化完成，无需在人工复制。

## armbian-docs

这里存放的是 Armbian 使用文档。

## common-files

- rootfs: 这里存放的是 Armbian 固件的个性化配置文件，将在打包脚本 `sudo ./rebuild` 执行时自动将相关文件集成到你的固件里。相关目录及文件命名均须与 Armbian 中 ROOTFS 分区 ( 即在 TTYD 终端里输入： `cd / && ls .` 你所看到的目录及各目录里面的文件名称 ) 保持完全一致。

```yaml
etc/network/interfaces
usr/sbin
```

- bootfs: 这里存放的是 Armbian 系统中 `/boot` 目录下的个性化配置文件。

- patches: 这是补丁文件存放目录，你可以将扩展文件，补丁等放置在该目录。

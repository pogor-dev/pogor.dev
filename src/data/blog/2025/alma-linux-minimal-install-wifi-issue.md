---
author: Victor Pogor
pubDatetime: 2025-02-08T22:42:09.000+10:00
modDatetime:
title: Fixing WiFi Issues on AlmaLinux Minimal Install
description: Learn how to resolve WiFi connection issues on AlmaLinux minimal install by installing the necessary NetworkManager-wifi package.
slug: fixing-wifi-issues-almalinux-minimal-install
featured: false
draft: false
tags:
  - RHEL
  - AlmaLinux
  - WiFi
  - NetworkManager
---

## Table of Contents

## Quick Fix

If you're struggling to connect to a WiFi network after a minimal install of AlmaLinux, you're not alone. When trying to activate the device (`nmcli dev up wlp0s20f3`), you might see this error:

`failed to add/activate new connection. Device class NMDeviceGeneric had no complete_connection`

The solution is simple: install the `NetworkManager-wifi` package:

```sh
dnf install NetworkManager-wifi
```

## Introduction

I recently repurposed my old laptop as a home lab server. While a wired connection is generally more reliable, I wanted the flexibility of a WiFi connection.

I installed [AlmaLinux 9.5](https://almalinux.org/) with a [minimal install](https://wiki.almalinux.org/documentation/installation-guide.html#software) as the base environment and enabled the [ANSI BP 028 (high)](https://wiki.almalinux.org/documentation/installation-guide.html#installation) security profile.

Everything worked fine with the **Server with GUI** base environment, but the **Minimal install** left me unable to connect to WiFi. Following the [official guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/assembly_managing-wifi-connections_configuring-and-managing-networking) didn't help.

Using `nmtui` to activate a connection only showed wired networks, and `nmcli` returned the error mentioned above.

After some digging, I found the solution in [this forum](https://access.redhat.com/discussions/6964734). The minimal install doesn't include the `NetworkManager-wifi` package or its dependencies (`wireless-regdb` and `iw`).

These are the following commands I have used until I discovered this error:

```sh
[root@homelab ~]# nmcli radio wifi
enabled

[root@homelab ~]# nmcli device wifi
[root@homelab ~]# nmcli device status
DEVICE        TYPE      STATE                  CONNECTION
lo           loopback  connected (externally)  --
wlp0s20f3    wifi      unavailable             --
eno1         ethernet  unavailable             --

[root@homelab ~]# nmcli device set wlp0s20f3 managed yes
[root@homelab ~]# nmcli device status
DEVICE        TYPE      STATE                  CONNECTION
lo           loopback  connected (externally)  --
wlp0s20f3    wifi      unavailable             --
eno1         ethernet  unavailable             --

[root@homelab ~]# nmcli device connect wlp0s20f3
Error: Failed to add/activate new connection: Device class NMDeviceGeneric had no complete_connection method
```

The same error is visible here:

```sh
[root@homelab ~]# systemctl status NetworkManager
● NetworkManager.service - Network Manager
    Loaded: loaded (/usr/lib/systemd/system/NetworkManager.service; enabled; preset: enabled)
    Active: active (running) since Fri 2025-02-07 22:46:51 EST; 5min ago
    Main PID: 3107 (NetworkManager)
    Tasks: 3 (limit: 32768)
    Memory: 11.3M
    CPU: 113ms
    CGroup: /system.slice/NetworkManager.service
        └─3107 /usr/sbin/NetworkManager --no-daemon

Feb 07 22:46:51 homelab NetworkManager[3107]: <info>  [1720392411.474711] device (lo): activation successful, device activated.
Feb 07 22:46:51 homelab NetworkManager[3107]: <info>  [1720392411.474717] manager: startup complete
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.311437] device (wlp0s20f3): state change: unmanaged -> unavailable (reason "connection-assumed", sys-iface-state: "assume")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375127] ifcfg-rh: new connection /etc/sysconfig/network-scripts/ifcfg-wlp0s20f3 (interface wlp0s20f3, pid 6323) add 0 result: success
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375134] device (wlp0s20f3): state change: unavailable -> disconnected (reason "none", sys-iface-state: "managed")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375137] device (wlp0s20f3): Activation: starting connection 'wlp0s20f3' (uuid ...)
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375140] device (wlp0s20f3): Activation: beginning transaction (timeout in 120 seconds)
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375144] device (wlp0s20f3): state change: disconnected -> prepare (reason "none", sys-iface-state: "managed")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375148] device (wlp0s20f3): state change: prepare -> config (reason "none", sys-iface-state: "managed")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375151] device (wlp0s20f3): state change: config -> need-auth (reason "none", sys-iface-state: "managed")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375154] device (wlp0s20f3): state change: need-auth -> failed (reason "no-secrets", sys-iface-state: "managed")
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375157] device (wlp0s20f3): Activation: failed for connection 'wlp0s20f3'
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375160] manager: NetworkManager state is now DISCONNECTED
Feb 07 22:46:54 homelab NetworkManager[3107]: <info>  [1720392414.375164] audit: op="connection-activate" pid=6323 uid=0 result="fail" reason="device class NMDeviceGeneric had no complete_connection method"
```

## Mount USB Drive

You can either connect to a wired network to install `NetworkManager-wifi` or, as I did, install it offline using the full OS image on a USB stick.

First, mount your USB drive:

```sh
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb
```

## Setup Yum Repository File

Create a new repository file:

```sh
vi /etc/yum.repos.d/almalinux9.repo
```

Add the following content:

```ini
[AlmaLinux-USB-BaseOS]
name=BaseOS Packages AlmaLinux 9
baseurl=file:///mnt/usb/BaseOS/
metadata_expire=-1
gpgcheck=0
enabled=1

[AlmaLinux-USB-AppStream]
name=AppStream Packages AlmaLinux 9
baseurl=file:///mnt/usb/AppStream/
metadata_expire=-1
gpgcheck=0
enabled=1
```

## Install NetworkManager-wifi Package from USB Drive

Now, install the package:

```sh
dnf install NetworkManager-wifi --disablerepo=* --enablerepo=AlmaLinux-USB-BaseOS --enablerepo=AlmaLinux-USB-AppStream
systemctl restart NetworkManager
```

## Cleanup

Finally, clean up:

```sh
# Remove repository file
rm /etc/yum.repos.d/almalinux9.repo

# Unmount USB drive
umount /mnt/usb
rm -r /mnt/usb
```

And there you have it! Your AlmaLinux minimal install should now support WiFi connections. Enjoy the freedom of wireless networking!

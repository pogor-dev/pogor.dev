---
author: Victor Pogor
pubDatetime: 2025-02-08T22:42:09.000+10:00
modDatetime:
title: AlmaLinux minimal install does not support WiFi connections
slug: alma-linux-minimal-install-wifi-issue
featured: false
draft: false
tags:
  - rhel
  - almalinux
description: TBA
---

## Table of contents

## Introduction

Recently I decided to use my laptop as a home lab server, given the fact that I don't use it anymore.

The thing is I wanted my laptop to be connected wireless, using a WiFi connection.
I understand it is better to have wired connection for this purpose, however, I wanted portability.

I decided to install [AlmaLinux 9.5](https://almalinux.org/) with [minimal install](https://wiki.almalinux.org/documentation/installation-guide.html#software) as a base environment.
In addition, I enabled [ANSI BP 028 (high)](https://wiki.almalinux.org/documentation/installation-guide.html#installation) security profile.

I could perfectly connect when installed **Server with GUI** base environment, but after installing **Minimal install**, I faced an issue that I couldn't connect to WiFi.
I have tried to follow the guide on [managing wifi connections](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/assembly_managing-wifi-connections_configuring-and-managing-networking), but nothing helped.

I have tried to [activate a connection](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/assembly_managing-wifi-connections_configuring-and-managing-networking#proc_configuring-a-wifi-connection-by-using-nmtui_assembly_managing-wifi-connections) via the `nmtui` command, but I could see only the wired network, not wireles and not a list of available WiFi networks.

Another attempt was to use `nmcli`, and when I wanted to turn on the device (`nmcli dev up wlp0s20f3`), I encountered the following error: `failed to add/activate new connection. Device class NMDeviceGeneric had no complete_connection`.

After some investigation, I found the solution in [this forum](https://access.redhat.com/discussions/6964734).
The thing is that Minimal base environment does not install the package `NetworkManager-wifi` and its dependencies (`wireless-regdb` and `iw`).

One option would be to connect the server to a wired network, install `NetworkManager-wifi`, and activate a WiFi connection.
Another solution (which I choose) is to install this package in offline mode by mounting the full image of the OS, which was installed on an USB stick.

## Mount USB drive

```sh
mkdir -p  /mnt/usb
mount /dev/sda1  /mnt/usb
```

## Setup yum repository file

```sh
vi /etc/yum.repos.d/almalinux9.repo
```

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

## Install NetworkManager-wifi package from USB drive

```sh
dnf install NetworkManager-wifi --disablerepo=* --enablerepo=AlmaLinux-USB-BaseOS --enablerepo=AlmaLinux-USB-AppStream
systemctl restart NetworkManager
```

## Cleanup

### Remove repository file

```sh
rm /etc/yum.repos.d/almalinux9.repo
```

### Unmount USB drive

```sh
umount /mnt/usb
rm -r /mnt/usb
```

## Final thoughts

---
author: Victor Pogor
pubDatetime: 2025-01-12T21:00:47.000+10:00
title: Personal Finance App
slug: "finance-app"
featured: false
draft: false
tags:
  - finance
description: Personal Finance App
---

## Table of contents

## Intro

I'm writing this post with the desire to build my personal finance application.
All this idea started after I used for a long time one Wallet app for Android.
It had bank sync integration which was convinient for me,
but I didn't like that the app collected all my financial and banking data, so I decided to have a personalized app that will help me excelerate my skills in
different areas, trying new technologies.

List:

- configured the docker compose with posgresql + timescaledb
- played with OpenTofu and K8s
- I decided to use my laptop as a linux server (RHEL)
- Fixed the sudo permission: chmod 4755 /usr/bin/sudo

  Before: ---s--x---. 1 root root 185320 Jan 24 2024 /usr/bin/sudo

  After: -rwsr-xr-x. 1 root root 185320 Jan 24 2024 /usr/bin/sudo

- Fixed the X11 permissions
  Failed to start X Wayland: Directory "/tmp/.X11-unix" is not writable
  sudo chmod 1777 /tmp/.X11-unix

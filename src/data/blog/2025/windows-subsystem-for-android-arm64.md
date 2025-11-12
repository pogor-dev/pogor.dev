---
author: Victor Pogor
pubDatetime: 2025-11-11T12:30:00.000+10:00
modDatetime:
title: Trying to fix Windows Subsystem for Android on ARM64 device
description: TBA
slug: windows-subsystem-for-android-arm64
featured: false
draft: false
tags:
  - Windows Subsystem for Android
  - WSA
  - ARM
---

## Table of Contents

> [!WARNING]  
> This blog post contains a lot of commands that need to be run under administrative privileges (e.g. `sudo`).
> The end-user is responsible to check and validate the scripts before running them.

## Intro

One day I decided to install Windows Subsystem for Android on my Surface Pro tablet that has a Qualcomm Snapdragon X1E-80-100 processor. But not long after I discovered that the WSA is [not compatible](https://github.com/MustardChef/WSABuilds/issues/325) with 64bit-only architecture.

This CPU is implementing the [ARMv8.7-A architecture](https://en.wikipedia.org/wiki/ARM_architecture_family) and it supports 64bit applications only.
However, Windows Subsystem for Android is configured to run in 32/64bit mode. It also has 5 binaries compiled in 32bit:

- `/system/system/bin/drmserver`
- `/system/system/bin/mediaserver`
- `/vendor/bin/hw/android.hardware.audio.service`
- `/vendor/bin/hw/android.hardware.cas@1.2-service`
- `/vendor/bin/hw/android.hardware.media.omx@1.0-service`

So the journey started with the idea on recompiling these binaries in 64bit, and replace them in system and vendor partitions.

Before starting, I'd like to mention that this is the first ever experience on working and building Android Open Source project. My knowledge at the moment this post was written is very limited and I'm not fully aware of the entire AOSP architecture and project structure 😊.

## Downloading and install of Windows Subsystem for Android

Even though the Windows Subsystem for Android is not available on Microsoft Store, there is still a way to download it. Please follow [this instruction](https://gist.github.com/HimDek/eb8704e2da1d98240153165743960e17). I personally downloaded the `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_neutral_*.msixbundle` file.

After that, using [7-Zip](https://www.7-zip.org/) tool, I've unarchived the folder and from the extracted folder, I've unarchived the `WsaPackage_2407.40000.4.0_ARM64_Release-*.msix` file. Next, I renamed and moved the folder into a more convenient place:

```powershell
mv "$HOME\Downloads\MicrosoftCorporationII.WindowsSubsystemForAndroid\" "$HOME\WSA\"
```

Now we can register the app package to our user account. If everything will work fine, you should expect Windows Subsystem for Android to be added into your device.

```powershell
 Add-AppxPackage -Path "$HOME\WSA\AppxManifest.xml" -Register -DisableDevelopmentMode
```

### First attempt to start WSA

![WPA Initial run.png](<./2025-10/WPA Initial run.png>)

In system in vendor partitions, we can find multiple `build.props` files.
Let's have a look at some particular properties from one of these files:

```ini
ro.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi

# The subset of ABIs that can run in 32-bit mode.
# Used when a 32-bit process is requested (e.g., app_process32, or zygote32).
ro.product.cpu.abilist32=armeabi-v7a,armeabi

# The subset of ABIs supported for 64-bit mode.
# Used when Android needs to spawn a 64-bit process (app_process64, zygote64).
ro.product.cpu.abilist64=arm64-v8a
```

These define all [CPU ABIs](https://developer.android.com/ndk/guides/abis#sa) (Application Binary Interfaces) that this device supports. Android uses this list to decide which native binaries and libraries it can run.

- **`arm64-v8a`** → 64-bit ARM apps
- **`armeabi-v7a`** → 32-bit ARMv7 apps
- **`armeabi`** → legacy ARMv5 apps (optional)

## Patching the Android Open Source project (AOSP)

> [!IMPORTANT]
> You need a 64-bit x86 system to build AOSP.

Follow the instruction on how to [clone and configure](https://source.android.com/docs/setup/download) the Android Open Source project.

### Selecting the right git branch

If taking a took in any `build.prop` file from original vendor and system partitions, we can notice this record:

```ini
ro.build.display.id=TQ3A.230901.001
```

AOSP has [a page](https://source.android.com/docs/setup/reference/build-numbers#source-code-tags-and-builds) where we can locate what branch do we need. I picked `android-13.0.0_r76`, since it is targeting a tablet device.

```sh
repo init -b android-13.0.0_r76
repo sync
```

### Patching board and device configs

The main changes here is removing 32bit support and disabling APEX compression (`apex` format instead of `capex`), to follow the same approach as WSA.

```diff
diff --git a/build/make/target/board/generic_arm64/BoardConfig.mk b/build/make/target/board/generic_arm64/BoardConfig.mk
index 45ed3daa7cd31823f4524215cc20cd723147881a..c64ca00f1838179b4046d9a164a189988fd2519f 100644
--- a/build/make/target/board/generic_arm64/BoardConfig.mk
+++ b/build/make/target/board/generic_arm64/BoardConfig.mk
@@ -19,39 +19,6 @@ TARGET_ARCH_VARIANT := armv8-a
 TARGET_CPU_VARIANT := generic
 TARGET_CPU_ABI := arm64-v8a

-TARGET_2ND_ARCH := arm
-TARGET_2ND_CPU_ABI := armeabi-v7a
-TARGET_2ND_CPU_ABI2 := armeabi
-
-ifneq ($(TARGET_BUILD_APPS)$(filter cts sdk,$(MAKECMDGOALS)),)
-# DO NOT USE
-# DO NOT USE
-#
-# This architecture / CPU variant must NOT be used for any 64 bit
-# platform builds. It is the lowest common denominator required
-# to build an unbundled application or cts for all supported 32 and 64 bit
-# platforms.
-#
-# If you're building a 64 bit platform (and not an application) the
-# ARM-v8 specification allows you to assume all the features available in an
-# armv7-a-neon CPU. You should set the following as 2nd arch/cpu variant:
-#
-# TARGET_2ND_ARCH_VARIANT := armv8-a
-# TARGET_2ND_CPU_VARIANT := generic
-#
-# DO NOT USE
-# DO NOT USE
-TARGET_2ND_ARCH_VARIANT := armv7-a-neon
-# DO NOT USE
-# DO NOT USE
-TARGET_2ND_CPU_VARIANT := generic
-# DO NOT USE
-# DO NOT USE
-else
-TARGET_2ND_ARCH_VARIANT := armv8-a
-TARGET_2ND_CPU_VARIANT := generic
-endif
-
 include build/make/target/board/BoardConfigGsiCommon.mk

 # Some vendors still haven't cleaned up all device specific directories under
diff --git a/build/make/target/product/aosp_arm64.mk b/build/make/target/product/aosp_arm64.mk
index 01897b77d2af0c7d9e2c542d4cadb89b3647f20d..3b0faf9c4be1d8badafc83cc69c21a1ebb8bf7a7 100644
--- a/build/make/target/product/aosp_arm64.mk
+++ b/build/make/target/product/aosp_arm64.mk
@@ -29,7 +29,7 @@
 #
 # All components inherited here go to system image
 #
-$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
+$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
 $(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

 # Enable mainline checking for excat this product name
@@ -62,6 +62,11 @@ ifeq (aosp_arm64,$(TARGET_PRODUCT))
 $(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)
 endif

+# Enable 64-bit audio HAL
+$(call soong_config_set,android_hardware_audio,run_64bit,true)
+
+# Disable APEX compress
+OVERRIDE_PRODUCT_COMPRESSED_APEX := false

 PRODUCT_NAME := aosp_arm64
 PRODUCT_DEVICE := generic_arm64
```

### Patching OMX and libstagefright into 64bit mode (output_video_encoding_issues)

> [!TIP]
> The changes made were mostly done blindly, due to lack of knowledge on AOSP.
> The main goal was to get rid of 32bit libraries and services.

This build will get at the end the support of AV1, VP8 and VP9 codecs that are often used on YouTube, but video decoding issues on H264 and H265 codecs.

#### Patching AV framework

```diff
diff --git a/frameworks/av/drm/drmserver/Android.bp b/frameworks/av/drm/drmserver/Android.bp
index df3a6a218bb1ed61c1facc7b60f687ecab07707c..945a4c6c1b348ced4b3ba868fef4a9a3e5814252 100644
--- a/frameworks/av/drm/drmserver/Android.bp
+++ b/frameworks/av/drm/drmserver/Android.bp
@@ -59,7 +59,7 @@ cc_binary {
         "-Werror",
     ],

-    compile_multilib: "prefer32",
+    // compile_multilib: "prefer32",

     init_rc: ["drmserver.rc"],
 }
diff --git a/frameworks/av/media/libstagefright/omx/Android.bp b/frameworks/av/media/libstagefright/omx/Android.bp
index 54c5697c14686b9946cca23c494d5b7cd7693369..44bd8a17730f2bfff5d0d0324d582e6c7ceecc1e 100644
--- a/frameworks/av/media/libstagefright/omx/Android.bp
+++ b/frameworks/av/media/libstagefright/omx/Android.bp
@@ -209,7 +209,8 @@ cc_defaults {
         cfi: true,
     },

-    compile_multilib: "32",
+    // compile_multilib: "32",
+    compile_multilib: "64",
 }

 cc_library_shared {
diff --git a/frameworks/av/media/mediaserver/Android.bp b/frameworks/av/media/mediaserver/Android.bp
index edddaa4f9055226a9909b9eaff91fcaefe829a8b..cf969ce71f0259921db23554c2fc2cd1dea6178f 100644
--- a/frameworks/av/media/mediaserver/Android.bp
+++ b/frameworks/av/media/mediaserver/Android.bp
@@ -53,7 +53,7 @@ cc_binary {
     // TO ENABLE 64-BIT MEDIASERVER ON MIXED 32/64-BIT DEVICES, COMMENT
     // OUT THE FOLLOWING LINE:
     // ****************************************************************
-    compile_multilib: "prefer32",
+    // compile_multilib: "prefer32",

     init_rc: ["mediaserver.rc"],

diff --git a/frameworks/av/services/mediacodec/Android.bp b/frameworks/av/services/mediacodec/Android.bp
index 4488efb026e747b2dec031f6478e31f64c2ea74c..57a444af8d7bd2410e408ba142af162fe155e453 100644
--- a/frameworks/av/services/mediacodec/Android.bp
+++ b/frameworks/av/services/mediacodec/Android.bp
@@ -117,8 +117,8 @@ cc_binary {
         "libstagefright_softomx_plugin",
     ],

-    // OMX interfaces force this to stay in 32-bit mode;
-    compile_multilib: "32",
+    // OMX interfaces updated to support 64-bit
+    compile_multilib: "64",

     init_rc: ["android.hardware.media.omx@1.0-service.rc"],

diff --git a/frameworks/av/services/mediacodec/seccomp_policy/mediacodec-arm64.policy b/frameworks/av/services/mediacodec/seccomp_policy/mediacodec-arm64.policy
index b4a9ff6249b4d3f010323d036cb4ad312c52dcfa..ae105cc82a0bb8c0d99db04e16e548c1a0fa0db7 100644
--- a/frameworks/av/services/mediacodec/seccomp_policy/mediacodec-arm64.policy
+++ b/frameworks/av/services/mediacodec/seccomp_policy/mediacodec-arm64.policy
@@ -11,11 +11,10 @@ close: 1
 writev: 1
 dup: 1
 ppoll: 1
-mmap2: 1
+mmap: 1
 getrandom: 1
 memfd_create: 1
 ftruncate: 1
-ftruncate64: 1

 # mremap: Ensure |flags| are (MREMAP_MAYMOVE | MREMAP_FIXED) TODO: Once minijail
 # parser support for '<' is in this needs to be modified to also prevent
@@ -31,9 +30,9 @@ openat: 1
 sigaltstack: 1
 clone: 1
 setpriority: 1
-getuid32: 1
-fstat64: 1
-fstatfs64: 1
+getuid: 1
+fstat: 1
+fstatfs: 1
 pread64: 1
 faccessat: 1
 readlinkat: 1
@@ -48,16 +47,14 @@ gettimeofday: 1
 sched_yield: 1
 nanosleep: 1
 lseek: 1
-_llseek: 1
 sched_get_priority_max: 1
 sched_get_priority_min: 1
-statfs64: 1
 sched_setscheduler: 1
-fstatat64: 1
-ugetrlimit: 1
+newfstatat: 1
+getrlimit: 1
 getdents64: 1
 getrandom: 1

-@include /system/etc/seccomp_policy/crash_dump.arm.policy
+@include /system/etc/seccomp_policy/crash_dump.arm64.policy

-@include /system/etc/seccomp_policy/code_coverage.arm.policy
+@include /system/etc/seccomp_policy/code_coverage.arm64.policy
```

#### Patching CAS interfaces

```diff
diff --git a/hardware/interfaces/cas/1.2/default/Android.bp b/hardware/interfaces/cas/1.2/default/Android.bp
index 38561fd3e7301ac6f2942727908c4ea8401771e8..c7932c84387b8d2fdc57e6be0d3fa9d0ac260794 100644
--- a/hardware/interfaces/cas/1.2/default/Android.bp
+++ b/hardware/interfaces/cas/1.2/default/Android.bp
@@ -21,7 +21,7 @@ cc_defaults {
       "TypeConvert.cpp",
     ],

-    compile_multilib: "prefer32",
+    compile_multilib: "64",

     shared_libs: [
       "android.hardware.cas@1.0",
```

### Removing OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS macro (output_with_removed_64bit_macro)

This version complements the previous one. This build will have the support of H264 and H265 codecs, but no AV1, VP8 and VP9 codecs.

#### Patching AV framework

```diff
diff --git a/frameworks/av/media/codec2/sfplugin/C2OMXNode.cpp b/frameworks/av/media/codec2/sfplugin/C2OMXNode.cpp
index ed7d69c8e9ca5df7e7f6df8f5e067dcaebc340f0..b8db27db365566eddd7febd47700fe6b5dd7b2c3 100644
--- a/frameworks/av/media/codec2/sfplugin/C2OMXNode.cpp
+++ b/frameworks/av/media/codec2/sfplugin/C2OMXNode.cpp
@@ -14,10 +14,6 @@
  * limitations under the License.
  */

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 //#define LOG_NDEBUG 0
 #define LOG_TAG "C2OMXNode"
 #include <log/log.h>
diff --git a/frameworks/av/media/codec2/sfplugin/Omx2IGraphicBufferSource.cpp b/frameworks/av/media/codec2/sfplugin/Omx2IGraphicBufferSource.cpp
index 764fa001ecc149b4ab504d15df11bc5602330d78..e3a9259e90e6b1913ff7ddd7a963e197f5325e6d 100644
--- a/frameworks/av/media/codec2/sfplugin/Omx2IGraphicBufferSource.cpp
+++ b/frameworks/av/media/codec2/sfplugin/Omx2IGraphicBufferSource.cpp
@@ -14,10 +14,6 @@
  * limitations under the License.
  */

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 //#define LOG_NDEBUG 0
 #define LOG_TAG "Omx2IGraphicBufferSource"
 #include <android-base/logging.h>
diff --git a/frameworks/av/media/libstagefright/ACodec.cpp b/frameworks/av/media/libstagefright/ACodec.cpp
index 52c4c0f52335b116d4d20978aba314aa044488b1..265526cb6862c5e34d7377c385ab3de7d2ab2e42 100644
--- a/frameworks/av/media/libstagefright/ACodec.cpp
+++ b/frameworks/av/media/libstagefright/ACodec.cpp
@@ -17,10 +17,6 @@
 //#define LOG_NDEBUG 0
 #define LOG_TAG "ACodec"

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 #include <inttypes.h>
 #include <utils/Trace.h>

@@ -6391,26 +6387,6 @@ void ACodec::BaseState::onInputBufferFilled(const sp<AMessage> &msg) {
                             bufferID, info->mCodecData, flags, timeUs, info->mFenceFd);
                     }
                     break;
-#ifndef OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-                case IOMX::kPortModeDynamicNativeHandle:
-                    if (info->mCodecData->size() >= sizeof(VideoNativeHandleMetadata)) {
-                        VideoNativeHandleMetadata *vnhmd =
-                            (VideoNativeHandleMetadata*)info->mCodecData->base();
-                        sp<NativeHandle> handle = NativeHandle::create(
-                                vnhmd->pHandle, false /* ownsHandle */);
-                        err2 = mCodec->mOMXNode->emptyBuffer(
-                            bufferID, handle, flags, timeUs, info->mFenceFd);
-                    }
-                    break;
-                case IOMX::kPortModeDynamicANWBuffer:
-                    if (info->mCodecData->size() >= sizeof(VideoNativeMetadata)) {
-                        VideoNativeMetadata *vnmd = (VideoNativeMetadata*)info->mCodecData->base();
-                        sp<GraphicBuffer> graphicBuffer = GraphicBuffer::from(vnmd->pBuffer);
-                        err2 = mCodec->mOMXNode->emptyBuffer(
-                            bufferID, graphicBuffer, flags, timeUs, info->mFenceFd);
-                    }
-                    break;
-#endif
                 default:
                     ALOGW("Can't marshall %s data in %zu sized buffers in %zu-bit mode",
                             asString(mCodec->mPortMode[kPortIndexInput]),
@@ -6599,12 +6575,7 @@ bool ACodec::BaseState::onOMXFillBufferDone(
                 native_handle_t *handle = NULL;
                 sp<SecureBuffer> secureBuffer = static_cast<SecureBuffer *>(buffer.get());
                 if (secureBuffer != NULL) {
-#ifdef OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-                    // handle is only valid on 32-bit/mediaserver process
-                    handle = NULL;
-#else
                     handle = (native_handle_t *)secureBuffer->getDestinationPointer();
-#endif
                 }
                 buffer->meta()->setPointer("handle", handle);
                 buffer->meta()->setInt32("rangeOffset", rangeOffset);
diff --git a/frameworks/av/media/libstagefright/OMXClient.cpp b/frameworks/av/media/libstagefright/OMXClient.cpp
index 9375de12664c504c9656647dd64a251a5d63e797..aad5c53d69f81be3ea14f0165533d7d6e4963bcf 100644
--- a/frameworks/av/media/libstagefright/OMXClient.cpp
+++ b/frameworks/av/media/libstagefright/OMXClient.cpp
@@ -17,10 +17,6 @@
 //#define LOG_NDEBUG 0
 #define LOG_TAG "OMXClient"

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 #include <utils/Log.h>
 #include <cutils/properties.h>

diff --git a/frameworks/av/media/libstagefright/OmxInfoBuilder.cpp b/frameworks/av/media/libstagefright/OmxInfoBuilder.cpp
index 79ffdeb8942877476db33e6eca1d1f304e9fa1bb..e455b21818a2cc21f46c8db11453d45c7fcc22e2 100644
--- a/frameworks/av/media/libstagefright/OmxInfoBuilder.cpp
+++ b/frameworks/av/media/libstagefright/OmxInfoBuilder.cpp
@@ -17,10 +17,6 @@
 //#define LOG_NDEBUG 0
 #define LOG_TAG "OmxInfoBuilder"

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 #include <android-base/properties.h>
 #include <utils/Log.h>

diff --git a/frameworks/av/media/libstagefright/omx/1.0/WGraphicBufferSource.cpp b/frameworks/av/media/libstagefright/omx/1.0/WGraphicBufferSource.cpp
index f7bf3ba43be604709f262fd57ba15b20a352daf1..157aa79b2f382cd5c0472c89de2adffce8ab9ef2 100644
--- a/frameworks/av/media/libstagefright/omx/1.0/WGraphicBufferSource.cpp
+++ b/frameworks/av/media/libstagefright/omx/1.0/WGraphicBufferSource.cpp
@@ -14,10 +14,6 @@
  * limitations under the License.
  */

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 //#define LOG_NDEBUG 0
 #define LOG_TAG "TWGraphicBufferSource"

diff --git a/frameworks/av/media/libstagefright/omx/OMXNodeInstance.cpp b/frameworks/av/media/libstagefright/omx/OMXNodeInstance.cpp
index bebd5161d7950cd5841d4ce3d22a9ffdced3d9e0..39dad988d13bb198ccdc01f9a2afe72e11ea89ac 100644
--- a/frameworks/av/media/libstagefright/omx/OMXNodeInstance.cpp
+++ b/frameworks/av/media/libstagefright/omx/OMXNodeInstance.cpp
@@ -49,6 +49,8 @@

 #include <vector>

+// static_assert(sizeof(OMX_PARAM_PORTDEFINITIONTYPE) == 112, "OMX_PARAM_PORTDEFINITIONTYPE should be 112 bytes in OMX project");
+
 static const OMX_U32 kPortIndexInput = 0;
 static const OMX_U32 kPortIndexOutput = 1;

diff --git a/frameworks/av/media/libstagefright/omx/OmxGraphicBufferSource.cpp b/frameworks/av/media/libstagefright/omx/OmxGraphicBufferSource.cpp
index 9484046f797270c1480c7909b727a1509c429874..e1dbb8fcc1440879fa5bfbfd1dda04a8e92626ac 100644
--- a/frameworks/av/media/libstagefright/omx/OmxGraphicBufferSource.cpp
+++ b/frameworks/av/media/libstagefright/omx/OmxGraphicBufferSource.cpp
@@ -14,10 +14,6 @@
  * limitations under the License.
  */

-#ifdef __LP64__
-#define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-#endif
-
 #include <inttypes.h>

 #define LOG_TAG "OmxGraphicBufferSource"
diff --git a/frameworks/av/media/libstagefright/omx/SimpleSoftOMXComponent.cpp b/frameworks/av/media/libstagefright/omx/SimpleSoftOMXComponent.cpp
index 44415aa8c5c466a693491d642d20ae01a3709663..7737faf60a98db67994e2a4e0a87b2264f0447cd 100644
--- a/frameworks/av/media/libstagefright/omx/SimpleSoftOMXComponent.cpp
+++ b/frameworks/av/media/libstagefright/omx/SimpleSoftOMXComponent.cpp
@@ -27,6 +27,8 @@
 #include <media/stagefright/foundation/ALooper.h>
 #include <media/stagefright/foundation/AMessage.h>

+static_assert(sizeof(OMX_PARAM_PORTDEFINITIONTYPE) == 112, "OMX_PARAM_PORTDEFINITIONTYPE should be 112 bytes in OMX project");
+
 namespace android {

 SimpleSoftOMXComponent::SimpleSoftOMXComponent(
@@ -503,7 +505,7 @@ void SimpleSoftOMXComponent::onChangeState(OMX_STATETYPE state) {
     if (mState != mTargetState) {
         ALOGE("State change to state %d requested while still transitioning from state %d to %d",
                 state, mState, mTargetState);
-        notify(OMX_EventError, OMX_ErrorUndefined, 0, NULL);
+        notify(OMX_EventError, OMX_ErrorUndefined, 0, 0);
         return;
     }

@@ -523,7 +525,7 @@ void SimpleSoftOMXComponent::onChangeState(OMX_STATETYPE state) {
             }

             mState = OMX_StateIdle;
-            notify(OMX_EventCmdComplete, OMX_CommandStateSet, state, NULL);
+            notify(OMX_EventCmdComplete, OMX_CommandStateSet, state, 0);
             break;
         }

@@ -549,7 +551,7 @@ void SimpleSoftOMXComponent::onPortEnable(OMX_U32 portIndex, bool enable) {

     if (port->mDef.eDir != OMX_DirOutput) {
         ALOGE("Port enable/disable allowed only on output ports.");
-        notify(OMX_EventError, OMX_ErrorUndefined, 0, NULL);
+        notify(OMX_EventError, OMX_ErrorUndefined, 0, 0);
         android_errorWriteLog(0x534e4554, "29421804");
         return;
     }
@@ -589,7 +591,7 @@ void SimpleSoftOMXComponent::onPortFlush(
         }

         if (sendFlushComplete) {
-            notify(OMX_EventCmdComplete, OMX_CommandFlush, OMX_ALL, NULL);
+            notify(OMX_EventCmdComplete, OMX_CommandFlush, OMX_ALL, 0);
         }

         return;
@@ -633,7 +635,7 @@ void SimpleSoftOMXComponent::onPortFlush(
     port->mQueue.clear();

     if (sendFlushComplete) {
-        notify(OMX_EventCmdComplete, OMX_CommandFlush, portIndex, NULL);
+        notify(OMX_EventCmdComplete, OMX_CommandFlush, portIndex, 0);

         onPortFlushCompleted(portIndex);
     }
@@ -691,7 +693,7 @@ void SimpleSoftOMXComponent::checkTransitions() {
                 onReset();
             }

-            notify(OMX_EventCmdComplete, OMX_CommandStateSet, mState, NULL);
+            notify(OMX_EventCmdComplete, OMX_CommandStateSet, mState, 0);
         } else {
             ALOGV("state transition from %d to %d not yet complete", mState, mTargetState);
         }
@@ -705,7 +707,7 @@ void SimpleSoftOMXComponent::checkTransitions() {
                 ALOGV("Port %zu now disabled.", i);

                 port->mTransition = PortInfo::NONE;
-                notify(OMX_EventCmdComplete, OMX_CommandPortDisable, i, NULL);
+                notify(OMX_EventCmdComplete, OMX_CommandPortDisable, i, 0);

                 onPortEnableCompleted(i, false /* enabled */);
             }
@@ -715,7 +717,7 @@ void SimpleSoftOMXComponent::checkTransitions() {

                 port->mTransition = PortInfo::NONE;
                 port->mDef.bEnabled = OMX_TRUE;
-                notify(OMX_EventCmdComplete, OMX_CommandPortEnable, i, NULL);
+                notify(OMX_EventCmdComplete, OMX_CommandPortEnable, i, 0);

                 onPortEnableCompleted(i, true /* enabled */);
             }
```

#### Patching Native framework

```diff
diff --git a/frameworks/native/headers/media_plugin/media/openmax/OMX_Types.h b/frameworks/native/headers/media_plugin/media/openmax/OMX_Types.h
index 515e002213a31e8616f83850e68a31bb946c2606..a280d396674efbe3563971609d57c7d55d8df3b0 100644
--- a/frameworks/native/headers/media_plugin/media/openmax/OMX_Types.h
+++ b/frameworks/native/headers/media_plugin/media/openmax/OMX_Types.h
@@ -212,24 +212,6 @@ typedef enum OMX_BOOL {
     OMX_BOOL_MAX = 0x7FFFFFFF
 } OMX_BOOL;

-/*
- * Temporary Android 64 bit modification
- *
- * #define OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
- * overrides all OMX pointer types to be uint32_t.
- *
- * After this change, OMX codecs will work in 32 bit only, so 64 bit processes
- * must communicate to a remote 32 bit process for OMX to work.
- */
-
-#ifdef OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS
-
-typedef uint32_t OMX_PTR;
-typedef OMX_PTR OMX_STRING;
-typedef OMX_PTR OMX_BYTE;
-
-#else /* OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS */
-
 /** The OMX_PTR type is intended to be used to pass pointers between the OMX
     applications and the OMX Core and components.  This is a 32 bit pointer and
     is aligned on a 32 bit boundary.
@@ -250,8 +232,6 @@ typedef char* OMX_STRING;
  */
 typedef unsigned char* OMX_BYTE;

-#endif /* OMX_ANDROID_COMPILE_AS_32BIT_ON_64BIT_PLATFORMS */
-
 /** OMX_UUIDTYPE is a very long unique identifier to uniquely identify
     at runtime.  This identifier should be generated by a component in a way
     that guarantees that every instance of the identifier running on the system
```

### Build the patched AOSP

```powershell
source build/envsetup.sh
lunch aosp_arm64-user

m -j16 \
    mediaserver \
    drmserver \
    android.hardware.audio.service \
    android.hardware.cas@1.2-service \
    android.hardware.media.omx@1.0-service \
    libstagefright \
    libstagefright_omx \
    com.android.media \
    com.android.media.swcodec \
    audioserver \
    cameraserver \
    mediaextractor \
    mediametrics \
    libstagefright_foundation \
    libmedia \
    libmediandk \
    libcodec2 \
    libcodec2_client \
    libavservices_minijail
```

I got some issues with symlinks while transferring the build from x64 to ARM device, so I decided to remove them as they stay the same compared with original WSA. In addition, I've removed the `system_external` folder from system partition. In original image, this folder is a symlink. Perhaps I could migrate this data in `system_external` image but for some reason I didn't do it 😁.

```sh
rm out/target/product/generic_arm64/system/lib64/libc.so \
    out/target/product/generic_arm64/system/lib64/libm.so \
    out/target/product/generic_arm64/system/lib64/libdl.so \
    out/target/product/generic_arm64/system/lib64/libdl_android.so

rm -r out/target/product/generic_arm64/system/system_ext
```

### Copy the artifacts to a destination folder

```powershell
mkdir "$HOME/OneDrive/Docs/IT/WSA/output_with_removed_64bit_macro_and_extra_targets"

cp -r out/target/product/generic_arm64/system "$HOME/OneDrive/Docs/IT/WSA/output_with_removed_64bit_macro_and_extra_targets"

cp -r out/target/product/generic_arm64/vendor "$HOME/OneDrive/Docs/IT/WSA/output_with_removed_64bit_macro_and_extra_targets"
```

## Patching the system and vendor partitions

### Variables

```sh
AOSP_PATH=/mnt/c/Users/victo/OneDrive/Docs/IT/WSA/output_with_removed_64bit_macro
WSA_PATH=/mnt/c/Users/victo/WSA

SYS_MNT="$HOME/system"
VND_MNT="$HOME/vendor"
```

### Mount the system and vendor images

```sh
cd $HOME
mkdir -p "$SYS_MNT"
mkdir -p "$VND_MNT"
```

Convert the `vhdx` files to `img`, so they can be mounted:

```sh
qemu-img convert -p -S 4k -O raw "$WSA_PATH/vendor.vhdx" "$HOME/vendor.img"
qemu-img convert -p -S 4k -O raw "$WSA_PATH/system.vhdx" "$HOME/system.img"
```

When mounting the first time, an error could occur:

```sh
sudo mount -o loop "$HOME/vendor.img" "$VND_MNT"
```

```
mount: $HOME/vendor: wrong fs type, bad option, bad superblock on /dev/loop2, missing codepage or helper program, or other error.
       dmesg(1) may have more information after failed mount system call.
```

That error usually means your `vendor.img` is **not a bare ext4 filesystem** but a **disk image with a partition table** inside. In that case, mounting the whole file with `-o loop` won’t work.

That means the image has **shared (reflinked/deduped) blocks** (e.g., created on a CoW FS like btrfs/APFS, or copied with reflinks). Many kernels **refuse to mount** an ext\* filesystem while the `shared_blocks` flag is set.

This can be fixed by running this command:

```sh
expand_ext_image() {
  local FILE="$1"
  local INC="$2"

  if [[ -z "$FILE" || -z "$INC" ]]; then
    echo "Usage: expand_ext_image <file> <increase>"
    echo "Example: expand_ext_image ~/vendor.img +50M"
    return 1
  fi
  [[ -f "$FILE" ]] || { echo "Error: File not found: $FILE"; return 1; }

  echo "→ Expanding $FILE by $INC..."
  truncate -s "$INC" "$FILE" || { echo "❌ truncate failed"; return 1; }

  echo "→ Running initial filesystem check..."
  sudo e2fsck -pf "$FILE" >/dev/null || { echo "❌ fsck failed"; return 1; }

  echo "→ Checking for shared blocks..."
  if sudo dumpe2fs -h "$FILE" 2>/dev/null | grep -q 'shared_blocks'; then
    echo "⚠️  Shared blocks detected — unsharing non-interactively..."
    # -f force, -y auto-yes, -E unshare_blocks to clear the flag safely
    sudo e2fsck -fy -E unshare_blocks "$FILE" >/dev/null || { echo "❌ unshare_blocks failed"; return 1; }
    # follow with a clean pass
    sudo e2fsck -pf "$FILE" >/dev/null || { echo "❌ post-unshare fsck failed"; return 1; }
    echo "✅ Shared blocks cleared."
  fi

  echo "→ Resizing filesystem..."
  sudo resize2fs -f "$FILE" >/dev/null || { echo "❌ resize2fs failed"; return 1; }

  echo "→ Final integrity check..."
  sudo e2fsck -pf "$FILE" >/dev/null || { echo "❌ final fsck failed"; return 1; }

  echo "✅ Done: $FILE expanded by $INC and verified."
}

expand_ext_image "$HOME/system.img" +400M
expand_ext_image "$HOME/vendor.img" +400M
```

```
# sudo e2fsck -fy vendor.img

e2fsck 1.47.0 (5-Feb-2023)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
vendor: 565/576 files (2.1% non-contiguous), 15157/15204 blocks

# sudo e2fsck -fy system.img
e2fsck 1.47.0 (5-Feb-2023)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 3A: Optimizing directories
Pass 4: Checking reference counts
Pass 5: Checking group summary information

/: ***** FILE SYSTEM WAS MODIFIED *****
/: 2794/2800 files (11.0% non-contiguous), 211124/227525 blocks
```

After fixing this, we should be able to mount the images:

```sh
sudo mount -o loop "$HOME/system.img" "$SYS_MNT"
sudo mount -o loop "$HOME/vendor.img" "$VND_MNT"
```

### Patching the system and vendor images

Now we can do the required update to have 64bit-only support:

```sh
# edit_prop FILE PROPERTY [VALUE]
edit_prop() {
  local file="$1" prop="$2" value="${3-__NULL__}"

  # --- basic guards ---
  [[ -n "$file" && -n "$prop" ]] || { echo "usage: edit_prop FILE PROP [VALUE]"; return 2; }
  if ! sudo test -f "$file"; then
    echo "ERROR: file not found: $file"
    return 2
  fi

  local rx="^[[:space:]]*#?[[:space:]]*${prop//./\\.}[[:space:]]*=.*$"

  # --- remove prop (no value passed) ---
  if [[ "$value" == "__NULL__" ]]; then
    if sudo grep -Eq "$rx" "$file"; then
      sudo sed -i -E "/$rx/d" "$file" || return 1
      echo "Removed: $prop"
      return 0
    else
      echo "Not found: $prop"
      return 1
    fi
  fi

  # --- keep prop (empty string) ---
  if [[ -z "$value" ]]; then
    echo "Kept existing value for $prop"
    return 0
  fi

  # --- set/replace prop ---
  if sudo grep -Eq "$rx" "$file"; then
    sudo sed -i -E "s|$rx|$prop=$value|" "$file" || return 1
    echo "Updated: $prop=$value"
    return 0
  fi

  # not present → append once (use tee so it writes as root)
  printf '%s=%s\n' "$prop" "$value" | sudo tee -a "$file" >/dev/null || return 1
  echo "Added: $prop=$value"
}

FILE="$SYS_MNT/system/build.prop"
edit_prop "$FILE" "ro.system.product.cpu.abilist" "arm64-v8a"
edit_prop "$FILE" "ro.system.product.cpu.abilist32"
edit_prop "$FILE" "ro.system.product.cpu.abilist64" "arm64-v8a"

FILE="$VND_MNT/build.prop"
edit_prop "$FILE" "ro.vendor.product.cpu.abilist" "arm64-v8a"
edit_prop "$FILE" "ro.vendor.product.cpu.abilist32"
edit_prop "$FILE" "ro.vendor.product.cpu.abilist64" "arm64-v8a"
edit_prop "$FILE" "ro.zygote" "zygote64"

FILE="$VND_MNT/odm/etc/build.prop"
edit_prop "$FILE" "ro.odm.product.cpu.abilist" "arm64-v8a"
edit_prop "$FILE" "ro.odm.product.cpu.abilist32"
edit_prop "$FILE" "ro.odm.product.cpu.abilist64" "arm64-v8a"

# Restore SELinux labels after edit
sudo chcon 'u:object_r:system_file:s0'          "$SYS_MNT/system/build.prop"
sudo chcon 'u:object_r:vendor_file:s0'          "$VND_MNT/build.prop"
sudo chcon 'u:object_r:vendor_configs_file:s0'  "$VND_MNT/odm/etc/build.prop"
```

```
Updated: ro.system.product.cpu.abilist=arm64-v8a
Removed: ro.system.product.cpu.abilist32
Updated: ro.system.product.cpu.abilist64=arm64-v8a
Updated: ro.vendor.product.cpu.abilist=arm64-v8a
Removed: ro.vendor.product.cpu.abilist32
Updated: ro.vendor.product.cpu.abilist64=arm64-v8a
Updated: ro.zygote=zygote64
Updated: ro.odm.product.cpu.abilist=arm64-v8a
Removed: ro.odm.product.cpu.abilist32
Updated: ro.odm.product.cpu.abilist64=arm64-v8a
```

Next, copy the patched 64bit binaries:

```sh
check_elf_arch() {
  local file="$1"
  [[ -n "$file" ]] || { echo "usage: check_elf_arch FILE"; return 2; }

  local desc
  desc=$(sudo file "$file" 2>/dev/null)

  if grep -q "ARM aarch64" <<<"$desc"; then
    echo "✅ $file is ARM64 (aarch64)"
    return 0
  else
    echo "❌ $file is NOT ARM64"
    echo "→ Detected: $desc"
    return 1   # non-zero ⇒ causes script to stop if 'set -e' is active
  fi
}

# set_meta FILE MODE [SELINUX_LABEL]
# - user/group is hardcoded to root:root
# - pass "-" (or leave empty) to skip SELinux label
set_meta() {
  local f="$1" mode="$2" label="${3-}"
  [[ -n "$f" && -n "$mode" ]] || { echo "usage: set_meta FILE MODE [SELINUX_LABEL]"; return 2; }
  sudo chown root:root "$f" || return
  sudo chmod "$mode" "$f" || return
  [[ -n "$label" && "$label" != "-" ]] && sudo chcon "$label" "$f"
}

SRC_SYS="$AOSP_PATH/system/"
SRC_VND="$AOSP_PATH/vendor/"

# Remove system_ext folder from source
rm -r "$SRC_SYS/system_ext/" 2>/dev/null

# Update ONLY files that already exist at DST, in-place
# Keeps destination owner/group/perm/SELinux labels exactly as-is
sudo rsync -a --inplace \
  --no-owner --no-group --no-perms --no-times --no-acls --no-xattrs \
  "$SRC_SYS/" "$SYS_MNT/system/"

sudo rsync -a --inplace \
  --no-owner --no-group --no-perms --no-times --no-acls --no-xattrs \
  "$SRC_VND/" "$VND_MNT/"

check_elf_arch "$SYS_MNT/system/bin/drmserver"
check_elf_arch "$SYS_MNT/system/bin/mediaserver"
check_elf_arch "$VND_MNT/bin/hw/android.hardware.audio.service"
check_elf_arch "$VND_MNT/bin/hw/android.hardware.cas@1.2-service"
check_elf_arch "$VND_MNT/bin/hw/android.hardware.media.omx@1.0-service"

# system libs
set_meta "$SYS_MNT/system/lib64/libmediaplayerservice.so" 0644 'u:object_r:system_lib_file:s0'
set_meta "$SYS_MNT/system/lib64/libresourcemanagerservice.so" 0644 'u:object_r:system_lib_file:s0'
set_meta "$SYS_MNT/system/lib64/libstagefright_httplive.so" 0644 'u:object_r:system_lib_file:s0'

# system libs (system label)
for f in \
  "$SYS_MNT/system/lib64/libcodec2_soft_g711alawdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_h263dec.so" \
  "$SYS_MNT/system/lib64/libstagefright_bufferqueue_helper_novndk.so" \
  "$SYS_MNT/system/lib64/libcodec2_hidl@1.0.so" \
  "$SYS_MNT/system/lib64/libcodec2_hidl@1.1.so" \
  "$SYS_MNT/system/lib64/libcodec2_hidl@1.2.so" \
  "$SYS_MNT/system/lib64/libcodec2_hidl_plugin_stub.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_aacdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_aacenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_amrnbdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_amrnbenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_amrwbdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_amrwbenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_av1dec_gav1.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_avcdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_avcenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_common.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_flacdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_flacenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_g711mlawdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_gsmdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_h263enc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_hevcdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_hevcenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_mp3dec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_mpeg2dec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_mpeg4dec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_mpeg4enc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_opusdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_opusenc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_rawdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_vorbisdec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_vp8dec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_vp8enc.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_vp9dec.so" \
  "$SYS_MNT/system/lib64/libcodec2_soft_vp9enc.so" \
  "$SYS_MNT/system/lib64/libmedia_codecserviceregistrant.so" \
  "$SYS_MNT/system/lib64/libopus.so" \
  "$SYS_MNT/system/lib64/libstagefright_enc_common.so" \
  "$SYS_MNT/system/lib64/libstagefright_flacdec.so" \
  "$SYS_MNT/system/lib64/libstagefright_omx.so" \
  "$SYS_MNT/system/lib64/libstagefright_omx_utils.so" \
  "$SYS_MNT/system/lib64/libvpx.so"
do
  set_meta "$f" 0644 'u:object_r:system_lib_file:s0'
done

# vendor libs (vendor label)
for f in \
  "$VND_MNT/lib64/android.hardware.cas.native@1.0.so" \
  "$VND_MNT/lib64/android.hardware.cas@1.0.so" \
  "$VND_MNT/lib64/android.hardware.cas@1.1.so" \
  "$VND_MNT/lib64/android.hardware.cas@1.2.so" \
  "$VND_MNT/lib64/libavservices_minijail.so" \
  "$VND_MNT/lib64/libopus.so" \
  "$VND_MNT/lib64/libstagefright_amrnb_common.so" \
  "$VND_MNT/lib64/libstagefright_enc_common.so" \
  "$VND_MNT/lib64/libstagefright_flacdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_aacdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_aacenc.so" \
  "$VND_MNT/lib64/libstagefright_soft_amrdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_amrnbenc.so" \
  "$VND_MNT/lib64/libstagefright_soft_amrwbenc.so" \
  "$VND_MNT/lib64/libstagefright_soft_avcdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_avcenc.so" \
  "$VND_MNT/lib64/libstagefright_soft_flacdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_flacenc.so" \
  "$VND_MNT/lib64/libstagefright_soft_g711dec.so" \
  "$VND_MNT/lib64/libstagefright_soft_gsmdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_hevcdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_mp3dec.so" \
  "$VND_MNT/lib64/libstagefright_soft_mpeg2dec.so" \
  "$VND_MNT/lib64/libstagefright_soft_mpeg4dec.so" \
  "$VND_MNT/lib64/libstagefright_soft_mpeg4enc.so" \
  "$VND_MNT/lib64/libstagefright_soft_opusdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_rawdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_vorbisdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_vpxdec.so" \
  "$VND_MNT/lib64/libstagefright_soft_vpxenc.so" \
  "$VND_MNT/lib64/libstagefright_softomx.so" \
  "$VND_MNT/lib64/libstagefright_softomx_plugin.so" \
  "$VND_MNT/lib64/libvorbisidec.so" \
  "$VND_MNT/lib64/libvpx.so"
do
  set_meta "$f" 0644 'u:object_r:vendor_file:s0'
done
```

Check if there is any un-labeled files, it is expected to return an empty output:

```sh
sudo find $SYS_MNT $VND_MNT -exec ls -dZ {} + 2>/dev/null | awk '$1 ~ /\?/ {print $NF}'
sudo find $SYS_MNT $VND_MNT -user "$USER" -exec ls -dZ {} + 2>/dev/null | awk '$1 ~ /\?/ {print $NF}'
```

### Un-mount the images and copy them back

```sh
sudo sync && sudo umount "$SYS_MNT"
sudo sync && sudo umount "$VND_MNT"

qemu-img convert -p -O vhdx -o subformat=dynamic "$HOME/system.img" "$WSA_PATH/system.vhdx"
qemu-img convert -p -O vhdx -o subformat=dynamic "$HOME/vendor.img" "$WSA_PATH/vendor.vhdx"
```

## Issues observed

### Video rendering

For testing the video/audio decoding, I've used [an online MIME type tester](https://tools.woolyss.com/html5-audio-video-tester/). I've tried two builds (`output_video_encoding_issues` and `output_with_removed_64bit_macro`), and both work unstable.

In case of `output_video_encoding_issues`, I have support of AV1, VP8 and VP9 codecs that are often used on YouTube, but H264 and H265 codecs are not working. Almost the opposite thing happens when using `output_with_removed_64bit_macro`.

| filename                       | video                            | audio            | source             | format | baseline_pc                                                                                                                | output_video_encoding_issues                                                                                                   | output_with_removed_64bit_macro                                                                                                                   |
| ------------------------------ | -------------------------------- | ---------------- | ------------------ | ------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| av1-opus-sita.webm             | AV1 Main@L3.1                    | Opus             | wikipedia.org      | webm   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                  | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| av1-nosound-chimera.mp4        | AV1 Main@L2.0                    | (no sound)       | netflix.com        | mp4    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video partially working, huge UI freeze</span> | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video partially working, huge UI freeze</span>                    |
| vp9-vorbis-spring.webm         | VP9                              | Vorbis           | wikipedia.org      | webm   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                  | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| vp8-vorbis-sintel.webm         | VP8                              | Vorbis           | wikipedia.org      | webm   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                  | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| theora-vorbis-caminandes-2.ogv | Theora                           | Vorbis           | wikipedia.org      | ogv    | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video not loading, audio is working</span> | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video not loading, audio is working</span>     | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video not loading, audio is working</span>                        |
| vvc-nosound-novosobornaya.mp4  | H.266/VVC                        | (no sound)       | elecard.com        | mp4    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>             | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| hevc-aac-caminandes-2.mp4      | H.265/HEVC Main@L4               | AAC lc           | wikipedia.org      | mp4    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                                     |
| hevc-aac-caminandes-3.mp4      | H.265/HEVC Main@L3.1             | AAC lc           | wikipedia.org      | mp4    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video is working last seconds of video<br>audio is working</span> |
| avc-aac-nerdist-friends.mp4    | H.264/AVC Baseline@L2.1          | AAC lc           | dailymail.co.uk    | mp4    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                                     |
| avc-aac-big-buck-bunny.m4v     | H.264/AVC Baseline@L3.0          | AAC lc           | wikipedia.org      | m4v    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>                                     |
| avc-mp3-sita.mov               | H.264/AVC High@L3.1              | MP3              | wikipedia.org      | mov    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video/audio is working</span>              | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| h263-amr-small.3gp             | H.263 BaseLine@1.0               | AMR              | techslides.com     | 3gp    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>             | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| mpeg4-mp3-sita.avi             | MPEG-4 Visual Advanced Simple@L4 | MP3              | wikipedia.org      | avi    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>             | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| esign_2_high.qt                | MPEG-4 Visual Advanced Simple@L3 | AAC              | blender.org        | qt     | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">no video<br>audio is working</span>        | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                 | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video/audio not working</span>                                    |
| audio-sample.amr               |                                  | AMR              | techslides.com     | amr    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                   | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                       | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                                          |
| audio-sample.mp3               |                                  | MP3              | dogphilosophy.net  | mp3    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.weba              |                                  | Vorbis           | dogphilosophy.net  | weba   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.ogg               |                                  | Vorbis           | dogphilosophy.net  | ogg    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.opus              |                                  | Opus             | dogphilosophy.net  | opus   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.flac              |                                  | Flac             | dogphilosophy.net  | flac   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.wav               |                                  | Wave             | dogphilosophy.net  | wav    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| audio-sample.m4a               |                                  | AAC lc           | jplayer.org        | m4a    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                       | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| ac192.mp3                      |                                  | MP3 (streaming)  | airconnectradio.eu | mp3    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| jazz-wr06-128.mp3              |                                  | MP3 (streaming)  | jazzradio.fr       | mp3    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| spoonradio-hd.aac              |                                  | AAC (streaming)  | spoonradio.com     | aac    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                       | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">audio not working</span>                                          |
| audio.opus                     |                                  | Opus (streaming) | euer-radio.de      | opus   | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                    | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">audio is working</span>                                           |
| f1Y1xzl.gifv                   |                                  | (no sound)       | imgur.com          |        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video is working</span>                    | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video not working</span>                       | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video partially working, huge UI freeze</span>                    |
| 7wPZQ57.gifv                   |                                  | (no sound)       | imgur.com          |        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">video is working</span>                    | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">video partially working, huge UI freeze</span> | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">video not working</span>                                          |
| **Total**                      |                                  |                  |                    |        | <span style="background:#00aa00;color:white;padding:2px 6px;border-radius:4px;">22/28</span>                               | <span style="background:#cc0000;color:white;padding:2px 6px;border-radius:4px;">12/28</span>                                   | <span style="background:#ffcc00;color:black;padding:2px 6px;border-radius:4px;">13/28</span>                                                      |

### VIRTGPU

```
I servicemanager: Could not find android.hardware.graphics.allocator.IAllocator/default in the VINTF manifest.
E platform: virtgpu backend not enabling VIRTGPU_PARAM_CREATE_GUEST_HANDLE
E platform: DRM_IOCTL_VIRTGPU_CONTEXT_INIT failed with Invalid argument, continuing without context...

E OpenGLRenderer: Failed to initialize 101010-2 format, error = EGL_SUCCESS
E OpenGLRenderer: Unable to match the desired swap behavior.
```

### Camera recording fail

```sh
# COLOR_FormatSurface (0x7f000789)
W OMXUtils: do not know color format 0x7f000789 = 2130708361
E SimpleLatteOMXComponent: b/27207275: need 112, got 96
E OMXNodeInstance: getParameter(0x6f114b5850:android.latte.hevc.decoder, ParamPortDefinition(0x2000001)) ERROR: BadParameter(0x80001005)
E [OMX.android.latte.hevc.decoder] configureCodec returning error -22
E ACodec  : signalError(omxError 0x80001001, internalError -22)
E MediaCodec: Codec reported err 0xffffffea/BAD_VALUE, actionCode 0, while in state 3/CONFIGURING
E MediaCodec: configure failed with err 0xffffffea, resetting...
E StagefrightRecorder: Failed to create video encoder
E Camera2ClientBase: stopRecording: attempt to use a locked camera from a different process (old pid 189, new pid 1355)
E MediaRecorder: start failed: -2147483648
```

> The Surface must be rendered with a hardware-accelerated API, such as OpenGL ES. [`Surface.lockCanvas(android.graphics.Rect`)](<https://developer.android.com/reference/android/view/Surface#lockCanvas(android.graphics.Rect)>) may fail or produce unexpected results.
> Source: [MediaCodec  |  API reference  |  Android Developers](<https://developer.android.com/reference/android/media/MediaCodec#createInputSurface()>)

### Hardware-accelerated video

[WSA 2307 Update! · microsoft/WSA · Discussion #374](https://github.com/microsoft/WSA/discussions/374?utm_source=chatgpt.com)
[New Vulkan feature didn‘t work on the Windows Arm64 Devices · Issue #375· microsoft/WSA](https://github.com/microsoft/WSA/issues/375)

![WSA Settings no Vulkan drivers.png](<./2025-10/WSA Settings no Vulkan drivers.png>)

### DRM support

Hardware DRM (L1 security level) support [was not implemented](https://github.com/microsoft/WSA?tab=readme-ov-file#roadmap) on Windows Subsystem For Android. There is only L3 security level support, which means that streaming services like Netflix will not be able to play Full HD or 4K content.

## Useful tools

This is the list used for troubleshooting and analysis:

- [Windows Performance Analyser (Preview)](https://apps.microsoft.com/detail/9n58qrw40dfw?hl=en-US&gl=US) (rich UI, slower filtering, truncated text)
- [PerfView](https://github.com/microsoft/perfview) (simple UI, faster filtering)
- [Microsoft-Performance-Tools-Linux-Android](https://github.com/microsoft/Microsoft-Performance-Tools-Linux-Android) (adds support of logcat)
- [logcat++](https://marketplace.visualstudio.com/items?itemName=JeyMichaelraj.logcatplusplus) (VS Code extension for logcat format)
- [WinMerge](https://winmerge.org/) (it was useful for comparing the [patches](https://github.com/snickler/WSA-Patched/releases) that [Jeremy Sinclair](https://github.com/snickler) made)

## FAQ

### How do I enable logs and tracing?

Open **Windows Subsystem for Android**, navigate to **System** section, expand **Optional diagnostic data** and press **Enable viewing** (1).

Once you start Android (e.g. by pressing on **Files** item), it will start collect logs and traces (2).

![WSA Enable tracing.png](<./2025-10/WSA Enable tracing.png>)

### How do I find what services exited with an error in traces?

You can use this regular expression: `exited with status [1-9][0-9]*`

![WPA Regex search.png](<./2025-10/WPA Regex search.png>)
![WPA Processes with failed exit status.png](<./2025-10/WPA Processes with failed exit status.png>)

### How do I find Access Vector Cache (AVC) errors in traces?

Perform a search by `avc:  denied` keywords (note a double space):
![WPA avc denied.png](<./2025-10/WPA avc denied.png>)

Another way is to find by `unlabeled` keyword:
![WPA avc unlabeled.png](<./2025-10/WPA avc unlabeled.png>)

```
[   13.119188] audit: type=1400 audit(1761406139.108:15): avc:  denied  { read } for  pid=615 comm="android.hardwar" name="android.hardware.cas@1.0.so" dev="sdb" ino=540 scontext=u:r:hal_cas_default:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0
```

Explanation: The **CAS HAL service** (which handles media decryption and DRM) tried to **read its library file** `android.hardware.cas@1.0.so`, but SELinux blocked it because that file is marked **“unlabeled”** - meaning it has no valid security label.

The kernel blocked the read operation. This does not normally break boot, but it indicates that the suspend service tried to inspect a hardware wakeup source that’s not whitelisted in its SELinux policy.

Some more traces given as an example:

| Line # | text (Field 1)                                                                                                                                                                                                                                                      | Time (s)     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ |
| 9      | [    8.114355] audit: type=1400 audit(1761406134.104:12): avc:  denied  { read } for  pid=608 comm="android.hardwar" name="android.hardware.cas@1.0.so" dev="sdb" ino=540 scontext=u:r:hal_cas_default:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0 | 9.065322900  |
| 10     | [    8.292456] audit: type=1400 audit(1761406134.284:13): avc:  denied  { read } for  pid=612 comm="android.hardwar" name="libavservices_minijail.so" dev="sdb" ino=567 scontext=u:r:mediacodec:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0        | 9.246540300  |
| 11     | [    8.300071] audit: type=1400 audit(1761406134.288:14): avc:  denied  { read } for  pid=611 comm="mediaserver" name="libmediaplayerservice.so" dev="sda" ino=2796 scontext=u:r:mediaserver:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0           | 9.249285300  |
| 12     | [   13.119188] audit: type=1400 audit(1761406139.108:15): avc:  denied  { read } for  pid=615 comm="android.hardwar" name="android.hardware.cas@1.0.so" dev="sdb" ino=540 scontext=u:r:hal_cas_default:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0 | 14.070617100 |
| 13     | [   13.291624] audit: type=1400 audit(1761406139.280:16): avc:  denied  { read } for  pid=618 comm="mediaserver" name="libmediaplayerservice.so" dev="sda" ino=2796 scontext=u:r:mediaserver:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0           | 14.243729000 |
| 14     | [   13.297205] audit: type=1400 audit(1761406139.284:17): avc:  denied  { read } for  pid=619 comm="android.hardwar" name="libavservices_minijail.so" dev="sdb" ino=567 scontext=u:r:mediacodec:s0 tcontext=u:object_r:unlabeled:s0 tclass=file permissive=0        | 14.245680900 |

### Exec format error

Attempting to run an executable compiled for a different CPU architecture (e.g., a 32bit ARM service on 64bit-only CPU), will lead to this error:

```
[    1.920187] init: cannot execv('/system/bin/drmserver'). See the 'Debugging init' section of init's README.md for tips: Exec format error
```

### init: Service with 'reboot_on_failure' option failed, shutting down system

```
[    1.922422] init: Service with 'reboot_on_failure' option failed, shutting down system.
```

> If this process cannot be started or if the process terminates with an exit code other than CLD*EXITED or an status other than ‘0’, reboot the system with the target specified in _target*. *target* takes the same format as the parameter to sys.powerctl. This is particularly intended to be used with the `exec_start` builtin for any must-have checks during boot.
> Source: [init/README.md](https://android.googlesource.com/platform/system/core/+/android16-release/init/README.md)

We can do a search in `system.vhdx` and `vendor.vhdx` images for `reboot_on_failure` keyword. This should help troubleshooting on what potential service could trigger this reboot:

| System partition                                                                                              | Vendor partition                                                                                              |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| ![VS Code search on reboot_on_failure_system.png](<./2025-10/VS Code search on reboot_on_failure_system.png>) | ![VS Code search on reboot_on_failure_vendor.png](<./2025-10/VS Code search on reboot_on_failure_vendor.png>) |

In case the `reboot_on_failure` option has a reboot (e.g. `boringssl-self-check-failed`), it will be shown on traces:

![WPA boringssl-self-check-failed.png](<./2025-10/WPA boringssl-self-check-failed.png>)

Some services with this option does not provide a reboot reason, and in this case you could add it by yourself.

### Cannot link executable error

This error can be found in the `logcat` folder:

```
CANNOT LINK EXECUTABLE "/system/bin/mediaserver": library "libmediaplayerservice.so" not found: needed by main executable
```

![Logcat CANNOT LINK EXECUTABLE mediaserver, library libmediaplayerservice.so not found.png](<./2025-10/Logcat CANNOT LINK EXECUTABLE mediaserver, library libmediaplayerservice.so not found.png>)

#### The library is missing in `lib64` folder.

Please check the appropriate partition (look at the binary path to infer the partition) if this file is present.

```sh
# required by /system/bin/mediaserver
sudo ls -lZ "$HOME/system/system/lib64/libmediaplayerservice.so"

# required by /vendor/bin/hw/android.hardware.cas@1.2-service
sudo ls -lZ "$HOME/vendor/lib64/android.hardware.cas@1.0.so"

# required by /vendor/bin/hw/android.hardware.media.omx@1.0-service
sudo ls -lZ "$HOME/vendor/lib64/libavservices_minijail.so"
```

This will confirm if the files are missing:

```
ls: cannot access '/home/<user>/system/system/lib64/libmediaplayerservice.so': No such file or directory
ls: cannot access '/home/<user>/vendor/lib64/android.hardware.cas@1.0.so': No such file or directory
ls: cannot access '/home/<user>/vendor/lib64/libavservices_minijail.so': No such file or directory
```

As a solution, we could take the missing libraries from the compiled AOSP or other WSA builds.

```sh
USER_NAME=victo
AOSP_PATH="/mnt/c/Users/$USER_NAME/OneDrive/Docs/IT/WSA/output"

sudo cp "$AOSP_PATH/system/lib64/libmediaplayerservice.so" "$HOME/system/system/lib64/"
sudo cp "$AOSP_PATH/vendor/lib64/android.hardware.cas@1.2.so" "$HOME/vendor/lib64/"
sudo cp "$AOSP_PATH/vendor/lib64/android.hardware.cas@1.1.so" "$HOME/vendor/lib64/"
sudo cp "$AOSP_PATH/vendor/lib64/android.hardware.cas@1.0.so" "$HOME/vendor/lib64/"
sudo cp "$AOSP_PATH/vendor/lib64/android.hardware.cas.native@1.0.so" "$HOME/vendor/lib64/"
sudo cp "$AOSP_PATH/vendor/lib64/libavservices_minijail.so" "$HOME/vendor/lib64/"
```

#### The SELinux policy is not correctly assigned and the kernel blocks reading this library

```sh
# required by /system/bin/mediaserver
sudo ls -lZ "$HOME/system/system/lib64/libmediaplayerservice.so"

# required by /vendor/bin/hw/android.hardware.cas@1.2-service
sudo ls -lZ "$HOME/vendor/lib64/android.hardware.cas@1.2.so"
sudo ls -lZ "$HOME/vendor/lib64/android.hardware.cas@1.1.so"
sudo ls -lZ "$HOME/vendor/lib64/android.hardware.cas@1.0.so"
sudo ls -lZ "$HOME/vendor/lib64/android.hardware.cas.native@1.0.so"

# required by /vendor/bin/hw/android.hardware.media.omx@1.0-service
sudo ls -lZ "$HOME/vendor/lib64/libavservices_minijail.so"
```

The question mark means "I don’t know the [SELinux label](https://source.android.com/docs/core/architecture/vndk/dir-rules-sepolicy) for this file". Either it’s missing, unreadable, or the filesystem doesn’t have one.

```
-rwxr-xr-x 1 root root ? 1507136 Oct 26 11:09 /home/<user>/system/system/lib64/libmediaplayerservice.so
-rwxr-xr-x 1 root root ? 288912 Oct 26 11:09 /home/<user>/vendor/lib64/android.hardware.cas@1.0.so
-rwxr-xr-x 1 root root ? 134432 Oct 26 11:09 /home/<user>/vendor/lib64/libavservices_minijail.so
```

We can fix the attributes by running the commands mentioned below. We also need to add in SELinux file contexts from vendor partition the [`u:object_r:same_process_hal_file:s0`](https://source.android.com/docs/core/architecture/vndk/dir-rules-sepolicy#sphal) labels.

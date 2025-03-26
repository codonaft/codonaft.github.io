---
layout: post
title: "Installing <span class='no-wrap'>Alpine Linux</span> from another preinstalled <span class='no-wrap'>GNU/Linux distro</span>"
feature-img: "assets/img/alpine-install-vps.svg"
thumbnail: "assets/img/alpine-install-vps-thumbnail.svg"
date: "2024-09-26 00:00:00 +0000"
tags: [vps, alpine, linux, iso, boot, grub]
nostr:
  comments: note1q99933ynx8kc0va0uwhev9n7puwul0wm8n8ga3rgqp3smnxy75ds50gjvh
---

In order to maintain my sanity, I install and configure software on VPS instances in a <span class='no-wrap'>[semi-automated](https://github.com/codonaft/ohmyvps)</span> way.

Recently I figured out how to install <span class='no-wrap'>Alpine Linux</span> on an `x86_64` VPS instance hosted by a company that didn't manage to implement a trivial boot from arbitrary ISO images.
<!--more-->

Here's how to deal with all this dementia:

#### 1. Boot preinstalled Ubuntu, `sudo -s`

#### 2. Reboot into the <span class='no-wrap'>Alpine Linux</span> ISO image:

```bash
#!/usr/bin/env bash

set -eu

ARCH="x86_64"
VERSION="3.20.3"
MIRROR="https://dl-cdn.alpinelinux.org/alpine"

short_version=$(echo ${VERSION} | sed 's!\.[0-9]*$!!')
iso="alpine-virt-${VERSION}-${ARCH}.iso"
url="${MIRROR}/v${short_version}/releases/${ARCH}/${iso}"

apt -y install wget
wget "${url}" "${url}.sha256" "${url}.asc" "https://alpinelinux.org/keys/ncopa.asc"
sha256sum -c "${iso}.sha256"
gpg --import < ncopa.asc
gpg --verify "${iso}.asc" "${iso}"

mount -t iso9660 "${iso}" /mnt
cp -a /mnt/* /
cp -a /mnt/* /boot/ # in case if you have a separate /boot partition and the rest of stuff on LVM
umount /mnt

echo '#!/bin/sh
cat << EOF
menuentry "Alpine Linux" --unrestricted {
  linux /boot/vmlinuz-virt
  initrd /boot/initramfs-virt
}
EOF' > /etc/grub.d/99_custom

chmod +x /etc/grub.d/99_custom
update-grub2
grub-reboot "Alpine Linux"
reboot
```

#### 3. Unmount VPS disk, fix file layout, wipe VPS disk, install the OS:
```bash
#!/usr/bin/env sh

set -eu

DISK="sda"

cp -r /.modloop /root/
cp -a /media/${DISK}*/apks /root/
umount /.modloop /media/${DISK}*
ln -sf /root/.modloop/modules /lib/modules
for i in /media/${DISK}*/ ; do
  cp -a /root/apks "$i"
done

setup-interfaces
setup-dns 9.9.9.9
/etc/init.d/networking restart
setup-apkrepos -1
apk add sgdisk
/etc/init.d/networking stop

sgdisk --zap-all "/dev/${DISK}"
setup-alpine
```

I wish the third step was less esoteric and more reliable.
Most likely this installation method will stop working after few ISO image releases.

## netboot.xyz
Another [approach](https://netboot.xyz/docs/booting/grub#on-debianubuntu), which is actually pretty user-friendly, is `grub-imageboot` + `netboot.xyz`.
It works. However, I'm personally *very* uneasy about the
{% include span_with_tooltip.html large="true" body="security" tooltip="Due to implementation limitations, it downloads everything over untrusted HTTP, not HTTPS. Any compromised router/ISP may easily replace OS you're trying to install with a modified backdoored/malicious version. Untrusted protocol <i>could</i> be okay, however I have serious concerns about whether netboot.xyz actually correctly checks all required signatures that relate <i>specifically</i> to <span class='no-wrap'>Alpine Linux.</span>" %}
of this approach and have less time to verify it.

## Booting ISO using ramdisk
This has [never worked](https://www.reddit.com/r/AlpineLinux/comments/1fm1r4s/comment/loxyheb/) for me, I'd gladly appreciate if anyone share a `grub2` config that *successfully* does that trick with <span class='no-wrap'>Alpine Linux.</span>

## If you are a VPS hosting provider
Please consider adding a *custom* ISO image boot option to your control panel.
It's so damn *simple* to implement and yet it will open your business to more clients and greater profits, for almost no effort!

And *no*, preinstalled system disk images are never enough.
Even for this specific OS you will likely make some weird disk layout or whatever else that makes provisioning/deployment scripts incompatible with your image, right?

{% include quote.html text="What's your favorite VPS hosting<br>that <u>supports</u> custom ISO boot?" %}

I'm pretty exhausted by this research.
Please let me know in the comments below if you are aware of any VPS hosting providers that *actually* fall under these criteria:
- control panel with
    - VNC client
    - *custom* ISO image boot support
- hosted in a [DMCA-ignored](https://en.wikipedia.org/wiki/Censorship_by_copyright) zone
- honest ≈1 Gbps outgoing speed
- ≥15 GiB SSD/NVMe disk space with a possibility to extend it later
- ≥1 GiB RAM
- monthly renewal with a possibility to switch to an annual renewal
- competitive price
    - with no hidden additional charges (like for traffic overuse, etc.)

Yes, it's still relevant, in whatever century you're reading this article. <span class='no-wrap'>Thank you a lot! ❤️</span>

BEARBOX_D1 INSTALL / REFRESH DISC

Purpose
-------
This disc boots the BearBox Ubuntu Server installer and installs the BearBox
headless/VR development bootstrap.

No Fixed Login On This Disc
---------------------------
This revised Disc 1 does not embed a fixed Linux username or password. During
installation, Ubuntu asks you to create the admin account and choose the
password. Write them down somewhere safe.

Storage Safety
--------------
The default BearBox menu entry keeps storage selection interactive and boots in
verbose safe-graphics mode. Carefully confirm the target disk before
installing.

The disc also includes a separate full-wipe entry:

  BearBox FULL WIPE VERBOSE (DESTROYS selected disk)

Choose that only when you want BearBox to take over a whole disk. It uses
Ubuntu's LVM layout and destroys the selected disk's existing partitions.

If boot hangs after only:

  EFI stub: Loaded initrd from LINUX_EFI_INITRD_MEDIA_GUID device path
  EFI stub: Measured initrd data into PCR 9

choose the first verbose safe-graphics entry. It uses text graphics, `nomodeset`,
and forced kernel/systemd console logging. The normal-graphics verbose entries
are there as fallback options if safe graphics is too conservative.

If that still hangs at the same EFI stub PCR 9 line, try:

  BearBox Install/Refresh VERBOSE no EFI runtime
  BearBox Install/Refresh VERBOSE ACPI/APIC fallback

If boot reaches PCI enumeration and stalls around a line such as
`PCI bridge to bus 23`, try:

  BearBox Install/Refresh VERBOSE PCI bridge fallback
  BearBox Install/Refresh VERBOSE last resort ACPI off

Multiboot / Alongside Existing OS
---------------------------------
BearBox can be installed on its own partition alongside Windows or another
Linux installation.

Recommended approach:

1. Back up the existing OS first.
2. Create free/unallocated space using the existing OS disk manager if possible.
3. Boot this disc.
4. At storage selection, choose manual/custom storage.
5. Preserve the existing EFI System Partition. Do not format it.
6. Create or select a Linux partition for BearBox and mount it as "/".
7. Optionally create a swap partition or use swapfile defaults.
8. Confirm only the BearBox target partition is formatted.

After first boot, BearBox installs `os-prober` and configures GRUB to show a
menu and discover other operating systems.

Full Wipe Install
-----------------
Use the full-wipe menu entry only for a dedicated BearBox disk or a machine you
are intentionally repurposing. The identity screen still asks you to create your
own admin username/password; those are not embedded on the disc.

Wipe All Non-Installer Disks
----------------------------
For lab/rebuild cases, this disc includes an extra manual utility:

  /bearbox-wipe-non-install-disks.sh

It is not run automatically. Boot the stock Ubuntu live/install environment,
open a shell, then run:

  sudo /cdrom/bearbox-wipe-non-install-disks.sh

That dry-runs and lists candidate disks. To actually wipe:

  sudo /cdrom/bearbox-wipe-non-install-disks.sh --wipe

The utility excludes the mounted installer source disk/partition, mounted
BEARBOX_D1/BEARBOX_D2 media, and mounted partitions containing BearBox
installer/runtime marker files. It is meant to protect cases where the install
disc contents were copied onto an SSD/HDD partition used as the installer
source.

Still verify the candidate list before confirming. It requires typing:

  WIPE NON INSTALL DISKS

What Gets Installed
-------------------
- OpenSSH server, with password SSH disabled after bootstrap
- BearBox first-boot bootstrap service
- Dr. Watson decoy shell
- Browser terminal support for Quest/remote browser workflows
- Cloudflare Tunnel helper for internet access
- Multiboot GRUB/os-prober support
- GitHub CLI, Codex CLI, NVIDIA driver, and CUDA bootstrap attempts

After Install
-------------
Log in with the username/password you created during installation.

If network was offline during first boot, configure it and restart bootstrap:

  sudo nmtui
  sudo systemctl restart bearbox-firstboot
  sudo journalctl -u bearbox-firstboot -f

Cloudflare Tunnel
-----------------
To expose the browser terminal and WebXR runtime over the internet, save your
Cloudflare Tunnel token at:

  /etc/bearbox/cloudflared-token

Then run:

  sudo configure-cloudflare-tunnel

Recommended Cloudflare routes:

  terminal hostname -> http://127.0.0.1:7681
  WebXR hostname    -> http://127.0.0.1:5173

Disc 2
------
Insert BEARBOX_D2 after install to verify the boot key and install the Vibe
runtime:

  sudo bearbox-verify-boot-key
  sudo install-vibe-runtime-from-disc2

# usb-cloner

Turns a Lenovo ThinkCentre M70q (or any Linux box) into a standalone USB
flash drive duplicator, replacing a StarTech USB duplicator.

- Master drive in the **front** USB port. Blanks in the **rear** ports.
- Sector-for-sector copy. No images are made or stored. The master is read
  once and streamed to every blank at the same time.
- Every blank is read back and hashed against the master. PASS/FAIL per port.
- Boots straight into the cloner on the console. No keyboard needed:
  blanks in, master in, it goes. Pull the drives, insert the next batch.

## Hardware

- Lenovo ThinkCentre M70q, any storage for the OS (nothing else lives on it).
- A monitor on HDMI/DisplayPort for the status screen.
- No keyboard. The default trigger is inserting the master. If you want
  Enter-to-start instead, set `TRIGGER=enter` and put a keyboard on the
  front USB-C port (through an adapter) so the rear ports stay free.
- The rear ports on some M70q generations are a mix of USB 3.2 and USB 2.0.
  USB 2.0 caps a stick at roughly 35 MB/s. `usb-cloner-map` prints the link
  speed it sees, so you can find out which is which.
- Need more than four at a time? Add a **powered** USB 3 hub to a rear port.
  Everything behind it is treated as a blank.

## Install the OS (once)

Debian 13 or Ubuntu Server 24.04 LTS both work; the cloner only needs
coreutils, util-linux and systemd. The steps below are for Debian. On
Ubuntu Server pick **Ubuntu Server (minimized)**, add only the OpenSSH
server, and skip every snap it offers.

1. Download the Debian 13 netinst ISO and write it to a stick.
2. Boot the M70q from it (F12 for the boot menu). Choose the text installer.
3. Partitioning: guided, use the entire internal disk.
4. Software selection: untick every desktop and "GNOME" etc. Tick only
   **SSH server** and **standard system utilities**. No desktop means no
   auto-mounting, which is what keeps inserted drives free to be written.
5. Finish, reboot, remove the installer stick.
6. BIOS (F1 at power-on): set *After Power Loss* to *Power On* so the box
   comes back on its own after an outage. Optional.

## Install the cloner

On the M70q, as root (or `sudo -i`):

```bash
apt-get install -y git
git clone https://github.com/Powerhouse-Recycling/usb-cloner.git /opt/usb-cloner
cd /opt/usb-cloner
./install.sh
systemctl start usb-cloner
```

On first start the screen asks you to remove all USB drives and insert one
into the socket you want as the master socket. That maps it, including the
socket's USB 2.0 side, which the kernel reports as the port's peer. Remove
the drive and the cloner is ready. No keyboard needed.

From now on the box boots into the cloner. Log in over SSH for maintenance.

## Moving the drive to another machine

The config remembers which machine it was mapped on. Boot the drive in a
different box and the screen runs the one-stick mapping again, because USB
port numbers are specific to the controller. Nothing else is hardware
specific: the network config takes DHCP on any wired interface, and the
EFI fallback loader is in place so firmware finds the drive without a
boot entry. Secure Boot on or off both work, the Ubuntu shim is signed.

## Daily use

1. Blanks in the rear ports. The screen lists each one with size and port.
   Blanks smaller than the master are listed as SKIP and left untouched.
2. Master in the front port. A 5 second countdown starts; pulling any drive
   aborts it. Then progress shows for the write, and dots for the verify.
3. Read the result table: `PASS`, `WRITE FAILED` or `VERIFY FAILED` per port.
   Throw away failed drives.
4. Pull the master and the blanks. The screen resets for the next batch.

The master going in is the "go". If it was already in before the blanks,
the screen says so; pull it and reinsert. A reboot with drives plugged in
never starts a batch by itself.

Over SSH, `sudo usb-cloner go` starts whatever is currently plugged in,
in any trigger mode. The other modes (`countdown`, `enter`) are described
in `cloner.conf.example`.

The batch runs at the speed of the slowest drive in it, same as the StarTech.
A full-size copy is made even if the master is mostly empty.

Every drive on the screen shows its negotiated link, USB3 or USB2. A USB 3
stick that links at USB2 was usually seated slowly: pull it and push it in
firmly. The screen warns when the master is on USB2, because a USB 2.0
master read (about 35 MB/s) caps all the writers together. Cheap sticks
that are USB 2.0 devices by design show USB2 in any port; nothing fixes
that except better sticks, and one slow stick sets the pace of its batch.

## Safety rules the script enforces

- Only whole disks attached over USB are ever considered. The internal
  drive is never a candidate.
- The master is identified by physical port (USB bus and port number from
  sysfs, e.g. `usb2/2-3`), never by `/dev/sdX` letter.
- Anything mounted is skipped. The master being mounted aborts.
- Two drives in master ports aborts.
- A target smaller than the master is skipped.

## Config

`/etc/usb-cloner/cloner.conf`, see `cloner.conf.example`. Restart the
service after changing it: `systemctl restart usb-cloner`.

## Logs

`/var/log/usb-cloner/YYYY-MM.log`, one line per target per batch with the
master's model, size and hash prefix and the result.

## Development

`./lint.sh` runs shellcheck in a container.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Screen asks to map the master socket | First start, or the drive is in a new machine | Follow it: remove all drives, insert one in the master socket, remove it |
| Master in front socket but shown as a target | Mapping done behind a hub, so no peer port | Map again with the stick directly in the socket, or run `sudo usb-cloner-map` over SSH |
| Target listed as "SKIP: mounted" | Something auto-mounted it | `apt-get purge udisks2`; never install a desktop on this box |
| Black screen, no cloner | Service not running | `systemctl status usb-cloner`, `journalctl -u usb-cloner` |
| Slow batch | One slow stick, or a USB 2.0 rear port | Check link speed with `usb-cloner-map`; move stick |
| Every target "VERIFY FAILED" on a fresh install | Rust coreutils `dd` (Ubuntu 25.10+) cannot do direct reads | Fixed in the script: it uses `gnudd` when present and reads back with `head`. Check `which gnudd` |

# usb-cloner

Turns a Lenovo ThinkCentre M70q (or any Linux box) into a standalone USB
flash drive duplicator, replacing a StarTech USB duplicator.

- Master drive in the **front** USB port. Blanks in the **rear** ports.
- Sector-for-sector copy. No images are made or stored. The master is read
  once and streamed to every blank at the same time.
- Every blank is read back and hashed against the master. PASS/FAIL per port.
- Boots straight into the cloner on the console. Press Enter to clone, pull
  the drives, insert the next batch.

## Hardware

- Lenovo ThinkCentre M70q, any storage for the OS (nothing else lives on it).
- A monitor on HDMI/DisplayPort for the status screen.
- A USB keyboard for the Enter key, **or** set `AUTOSTART_SECONDS` in the
  config and run without one. The M70q front has both a USB-A and a USB-C
  port; a keyboard can sit on whichever one is not the master port.
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
git clone <this repo> /opt/usb-cloner
cd /opt/usb-cloner
./install.sh
usb-cloner-map
```

`usb-cloner-map` asks you to remove all drives, then insert one into the
front port, and records that port as the master port. A USB 2.0 drive and
a USB 3.x drive in the same socket show up on different port paths, so run
it once with each kind if you use both. Then:

```bash
systemctl start usb-cloner
```

From now on the box boots into the cloner. Log in over SSH for maintenance.

## Daily use

1. Master in the front port. Blanks in the rear ports.
2. The screen lists the master and every blank with size and port. Blanks
   smaller than the master are listed as SKIP and left untouched.
3. Press Enter. Progress shows for the write, then dots for the verify.
4. Read the result table: `PASS`, `WRITE FAILED` or `VERIFY FAILED` per port.
   Throw away failed drives.
5. Pull the blanks. The screen resets for the next batch. The master can stay.

The batch runs at the speed of the slowest drive in it, same as the StarTech.
A full-size copy is made even if the master is mostly empty.

## Safety rules the script enforces

- Only whole disks attached over USB are ever considered. The internal
  drive is never a candidate.
- The master is identified by physical port, never by `/dev/sdX` letter.
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
| "no master port mapped" | `usb-cloner-map` never run | Run it over SSH or on tty2 (Ctrl-Alt-F2) |
| Master in front port but shown as a target | Port path differs for USB 2.0 vs 3.x drives | Run `usb-cloner-map` again with that drive |
| Target listed as "SKIP: mounted" | Something auto-mounted it | `apt-get purge udisks2`; never install a desktop on this box |
| Black screen, no cloner | Service not running | `systemctl status usb-cloner`, `journalctl -u usb-cloner` |
| Slow batch | One slow stick, or a USB 2.0 rear port | Check link speed with `usb-cloner-map`; move stick |

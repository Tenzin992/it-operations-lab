# Troubleshooting Log

Problems I ran into while building the lab, how I diagnosed them, and how I fixed them.

---

## 1. VirtualBox crashes whenever a VM restarts itself

**Symptom:** `VirtualBoxVM.exe - Application Error: The instruction at 0x... referenced memory at 0x... The memory could not be written.` The VM window showed an `iPXE` line before crashing. It happened every time a VM rebooted itself (after Guest Additions, after domain controller promotion, during Windows setup).

![VirtualBox crash error](../screenshots/12-virtualbox-crash-error.png)

**Diagnosis:**
- Noticed the pattern: crashes only on **guest-initiated restarts**; normal start and shutdown worked.
- Suspected a conflict with Windows' built-in hypervisor (Hyper-V), which Docker Desktop and Windows security features use. When Hyper-V is running, VirtualBox has to run on top of it instead of directly on the hardware.
- Ran `systeminfo` on the host. It reported **"A hypervisor has been detected."**
- Disabled Hyper-V at boot with `bcdedit /set hypervisorlaunchtype off` and confirmed the setting with `bcdedit /enum "{current}"`. The hypervisor was still detected.
- Turned off Memory Integrity (Core isolation) and restarted. `systeminfo` showed **Secure Launch** still running under Virtualization-based security, which keeps the hypervisor loaded at the firmware level.

![systeminfo showing hypervisor detected](../screenshots/11-systeminfo-hypervisor.png)

**Resolution / workaround:**
- Decided not to disable firmware-level security on my main laptop just for a lab. Re-enabled Memory Integrity, since it was no longer buying anything.
- Workaround: instead of **Restart**, use **Shut down → wait for Powered Off → Start**. For automatic restarts I can't control, click OK on the error and start the VM again; no data was lost in any case.

**Lesson:** look for the *pattern* in a recurring failure, confirm the cause with tools, and weigh the fix against its cost. Turning off security features isn't always the right answer.

---

## 2. "Failed to open a session for the virtual machine"

**Symptom:** VirtualBox error after a snapshot ("Taking snapshot… 99%") and a power-off ran at the same time.

**Fix:** closed the VM window, ended the stuck `VirtualBoxVM` process in Task Manager, reopened VirtualBox, checked the Snapshots view for a half-finished snapshot, and retook the snapshot with the VM **powered off**.

**Lesson:** don't power off or close a VM while a snapshot is in progress. Offline snapshots are faster and more reliable.

---

## 3. "Insert Guest Additions CD" did nothing

**Symptom:** clicking *Devices → Insert Guest Additions CD image* showed no prompt.

**Fix:** inserting the virtual CD doesn't auto-launch anything. Opened *File Explorer → This PC → VirtualBox Guest Additions (D:)* and ran `VBoxWindowsAdditions-amd64.exe` manually.

---

## 4. Shutdown Event Tracker after an unexpected shutdown

**Symptom:** Windows Server asked *"Why did the computer shut down unexpectedly?"* after the VirtualBox crash.

**Fix:** selected *Other (Unplanned)* and entered a comment (`VirtualBox host crashed during reboot`).

**Lesson:** on real servers, admins log shutdown reasons. These entries show up in Event Viewer when investigating outages.

---

## 5. Domain option greyed out when joining CLIENT01

**Symptom:** in *Computer Name/Domain Changes*, the **Domain** option was disabled with the message *"You must restart this computer for the name change to take effect before you can change its domain membership."*

**Cause:** I had applied the rename to `CLIENT01` first, and Windows won't change domain membership while a rename is pending.

**Fix:** shut down, started the VM again, then joined `lab.local`.

**Lesson:** some changes only apply after a restart, and stacking changes before restarting can block the next one.

---

## 6. `nslookup` shows "Server: UnKnown"

**Symptom:** `nslookup lab.local` on CLIENT01 returned `Server: UnKnown`.

**Explanation:** not an error. nslookup tries to turn the DNS server's IP back into a name (a reverse lookup), and DC01 has no reverse lookup zone yet. The actual answer, `lab.local → 10.0.2.10`, was correct.

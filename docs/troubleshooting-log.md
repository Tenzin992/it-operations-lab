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

---

## 7. Guest Additions install blocked, and CLIENT01's screen wouldn't resize

**Symptom:** running the Guest Additions installer as Jane showed *"You need administrator rights to install or uninstall..."*. After installing, the CLIENT01 desktop still didn't resize with the window.

**Fix:**
- Right-clicked the installer → **Run as administrator** → entered `LAB\Administrator` credentials at the UAC prompt.
- Enabled *View → Auto-resize Guest Display*, then changed CLIENT01's **Graphics Controller to VBoxSVGA** with 128 MB video memory (recommended for Windows guests).

**Lesson:** standard users can't install drivers, which is intended security. IT enters admin credentials only for the task that needs them.

---

## 8. SSH to GLPI01: "Connection refused"

**Symptom:** `ssh labadmin@10.0.2.20` from DC01 returned `connect to host 10.0.2.20 port 22: Connection refused`.

**Diagnosis:** *refused* means the host is reachable but nothing is listening on that port. (A *timeout* would mean the host itself can't be reached.) The OpenSSH server option hadn't been selected during the Ubuntu install.

**Fix:**
```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
systemctl status ssh   # active (running)
```

**Lesson:** the exact wording of a network error tells you which layer to check.

---

## 9. GLPI container crash-looping: "Permission denied"

**Symptom:** `docker compose logs -f glpi` repeated `mkdir: cannot create directory '/var/glpi/config': Permission denied`, then `exited with code 1 (restarting)`.

**Cause:** Docker created the bind-mounted folder `./storage/glpi` owned by `root`, but GLPI inside the container runs as the limited `www-data` user.

**Fix:**
```bash
docker compose down
docker compose run --rm --entrypoint id glpi    # uid=33(www-data)
sudo chown -R 33:33 ./storage/glpi
docker compose up -d
```

**Lesson:** containers run as their own users; folders shared with the host need matching ownership. Linux tracks users by number (uid), like Windows tracks them by SID.

---

## 10. GLPI01 freezing: "soft lockup – CPU#0 stuck"

**Symptom:** GLPI stopped loading in the browser (`ERR_CONNECTION_TIMED_OUT`). GLPI01's console showed `watchdog: BUG: soft lockup - CPU#0 stuck for 139s!`, `rcu_preempt detected stalls on CPUs`, and systemd watchdog timeouts.

**Diagnosis:** the VM's virtual CPU wasn't getting real CPU time from the laptop. Three VMs were running at once on top of Hyper-V, and Windows **Energy Saver** was throttling the CPU on battery.

**Fix / mitigation:** powered GLPI01 off and on (the containers restarted automatically thanks to `restart: unless-stopped`), kept the laptop plugged in with Energy Saver off, and closed other apps. If it recurs, reduce GLPI01 to 1 vCPU.

**Lesson:** an "app is down" ticket can be caused by the host underneath. Check the server's own logs before changing the app.

---

## 11. GLPI LDAP test: "Invalid credentials (49)"

**Symptom:** the LDAP test passed the network, BaseDN, and URI checks but failed at **Bind** with error 49.

**First guess (wrong):** the browser autofilled the wrong password.

**Real cause:** the `svc-glpi` account **had never been created**. Two PowerShell commands were pasted as one line, so `Read-Host` treated the whole `New-ADUser ...` text as its prompt, and `New-ADUser` never ran. No error appeared. `Set-ADAccountPassword` later revealed it: *"Cannot find an object with identity: 'svc-glpi'."*

**Fix:** ran the two commands separately, then verified with `Get-ADUser svc-glpi | Select-Object Name, Enabled`.

**Lesson:** "no error" doesn't mean "it worked." Always verify the result.

---

## 12. GLPI LDAP test: "Strong(er) authentication required (8)"

**Symptom:** after fixing the account, Bind failed with error 8.

**Cause:** Windows Server 2025 domain controllers require **LDAP signing** by default and reject plain binds on port 389.

**Fix (lab only):** in the **Default Domain Controllers Policy**, set *Domain controller: LDAP server signing requirements* = **None** and *... Enforcement* = **Disabled**, then `gpupdate /force` on DC01.

**Proper fix (planned):** keep signing enforced and connect with **LDAPS** (port 636) using a certificate from AD Certificate Services.

**Lesson:** a changed error code means progress. Error 49 was about *who* was logging in; error 8 was about *how*.

---

## 13. LDAP sync imported groups and disabled users

**Symptom:** the first `ldap:sync` reported 15 users imported, but LabCorp only has 8 active employees. The GLPI user list included `HR-Staff`, `IT-Staff`, `Sales-Staff`, `Finance-Staff`, plus `mlee` and `tnguyen` (both offboarded).

**Cause:** the LDAP **connection filter was empty**, so GLPI read every object with a login name in `OU=LabCorp`.

**Fix:** moved the 6 wrong entries to the trashbin, then set the filter to active people only:
```
(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

**Lesson:** compare results against what you expect. "Success, 15 imported" was only wrong because I knew the right number was 8.

---

## 14. LDAP filter: "Bad search filter (-7)"

**Symptom:** after entering the full filter, the LDAP test failed at Search with error -7 (filter syntax error).

**Diagnosis:** simplified the filter and added one piece at a time, predicting the count for each:
- `(objectClass=user)` → **11** ✅
- `(&(objectClass=user)(objectCategory=person))` → **10** ✅
- full filter, retyped carefully → **8** ✅

The original typo was in the disabled-account part.

**Lesson:** when something complex fails, reduce it to the smallest version that works, then add pieces back one at a time.

---

## 15. Small command-line gotchas

- **`glpi` rejected at GLPI01's Linux login:** `glpi` is the GLPI *website* account; the Linux server account is `labadmin`. Different systems, different accounts.
- **`There are no commands defined in the "glpi:ldap" namespace`:** the command was renamed in GLPI 12. Found the current name with `php bin/console list ldap` (`ldap:sync`) and checked its options with `--help` before running it.

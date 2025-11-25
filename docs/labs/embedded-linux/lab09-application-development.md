# Lab 9: Application Development and Debugging

## DON'T PANIC

The Hitchhiker's Guide to Embedded Linux has this to say about debugging:

*"Debugging is the art of figuring out why your code doesn't work, as opposed to why you thought it would work. This is similar to the difference between what Deep Thought calculated (42) and what everyone expected (a useful answer). Both are technically correct, but only one is helpful."*

## Objectives

Master cross-platform application development and debugging techniques:

- Cross-compile standalone applications for ARM64
- Use pkg-config for library dependency management
- Debug applications with strace and ltrace
- Remote debugging with gdb and gdbserver
- Visual Studio Code integration for embedded debugging
- System profiling with perf
- Implement real-world application: Nunchuk-controlled MPD client
- Analyze core dumps for post-mortem debugging

## Prerequisites

- Completed Lab 8 (Buildroot)
- Running Buildroot system with NFS root
- USB audio device connected
- Nunchuk connected to I2C bus
- Understanding of C programming
- Basic debugging concepts

## Lab Duration

Approximately 5-6 hours

## Application Architecture

```
┌──────────────────────────────────────────────────────────────┐
│           Nunchuk MPD Client Application                     │
└──────────────────────────────────────────────────────────────┘

User Input (Nunchuk):                   Audio Output:
  Joystick UP    → Volume +5%             ┌─────────────┐
  Joystick DOWN  → Volume -5%             │  USB Audio  │
  Joystick LEFT  → Previous track         │   Device    │
  Joystick RIGHT → Next track             └──────▲──────┘
  Z button       → Pause/Play                    │
  C button       → Quit client                   │
                                           ┌─────┴──────┐
         ↓                                 │    MPD     │
  ┌─────────────────┐                      │  (Server)  │
  │  Input Layer    │                      └─────▲──────┘
  │ /dev/input/eventX│                           │
  └────────┬────────┘                            │
           │                              ┌──────┴──────┐
           ↓                              │  libmpdclient│
  ┌─────────────────┐                    │   (Library)  │
  │ Nunchuk Client  │────────────────────┤              │
  │  Application    │  MPD Protocol      └──────────────┘
  │  (nunchuk-mpd-  │  (Port 6600)
  │   client)       │
  └─────────────────┘

Libraries:
- libmpdclient: MPD client library
- libc (musl): C standard library

System Calls:
- open(), read(), write() → Input device access
- socket(), connect(), send(), recv() → MPD communication
```

## Environment Setup

### Working Directory

```bash
cd $HOME/embedded-linux-beagleplay-labs
mkdir -p appdev
cd appdev
```

### Verify Buildroot System

Ensure your BeaglePlay is booted with the Buildroot NFS root from Lab 8:

```bash
# On BeaglePlay
mount | grep nfs

# Verify MPD and Nunchuk
ps | grep mpd
lsmod | grep nunchuk
ls /dev/input/event*
```

## Section 1: Third-Party Library Integration

### Understanding Library Dependencies

Our application depends on `libmpdclient` to communicate with MPD. Buildroot hasn't built this yet.

### Add libmpdclient to Buildroot

```bash
cd $HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot

make menuconfig
```

**Enable libmpdclient:**

```
Target packages --->
    Audio and video applications --->
        [*] libmpdclient
```

Save and exit.

### Rebuild Buildroot

```bash
# Incremental build (only libmpdclient and dependencies)
make

# Update NFS root
cd ../nfsroot
rm -rf *
tar xvf ../buildroot/output/images/rootfs.tar
```

### Verify Library Installation

```bash
# On BeaglePlay (after reboot)
ls -l /usr/lib/libmpdclient.*

# Expected:
# lrwxrwxrwx ... libmpdclient.so -> libmpdclient.so.2
# lrwxrwxrwx ... libmpdclient.so.2 -> libmpdclient.so.2.22
# -rwxr-xr-x ... libmpdclient.so.2.22
```

**Verification Checklist:**

- [ ] libmpdclient added to Buildroot configuration
- [ ] Buildroot rebuilt with libmpdclient
- [ ] NFS root updated
- [ ] Library files present on target in `/usr/lib/`

## Section 2: Cross-Compiling with pkg-config

### Create Application Source

```bash
cd $HOME/embedded-linux-beagleplay-labs/appdev

# Create nunchuk-mpd-client.c
vi nunchuk-mpd-client.c
```

**nunchuk-mpd-client.c:**

```c
/* nunchuk-mpd-client.c - Control MPD playback with Nunchuk */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/input.h>
#include <mpd/client.h>
#include <dirent.h>

#define INPUT_DEVICE_PREFIX "/dev/input/event"

/* Find Nunchuk input device */
static int find_nunchuk_device(void) {
    DIR *dir;
    struct dirent *entry;
    char device_path[256];
    char device_name[256];
    int fd;

    dir = opendir("/dev/input");
    if (!dir) {
        perror("Failed to open /dev/input");
        return -1;
    }

    while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "event", 5) != 0)
            continue;

        snprintf(device_path, sizeof(device_path), "/dev/input/%s", entry->d_name);
        
        fd = open(device_path, O_RDONLY);
        if (fd < 0)
            continue;

        if (ioctl(fd, EVIOCGNAME(sizeof(device_name)), device_name) >= 0) {
            if (strstr(device_name, "Nunchuk") != NULL) {
                closedir(dir);
                printf("Found Nunchuk at %s\n", device_path);
                return fd;
            }
        }
        
        close(fd);
    }

    closedir(dir);
    fprintf(stderr, "ERROR: didn't manage to find the Nunchuk device in /dev/input. "
                    "Is the Nunchuk driver loaded?\n");
    return -1;
}

int main(int argc, char *argv[]) {
    struct input_event ev;
    int nunchuk_fd;
    struct mpd_connection *conn;
    int joystick_x_prev = 0;
    int joystick_y_prev = 0;

    printf("Nunchuk MPD Client starting...\n");

    /* Find and open Nunchuk device */
    nunchuk_fd = find_nunchuk_device();
    if (nunchuk_fd < 0) {
        return EXIT_FAILURE;
    }

    /* Connect to MPD */
    conn = mpd_connection_new("localhost", 6600, 0);
    if (conn == NULL) {
        fprintf(stderr, "Failed to create MPD connection\n");
        close(nunchuk_fd);
        return EXIT_FAILURE;
    }

    if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS) {
        fprintf(stderr, "MPD connection error: %s\n",
                mpd_connection_get_error_message(conn));
        mpd_connection_free(conn);
        close(nunchuk_fd);
        return EXIT_FAILURE;
    }

    printf("Connected to MPD. Use Nunchuk to control playback:\n");
    printf("  Joystick UP:    Volume +5%%\n");
    printf("  Joystick DOWN:  Volume -5%%\n");
    printf("  Joystick LEFT:  Previous track\n");
    printf("  Joystick RIGHT: Next track\n");
    printf("  Z button:       Pause/Play\n");
    printf("  C button:       Quit\n\n");

    /* Event loop */
    while (1) {
        ssize_t bytes = read(nunchuk_fd, &ev, sizeof(ev));
        if (bytes != sizeof(ev)) {
            perror("read");
            break;
        }

        /* Process only key and absolute axis events */
        if (ev.type == EV_KEY && ev.value == 1) {  /* Button press */
            if (ev.code == BTN_Z) {
                /* Z button: toggle pause/play */
                printf("Z pressed: Toggle playback\n");
                mpd_run_toggle_pause(conn);
            } else if (ev.code == BTN_C) {
                /* C button: quit */
                printf("C pressed: Quitting\n");
                break;
            }
        } else if (ev.type == EV_ABS) {  /* Joystick movement */
            struct mpd_status *status;
            int volume;

            if (ev.code == ABS_Y) {
                /* Joystick Y axis: volume control */
                if (ev.value < 100 && joystick_y_prev >= 100) {
                    /* DOWN */
                    status = mpd_run_status(conn);
                    if (status) {
                        volume = mpd_status_get_volume(status);
                        mpd_status_free(status);
                        
                        volume -= 5;
                        if (volume < 0) volume = 0;
                        
                        mpd_run_set_volume(conn, volume);
                        printf("Volume down: %d%%\n", volume);
                    }
                } else if (ev.value > 150 && joystick_y_prev <= 150) {
                    /* UP */
                    status = mpd_run_status(conn);
                    if (status) {
                        volume = mpd_status_get_volume(status);
                        mpd_status_free(status);
                        
                        volume += 5;
                        if (volume > 100) volume = 100;
                        
                        mpd_run_set_volume(conn, volume);
                        printf("Volume up: %d%%\n", volume);
                    }
                }
                joystick_y_prev = ev.value;
            } else if (ev.code == ABS_X) {
                /* Joystick X axis: track navigation */
                if (ev.value < 80 && joystick_x_prev >= 80) {
                    /* LEFT */
                    printf("Previous track\n");
                    mpd_run_previous(conn);
                } else if (ev.value > 180 && joystick_x_prev <= 180) {
                    /* RIGHT */
                    printf("Next track\n");
                    mpd_run_next(conn);
                }
                joystick_x_prev = ev.value;
            }
        }

        /* Check for MPD errors */
        if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS) {
            fprintf(stderr, "MPD error: %s\n",
                    mpd_connection_get_error_message(conn));
            mpd_connection_clear_error(conn);
        }
    }

    /* Cleanup */
    mpd_connection_free(conn);
    close(nunchuk_fd);

    printf("Client terminated.\n");
    return EXIT_SUCCESS;
}
```

### Configure pkg-config for Cross-Compilation

```bash
# Set PKG_CONFIG_LIBDIR to point to target libraries
export PKG_CONFIG_LIBDIR=$HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging/usr/lib/pkgconfig

# Set PKG_CONFIG_SYSROOT_DIR
export PKG_CONFIG_SYSROOT_DIR=$HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging

# Test pkg-config
pkg-config --cflags --libs libmpdclient

# Expected output:
# -I/home/<user>/.../output/staging/usr/include -L/home/<user>/.../output/staging/usr/lib -lmpdclient
```

### Cross-Compile the Application

```bash
cd $HOME/embedded-linux-beagleplay-labs/appdev

# Set cross-compiler
export PATH=$HOME/x-tools/aarch64-beagleplay-linux-musl/bin:$PATH

# Compile
aarch64-beagleplay-linux-musl-gcc \
    -o nunchuk-mpd-client \
    nunchuk-mpd-client.c \
    $(pkg-config --cflags --libs libmpdclient)

# Verify it's ARM64
file nunchuk-mpd-client

# Expected:
# nunchuk-mpd-client: ELF 64-bit LSB executable, ARM aarch64, ...
```

### Deploy to Target

```bash
# Copy to NFS root
cp nunchuk-mpd-client $HOME/embedded-linux-beagleplay-labs/buildroot-lab/nfsroot/root/

# Strip to reduce size
aarch64-beagleplay-linux-musl-strip $HOME/embedded-linux-beagleplay-labs/buildroot-lab/nfsroot/root/nunchuk-mpd-client
```

### Test on Target

```bash
# On BeaglePlay

# Ensure MPD is running and has music
mpc update
mpc add /
mpc play

# Run client
/root/nunchuk-mpd-client

# Use Nunchuk to control playback!
```

**Verification Checklist:**

- [ ] Application source code created
- [ ] pkg-config configured for cross-compilation
- [ ] Application compiled successfully for ARM64
- [ ] Binary deployed to NFS root
- [ ] Application runs on target
- [ ] Nunchuk controls work (volume, track navigation, pause, quit)

## Section 3: Debugging with strace

If the application doesn't work, let's debug it systematically.

### Add strace to Buildroot

```bash
cd $HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot

make menuconfig
```

**Enable strace:**

```
Target packages --->
    Debugging, profiling and benchmark --->
        [*] strace
```

Save, rebuild, update NFS root.

### Trace System Calls

```bash
# On BeaglePlay

# Run application through strace
strace /root/nunchuk-mpd-client
```

**Expected Output (partial):**

```
execve("/root/nunchuk-mpd-client", ["/root/nunchuk-mpd-client"], ...) = 0
...
openat(AT_FDCWD, "/dev/input", O_RDONLY|O_DIRECTORY) = 3
getdents64(3, /* entries */, 1024) = ...
openat(AT_FDCWD, "/dev/input/event0", O_RDONLY) = 4
ioctl(4, EVIOCGNAME(256), "gpio-keys") = 10
close(4) = 0
openat(AT_FDCWD, "/dev/input/event5", O_RDONLY) = 4
ioctl(4, EVIOCGNAME(256), "Wii Nunchuk") = 12
socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 5
connect(5, {sa_family=AF_INET, sin_port=htons(6600), sin_addr=inet_addr("127.0.0.1")}, 16) = 0
...
read(4, ..., 24) = 24   # Reading from Nunchuk
write(5, "noidle\n", 7) = 7   # Writing to MPD
```

**Key Observations:**

- `openat("/dev/input", ...)`: Scanning for input devices
- `ioctl(EVIOCGNAME, ...)`: Querying device names
- `socket(...AF_INET...)` + `connect(...)`: MPD connection
- `read(4, ...)`: Reading Nunchuk events
- `write(5, ...)`: Sending MPD commands

###Common Issues Detected by strace

**Problem: Can't find Nunchuk**

```
openat(AT_FDCWD, "/dev/input", O_RDONLY|O_DIRECTORY) = -1 ENOENT (No such file or directory)
```

**Solution:** Mount devtmpfs or create `/dev/input`

**Problem: Permission denied**

```
openat(AT_FDCWD, "/dev/input/event5", O_RDONLY) = -1 EACCES (Permission denied)
```

**Solution:** Run as root or adjust permissions

**Problem: MPD connection refused**

```
connect(5, {sa_family=AF_INET, ...}, 16) = -1 ECONNREFUSED (Connection refused)
```

**Solution:** Start MPD service

**Verification Checklist:**

- [ ] strace installed via Buildroot
- [ ] Application traced successfully
- [ ] System calls visible and understood
- [ ] Used strace to diagnose issues

## Section 4: Debugging with ltrace

### Add ltrace to Buildroot

```bash
cd $HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot

make menuconfig
```

**Enable ltrace:**

```
Target packages --->
    Debugging, profiling and benchmark --->
        [*] ltrace
```

Rebuild and update NFS root.

### Trace Library Calls

```bash
# On BeaglePlay
ltrace /root/nunchuk-mpd-client
```

**Expected Output (partial):**

```
mpd_connection_new("localhost", 6600, 0) = 0x...
mpd_connection_get_error(0x...) = MPD_ERROR_SUCCESS
mpd_run_status(0x...) = 0x...
mpd_status_get_volume(0x...) = 75
mpd_status_free(0x...)
mpd_run_set_volume(0x..., 80) = 1
mpd_run_toggle_pause(0x...) = 1
mpd_run_next(0x...) = 1
mpd_connection_free(0x...)
```

**Key Observations:**

- All `mpd_*` function calls from libmpdclient are visible
- Return values shown (helpful for debugging)
- Can see actual parameters passed

### Debug a Crash with ltrace

Let's intentionally introduce a bug to see ltrace in action.

**Modified code (buggy version):**

```c
/* In main(), after creating connection */
mpd_connection_free(conn);  /* BUG: Free too early! */

/* Then later when trying to use conn... */
mpd_run_toggle_pause(conn);  /* CRASH: Use-after-free */
```

**Run with ltrace:**

```bash
ltrace /root/nunchuk-mpd-client
```

**Output shows:**

```
mpd_connection_free(0x12345678) = <void>
...
mpd_run_toggle_pause(0x12345678) = +++ killed by SIGSEGV +++
```

This clearly shows the sequence: connection freed, then accessed → crash!

**Verification Checklist:**

- [ ] ltrace installed via Buildroot
- [ ] Library calls traced successfully
- [ ] Used ltrace to understand call sequence
- [ ] Debugged library-related issues

## Section 5: Remote Debugging with gdb and gdbserver

### Add gdb and gdbserver to Buildroot

```bash
cd $HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot

make menuconfig
```

**Enable debugging tools:**

```
Target packages --->
    Debugging, profiling and benchmark --->
        [*] gdb
            [*] gdbserver
            [*] full debugger
```

**Toolchain options:**

```
Toolchain --->
    [*] Build cross gdb for the host
        # This gives you aarch64-linux-gdb on your workstation
```

Rebuild and update NFS root.

### Compile Application with Debug Symbols

```bash
cd $HOME/embedded-linux-beagleplay-labs/appdev

# Compile with -g flag (debug symbols)
aarch64-beagleplay-linux-musl-gcc \
    -g \
    -o nunchuk-mpd-client-debug \
    nunchuk-mpd-client.c \
    $(pkg-config --cflags --libs libmpdclient)

# Deploy non-stripped version
cp nunchuk-mpd-client-debug $HOME/embedded-linux-beagleplay-labs/buildroot-lab/nfsroot/root/
```

### Start gdbserver on Target

```bash
# On BeaglePlay
gdbserver :2345 /root/nunchuk-mpd-client-debug

# gdbserver listens on TCP port 2345
```

### Connect from Host with gdb

```bash
# On workstation
cd $HOME/embedded-linux-beagleplay-labs/appdev

# Use cross-gdb
aarch64-beagleplay-linux-musl-gdb nunchuk-mpd-client-debug
```

**In gdb:**

```gdb
(gdb) set sysroot /home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging

(gdb) target remote 192.168.0.100:2345

(gdb) break main
Breakpoint 1 at 0x...: file nunchuk-mpd-client.c, line 50.

(gdb) continue
Continuing.

Breakpoint 1, main (argc=1, argv=0x...) at nunchuk-mpd-client.c:50
50          printf("Nunchuk MPD Client starting...\n");

(gdb) next
51          nunchuk_fd = find_nunchuk_device();

(gdb) step
find_nunchuk_device () at nunchuk-mpd-client.c:15
15          dir = opendir("/dev/input");

(gdb) print device_path
$1 = ""

(gdb) continue
Continuing.
```

**Common gdb Commands:**

| Command | Description |
|---------|-------------|
| `break <function>` | Set breakpoint |
| `break <file>:<line>` | Set breakpoint at line |
| `continue` | Resume execution |
| `next` | Step over (next line) |
| `step` | Step into function |
| `print <var>` | Print variable value |
| `backtrace` | Show call stack |
| `info locals` | Show local variables |
| `quit` | Exit gdb |

**Verification Checklist:**

- [ ] gdb and gdbserver added to Buildroot
- [ ] Cross-gdb available on workstation
- [ ] Application compiled with `-g` flag
- [ ] gdbserver started on target
- [ ] Connected from host gdb
- [ ] Set breakpoints and stepped through code

## Section 6: Visual Studio Code Remote Debugging

### Install VS Code Extensions

On your workstation:

```bash
code --install-extension ms-vscode.cpptools
```

### Prepare Target for VS Code Debugging

```bash
# On BeaglePlay

# Start gdbserver in multi mode (persistent)
gdbserver --multi :3333

# This allows VS Code to launch and attach to programs
```

### Create VS Code Configuration

```bash
cd $HOME/embedded-linux-beagleplay-labs/appdev

mkdir -p .vscode
```

**Create .vscode/launch.json:**

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug on BeaglePlay",
            "type": "cppdbg",
            "request": "launch",
            "program": "/root/nunchuk-mpd-client-debug",
            "args": [],
            "stopAtEntry": false,
            "cwd": "/root",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "miDebuggerPath": "/home/<user>/x-tools/aarch64-beagleplay-linux-musl/bin/aarch64-beagleplay-linux-musl-gdb",
            "miDebuggerServerAddress": "192.168.0.100:3333",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "Set sysroot",
                    "text": "set sysroot /home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging"
                }
            ],
            "preLaunchTask": "upload",
            "logging": {
                "moduleLoad": false,
                "trace": false
            }
        }
    ]
}
```

**Create .vscode/tasks.json:**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "type": "shell",
            "command": "aarch64-beagleplay-linux-musl-gcc",
            "args": [
                "-g",
                "-o",
                "nunchuk-mpd-client-debug",
                "nunchuk-mpd-client.c",
                "$(PKG_CONFIG_LIBDIR=/home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging/usr/lib/pkgconfig pkg-config --cflags --libs libmpdclient)"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
        {
            "label": "upload",
            "type": "shell",
            "command": "cp",
            "args": [
                "nunchuk-mpd-client-debug",
                "/home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/nfsroot/root/"
            ],
            "dependsOn": "build"
        }
    ]
}
```

### Debug in VS Code

1. Open `appdev` folder in VS Code:

```bash
code $HOME/embedded-linux-beagleplay-labs/appdev
```

2. Open `nunchuk-mpd-client.c`

3. Set breakpoint (click left of line number)

4. Press `F5` or **Run → Start Debugging**

5. VS Code will:
   - Build the application
   - Upload to target
   - Start debugging session
   - Break at your breakpoint

6. Use debugging controls:
   - Continue (F5)
   - Step Over (F10)
   - Step Into (F11)
   - View variables in sidebar
   - Watch expressions

**Verification Checklist:**

- [ ] VS Code C/C++ extension installed
- [ ] gdbserver running in multi mode on target
- [ ] VS Code launch.json and tasks.json created
- [ ] Successfully debugged application from VS Code
- [ ] Set breakpoints and inspected variables

## Section 7: Post-Mortem Analysis with Core Dumps

### Enable Core Dumps

```bash
# On BeaglePlay

# Set core file pattern
echo "/tmp/core.%p" > /proc/sys/kernel/core_pattern

# Remove core file size limit
ulimit -c unlimited
```

### Introduce a Crash

Modify the application to crash:

```c
/* In main(), after successful operations */
char *bad_ptr = NULL;
*bad_ptr = 'X';  /* Deliberate NULL pointer dereference */
```

Recompile, deploy, and run.

### Collect Core Dump

```bash
# On BeaglePlay
/root/nunchuk-mpd-client-debug

# After crash:
ls -l /tmp/core.*

# core.1234 (where 1234 is the PID)
```

### Analyze Core Dump

```bash
# Copy core dump to workstation (via NFS or scp)
cp /tmp/core.1234 /tmp/

# On workstation
cd $HOME/embedded-linux-beagleplay-labs/appdev

aarch64-beagleplay-linux-musl-gdb \
    nunchuk-mpd-client-debug \
    /tmp/core.1234
```

**In gdb:**

```gdb
(gdb) set sysroot /home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging

(gdb) backtrace
#0  0x0000aaaaaaaabc12 in main () at nunchuk-mpd-client.c:123
#1  0x0000fffff7e12abc in __libc_start_main () from /lib/libc.so.6
#2  0x0000aaaaaaaab890 in _start ()

(gdb) frame 0
#0  0x0000aaaaaaaabc12 in main () at nunchuk-mpd-client.c:123
123         *bad_ptr = 'X';  /* Crash here! */

(gdb) print bad_ptr
$1 = 0x0 <null>

(gdb) info locals
# Shows all local variables at crash time

(gdb) bt full
# Full backtrace with all variables in all frames
```

This shows exactly where and why the crash occurred, without running the program!

**Verification Checklist:**

- [ ] Core dumps enabled on target
- [ ] Crashed application generated core dump
- [ ] Core dump analyzed with gdb on workstation
- [ ] Identified crash location and cause

## Section 8: System Profiling with perf

### Add perf to Buildroot

```bash
cd $HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot

make menuconfig
```

**Enable perf:**

```
Kernel --->
    Linux Kernel Tools --->
        [*] perf
```

Rebuild and update.

### Profile Application

```bash
# On BeaglePlay

# Record application activity
perf record -g /root/nunchuk-mpd-client-debug

# Use Nunchuk for 30 seconds, then quit (C button)

# View report
perf report
```

**Expected Output:**

```
Samples: 1K of event 'cycles:u', Event count (approx.): 123456789
  Overhead  Command   Shared Object      Symbol
+   42.15%  nunchuk   libc.so.6          [.] read
+   18.32%  nunchuk   libmpdclient.so.2  [.] mpd_run_status
+   12.45%  nunchuk   nunchuk-mpd-client [.] main
+    8.21%  nunchuk   libc.so.6          [.] recv
...
```

**Interpretation:**

- 42% of time spent in `read()` (waiting for Nunchuk events)
- 18% in MPD library calls
- 12% in our main loop

### System-Wide Profiling

```bash
# On BeaglePlay

# Ensure music is playing
mpc play

# Profile entire system for 30 seconds
perf record -a -g sleep 30

# Generate report
perf report

# Shows kernel and userspace activity
# Press Enter on symbols to see caller graphs
```

### Live Profiling

```bash
# On BeaglePlay (via SSH for better display)

# Real-time top-like profiler
perf top

# Shows live CPU usage by function
# Useful for finding hot spots
```

**Verification Checklist:**

- [ ] perf compiled and installed via Buildroot
- [ ] Application profiled with `perf record`
- [ ] Profile viewed with `perf report`
- [ ] System-wide profiling performed
- [ ] Understood CPU time distribution

## Troubleshooting Guide

### Problem: pkg-config can't find libmpdclient

**Error:**

```
Package libmpdclient was not found in the pkg-config search path
```

**Solution:**

```bash
export PKG_CONFIG_LIBDIR=$HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging/usr/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=$HOME/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging

# Verify
pkg-config --libs libmpdclient
```

### Problem: gdb can't find libraries

**Symptoms:**

```
(gdb) continue
warning: Could not load shared library symbols for libmpdclient.so.2.
```

**Solution:**

Set sysroot in gdb:

```gdb
(gdb) set sysroot /home/<user>/embedded-linux-beagleplay-labs/buildroot-lab/buildroot/output/staging
```

### Problem: gdbserver connection refused

**Error:**

```
192.168.0.100:2345: Connection refused.
```

**Solutions:**

1. **gdbserver not running on target:**

```bash
# On BeaglePlay
gdbserver :2345 /root/nunchuk-mpd-client-debug
```

2. **Firewall blocking port:**

Disable firewall on target or open port 2345.

3. **Wrong IP address:**

Verify target IP:

```bash
# On BeaglePlay
ip addr show eth0
```

### Problem: Segmentation fault without useful info

**Symptoms:**

```
Program received signal SIGSEGV, Segmentation fault.
0x0000fffff7fc1234 in ?? ()
```

**Cause:** Application not compiled with debug symbols.

**Solution:**

```bash
# Recompile with -g
aarch64-beagleplay-linux-musl-gcc -g -o app app.c $(pkg-config --cflags --libs libmpdclient)
```

### Problem: perf record permission denied

**Error:**

```
perf_event_open(..., PERF_FLAG_FD_CLOEXEC) failed with unexpected error 1 (Operation not permitted)
```

**Solution:**

```bash
# On BeaglePlay
echo -1 > /proc/sys/kernel/perf_event_paranoid
```

Or run as root.

## Advanced Challenges

### Challenge 1: Add Logging Infrastructure

Implement syslog-based logging for the application.

**Requirements:**
- Log MPD commands to syslog
- Different log levels (debug, info, error)
- Use `syslog()` from libc

### Challenge 2: Implement Signal Handling

Add graceful shutdown on SIGINT (Ctrl+C).

**Hint:**

```c
#include <signal.h>

volatile sig_atomic_t running = 1;

void signal_handler(int signum) {
    running = 0;
}

int main() {
    signal(SIGINT, signal_handler);
    
    while (running) {
        /* Main loop */
    }
    
    /* Cleanup */
}
```

### Challenge 3: Memory Leak Detection with Valgrind

Add Valgrind to Buildroot and detect memory leaks.

**Enable in Buildroot:**

```
Target packages --->
    Debugging, profiling and benchmark --->
        [*] valgrind
```

**Run:**

```bash
valgrind --leak-check=full /root/nunchuk-mpd-client
```

### Challenge 4: Create Buildroot Package

Integrate the Nunchuk MPD client as a Buildroot package.

**Structure:**
- `package/nunchuk-mpd-client/Config.in`
- `package/nunchuk-mpd-client/nunchuk-mpd-client.mk`
- Use `$(eval $(cmake-package))` or custom Makefile

### Challenge 5: Implement Auto-Restart with systemd

If using systemd (requires glibc Buildroot config), create a service unit to auto-restart the client on crash.

## What You've Learned

By completing this lab, you've mastered:

✅ **Cross-Compilation:**
- Used pkg-config for library dependency management
- Cross-compiled applications for ARM64
- Managed library paths with `PKG_CONFIG_LIBDIR` and `PKG_CONFIG_SYSROOT_DIR`
- Deployed to target via NFS

✅ **Application Development:**
- Implemented real-world embedded application
- Used third-party libraries (libmpdclient)
- Integrated with hardware (Nunchuk input device)
- Controlled services (MPD playback)

✅ **System Call Debugging:**
- Used strace to trace system calls
- Diagnosed file access, network, and permission issues
- Understood kernel-userspace interaction

✅ **Library Call Debugging:**
- Used ltrace to trace library function calls
- Debugged library usage and sequence issues
- Identified use-after-free and API misuse

✅ **Remote Debugging:**
- Set up gdbserver on embedded target
- Connected from host gdb
- Set breakpoints, stepped through code, inspected variables
- Used cross-gdb with sysroot configuration

✅ **IDE Integration:**
- Configured Visual Studio Code for embedded debugging
- Created launch and task configurations
- Debugged visually with breakpoints and variable inspection

✅ **Post-Mortem Analysis:**
- Enabled core dump generation
- Analyzed crashes without reproducing
- Extracted crash location and variable states from core files

✅ **Performance Profiling:**
- Used perf for application profiling
- Performed system-wide profiling
- Identified performance hotspots
- Understood CPU time distribution

✅ **Best Practices:**
- Separate debug and release builds
- Strip production binaries
- Keep debug symbols on development host
- Use appropriate tools for different debugging scenarios

## Going Further

### Recommended Reading

**Books:**
- *Advanced Linux Programming* - Library usage, debugging
- *Linux System Programming* - System calls, I/O, signals
- *The Art of Debugging with GDB, DDD, and Eclipse*

**Online Resources:**
- GDB manual: https://sourceware.org/gdb/documentation/
- perf wiki: https://perf.wiki.kernel.org/
- Brendan Gregg's performance tools: http://www.brendangregg.com/

### Next Steps

**Continue to Yocto Labs:**
- Lab 10: Yocto Project introduction and environment setup
- Lab 11: Writing custom Yocto layers and recipes
- Lab 12: Image customization and deployment
- Lab 13: SDK generation and application development workflow

**Or explore Linux Debugging track:**
- Lab 14: Kernel debugging techniques
- Lab 15: Kernel crash analysis and oops interpretation
- Lab 16: Tracing with ftrace and trace-cmd
- Lab 17: Dynamic debugging and printk

---

**Estimated Completion Time:** 5-6 hours

**Difficulty:** ⭐⭐⭐⭐☆ (Advanced)

**Prerequisites Met:** ✅ Lab 8 (Buildroot)

**Leads to:** Yocto Labs (10-13) or Debugging Labs (14-17)

**Congratulations!** You've completed all 9 Embedded Linux labs and built a complete embedded system from scratch!

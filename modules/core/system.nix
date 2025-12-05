{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  boot.kernel.sysctl = {
    # Reboot 10 seconds after a kernel panic (helpful for headless machines)
    "kernel.panic" = 10;

    # Increase max PID limit (useful for heavy multitasking)
    "kernel.pid_max" = 4194304;

    # Debugging: Append PID to core dump filename
    "kernel.core_uses_pid" = 1;

    # Increase open file descriptors limit
    "fs.file-max" = 9223372036854775807;

    # Increase inotify watches
    "fs.inotify.max_user_watches" = 524288;
  };
}

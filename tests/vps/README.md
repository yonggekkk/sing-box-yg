# VPS validation helpers

These checks complement the fast shell tests in `tests/`.  Run them only on a
disposable VPS, after a normal installation has completed successfully.

```bash
bash tests/run.sh
bash tests/vps/run-distribution-matrix.sh
bash tests/vps/run-host-integration.sh --live
```

`run-distribution-matrix.sh` needs Docker and verifies the package-manager
selection used by supported distribution families.  `run-host-integration.sh`
requires root and an installed sing-box service; it deliberately writes an
invalid temporary configuration to prove that the restart guard restores the
last known-good configuration.  The script refuses to run unless `--live` is
passed explicitly, and restores the configuration before it exits.

For a longer observation, install `monitor-health.sh` with the accompanying
systemd service and timer units.  It records service state, `sing-box check`,
disk use, and post-install service errors without changing the configuration.

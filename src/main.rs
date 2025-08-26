mod config;
mod evdev;

use crate::config::Config;
use anyhow::Context;
use evdev::ReadFlag;
use std::{
    collections::{HashMap, hash_map},
    ffi::OsString,
    fs::File,
};

fn main() -> anyhow::Result<()> {
    let config_file_path: OsString = match std::env::args_os().nth(1) {
        Some(x) => x,
        None => {
            eprintln!(
                "usage: {} [config-file]",
                std::env::args_os()
                    .next()
                    .unwrap_or_else(|| OsString::from("???"))
                    .to_string_lossy()
            );
            std::process::exit(1);
        }
    };

    let config: Config = Config::load(config_file_path).context("Failed to load configuration")?;

    systemd_journal_logger::JournalLog::new()
        .context("Failed to create logger")?
        .install()
        .context("Failed to install logger")?;

    log::set_max_level(log::LevelFilter::Trace);

    log::debug!("Connecting to keyboard...");

    let dev_file: File = File::open(config.dev).context("Failed to open device file")?;

    let dev = evdev::Dev::try_from(dev_file).context("Unable to create evdev")?;

    log::info!(
        "Connected to {}, VID:PID {:04X}:{:04X}",
        dev.name(),
        dev.vendor_id(),
        dev.product_id()
    );

    let mut outstanding = HashMap::with_capacity(config.keys.len());

    loop {
        match dev.next_event(ReadFlag::NORMAL | ReadFlag::BLOCKING) {
            Ok(Some(event)) => {
                log::debug!(
                    "Event type={} code={} value={}",
                    event.type_,
                    event.code,
                    event.value
                );
                if event.value == 1
                    && event.type_ == 1
                    && let Some(cmd) = config.keys.get(&event.code)
                {
                    if let hash_map::Entry::Vacant(e) = outstanding.entry(event.code) {
                        log::info!("Executing: {cmd}");
                        match std::process::Command::new(cmd).spawn() {
                            Ok(child) => {
                                e.insert(child);
                            }
                            Err(e) => log::error!("Failed to spawn '{cmd}': {e}"),
                        }
                    } else {
                        log::warn!(
                            "Ignoring reapeat key {}, command already in-progress",
                            event.code
                        );
                    }
                }
            }
            Ok(None) => (),
            // Reconnection to keyboard will be handled by systemd
            Err(e) => anyhow::bail!("Failed to get next event: {e}"),
        };

        outstanding.retain(|key, child| match child.try_wait() {
            Ok(Some(status)) => {
                if status.success() {
                    log::info!("child process for key {key} exited sucessfully");
                } else {
                    log::warn!("child process for key {key} exited with code {status:?}");
                }
                false
            }
            Ok(None) => true,
            Err(e) => {
                log::error!("Failed to try_wait child: {e}");
                false
            }
        });
    }
}

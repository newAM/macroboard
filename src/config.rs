use anyhow::Context;
use std::{
    collections::HashMap,
    fs::File,
    io::BufReader,
    path::{Path, PathBuf},
};

#[derive(serde::Deserialize)]
pub struct Config {
    pub dev: PathBuf,
    pub keys: HashMap<u16, String>,
}

impl Config {
    pub fn load<P: AsRef<Path>>(path: P) -> anyhow::Result<Self> {
        let config: Self = serde_json::from_reader(BufReader::new(
            File::open(path).context("Failed to open configuration file")?,
        ))
        .context("Failed to load configuration from file")?;
        Ok(config)
    }
}

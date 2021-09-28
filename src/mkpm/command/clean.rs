/**
 * File: /src/mkpm/command/update.rs
 * Project: mkpm
 * File Created: 26-09-2021 00:17:17
 * Author: Clay Risser
 * -----
 * Last Modified: 26-09-2021 00:40:49
 * Modified By: Clay Risser
 * -----
 * Copyright (c) 2018 Aerys
 *
 * MIT License
 */
use std::fs;

use clap::ArgMatches;

use crate::mkpm;
use crate::mkpm::command::{Command, CommandError, CommandResult};

pub struct CleanCacheCommand {}

impl CleanCacheCommand {
    fn run_clean(&self) -> Result<bool, CommandError> {
        info!("running the \"clean\" command");

        let cache = mkpm::file::get_or_init_cache_dir().map_err(CommandError::IOError)?;

        if !cache.exists() || !cache.is_dir() {
            warn!("{} does not exist or is not a directory", cache.display());

            return Ok(false);
        }

        debug!("removing {}", cache.display());
        fs::remove_dir_all(&cache).map_err(CommandError::IOError)?;
        debug!("{} removed", cache.display());

        Ok(true)
    }
}

impl Command for CleanCacheCommand {
    fn matched_args<'a, 'b>(&self, args: &'a ArgMatches<'b>) -> Option<&'a ArgMatches<'b>> {
        args.subcommand_matches("clean")
    }

    fn run(&self, _args: &ArgMatches) -> CommandResult {
        match self.run_clean() {
            Ok(success) => {
                if success {
                    info!("cache successfully cleaned");
                    Ok(true)
                } else {
                    error!("cache has not been cleaned, check the logs for warnings/errors");
                    Ok(false)
                }
            }
            Err(e) => Err(e),
        }
    }
}
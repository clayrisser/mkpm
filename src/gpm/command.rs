/**
 * File: /src/gpm/command.rs
 * Project: mkpm
 * File Created: 26-09-2021 00:17:17
 * Author: Clay Risser
 * -----
 * Last Modified: 26-09-2021 00:24:40
 * Modified By: Clay Risser
 * -----
 * Copyright (c) 2018 Aerys
 *
 * MIT License
 */
use std::io;
use std::path;

use clap::ArgMatches;
use err_derive::Error;
use git2;
use gitlfs::lfs;

use crate::gpm::package::Package;
use crate::gpm::ssh;

pub mod clean;
pub mod download;
pub mod install;
pub mod update;

#[derive(Debug, Error)]
pub enum CommandError {
    #[error(display = "IO error")]
    IOError(#[error(source)] io::Error),
    #[error(display = "git error")]
    GitError(#[error(source)] git2::Error),
    #[error(display = "Git LFS error")]
    GitLFSError(#[error(source)] lfs::Error),
    #[error(display = "no matching version for package {}", package)]
    NoMatchingVersionError { package: Package },
    #[error(
        display = "the path {:?} (passed via --prefix) does not exist, use --force to create it",
        prefix
    )]
    PrefixNotFoundError { prefix: path::PathBuf },
    #[error(
        display = "the path {:?} (passed via --prefix) is not a directory",
        prefix
    )]
    PrefixIsNotDirectoryError { prefix: path::PathBuf },
    #[error(
        display = "package {} was not successfully installed, check the logs for warnings/errors",
        package
    )]
    PackageNotInstalledError { package: Package },
    #[error(display = "SSH config parser error")]
    SSHConfigParserError(#[error(source)] pest::error::Error<ssh::Rule>),
    #[error(
        display = "invalid LFS object signature: expected {}, got {}",
        expected,
        got
    )]
    InvalidLFSObjectSignature { expected: String, got: String },
}

type CommandResult = std::result::Result<bool, CommandError>;

pub trait Command {
    fn matched_args<'a, 'b>(&self, args: &'a ArgMatches<'b>) -> Option<&'a ArgMatches<'b>>;
    fn run(&self, args: &ArgMatches) -> CommandResult;
}

pub fn commands() -> Vec<Box<dyn Command>> {
    vec![
        Box::new(install::InstallPackageCommand {}),
        Box::new(download::DownloadPackageCommand {}),
        Box::new(update::UpdatePackageRepositoriesCommand {}),
        Box::new(clean::CleanCacheCommand {}),
    ]
}

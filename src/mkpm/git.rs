/**
 * File: /src/mkpm/git.rs
 * Project: mkpm
 * File Created: 26-09-2021 00:17:17
 * Author: Clay Risser
 * -----
 * Last Modified: 26-09-2021 16:46:37
 * Modified By: Clay Risser
 * -----
 * Copyright (c) 2018 Aerys
 *
 * MIT License
 */
use regex;
use std::env;
use std::fs;
use std::io;
use std::path;

use std::io::prelude::*;

use git2;

use indicatif::{ProgressBar, ProgressStyle};

use url::Url;

use crypto_hash::{Algorithm, Hasher};

use crate::mkpm;
use crate::mkpm::command::CommandError;
use crate::mkpm::package::Package;

pub fn get_git_credentials_callback(
) -> impl Fn(&str, Option<&str>, git2::CredentialType) -> Result<git2::Cred, git2::Error> {
    move |remote: &str,
          username: Option<&str>,
          cred_type: git2::CredentialType|
          -> Result<git2::Cred, git2::Error> {
        trace!("entering git credentials callback");

        let url: Url = remote.parse().unwrap();
        let username = username.unwrap_or("git");

        if cred_type.contains(git2::CredentialType::USERNAME) {
            debug!("using username from URI");
            git2::Cred::username(username)
        } else if url.username() != "" && url.password().is_some() {
            debug!("using username and password from URI");
            git2::Cred::userpass_plaintext(url.username(), url.password().unwrap())
        } else {
            debug!("using SSH key");
            let host = String::from(url.host_str().unwrap());
            let (key, passphrase) = mkpm::ssh::get_ssh_key_and_passphrase(&host);
            let (has_pass, passphrase) = match passphrase {
                Some(p) => (true, p),
                None => (false, String::new()),
            };

            match key {
                Some(k) => git2::Cred::ssh_key(
                    username,
                    None,
                    &k,
                    if has_pass {
                        Some(passphrase.as_str())
                    } else {
                        None
                    },
                ),
                None => git2::Cred::default(),
            }
        }
    }
}

pub fn pull_repo(repo: &git2::Repository) -> Result<(), git2::Error> {
    info!(
        "fetching changes for repository {}",
        repo.workdir().unwrap().display()
    );

    let mut callbacks = git2::RemoteCallbacks::new();
    let mut origin_remote = repo.find_remote("origin")?;
    trace!("setup git credentials callback");
    callbacks.credentials(mkpm::git::get_git_credentials_callback());

    let oid = repo.refname_to_id("refs/remotes/origin/master")?;
    let object = repo.find_object(oid, None)?;
    trace!("reset master to HEAD");
    repo.reset(&object, git2::ResetType::Hard, None)?;

    let mut builder = git2::build::CheckoutBuilder::new();
    builder.force();
    repo.set_head("refs/heads/master")?;
    trace!("checkout head");
    repo.checkout_head(Some(&mut builder))?;

    debug!("reset head to master");
    let mut opts = git2::FetchOptions::new();
    opts.remote_callbacks(callbacks);

    origin_remote.fetch(&["master"], Some(&mut opts), None)?;

    debug!("fetched changes");

    Ok(())
}

pub fn get_or_clone_repo(remote: &String) -> Result<(git2::Repository, bool), CommandError> {
    let path = remote_url_to_cache_path(remote)?;

    if path.exists() {
        debug!(
            "use existing repository already in cache {}",
            path.to_str().unwrap()
        );
        return Ok((git2::Repository::open(path)?, false));
    }

    match path.parent() {
        Some(parent) => {
            if !parent.exists() {
                debug!("create missing parent directory {}", parent.display());
                fs::create_dir_all(parent).map_err(CommandError::IOError)?;
            }
        }
        None => (),
    };

    let mut callbacks = git2::RemoteCallbacks::new();
    trace!("setup git credentials callback");
    callbacks.credentials(mkpm::git::get_git_credentials_callback());

    let mut opts = git2::FetchOptions::new();
    opts.remote_callbacks(callbacks);
    opts.download_tags(git2::AutotagOption::All);

    let mut builder = git2::build::RepoBuilder::new();
    builder.fetch_options(opts);
    builder.branch("master");

    debug!(
        "start cloning repository {} in {}",
        remote,
        path.to_str().unwrap()
    );

    // ! FIXME: check .gitattributes for LFS, warn! if relevant
    match builder.clone(remote, &path) {
        Ok(r) => {
            debug!("repository cloned");

            Ok((r, true))
        }
        Err(e) => {
            error!("{:?}", e);
            dbg!(&e);
            Err(CommandError::GitError(e))
        }
    }
}

pub fn remote_url_to_cache_path(remote: &String) -> Result<path::PathBuf, CommandError> {
    let cache = mkpm::file::get_or_init_cache_dir().map_err(CommandError::IOError)?;
    let hash = {
        let mut hasher = Hasher::new(Algorithm::SHA256);

        hasher.write(remote.as_bytes()).unwrap();

        hasher
            .finish()
            .into_iter()
            .fold(String::new(), |s: String, i| {
                s + format!("{:02x}", i).as_str()
            })
    };

    let mut path = path::PathBuf::new();
    path.push(cache);
    path.push(hash);

    Ok(path)
}

pub fn find_or_init_repo(package: &Package) -> Result<(git2::Repository, String), CommandError> {
    match package.remote() {
        Some(remote) => {
            let (repo, is_new_repo) = mkpm::git::get_or_clone_repo(&remote)?;

            if !is_new_repo {
                mkpm::git::pull_repo(&repo).map_err(CommandError::GitError)?;
            }

            match package.find(&repo) {
                Some(refspec) => match find_package_tag(package, &repo, &refspec)? {
                    Some(tag_refspec) => {
                        println!(
                            "  Found:\n    {}{}\n  in:\n    {}\n  at refspec:\n    {}\n  tagged as:\n    {}",
                            mkpm::style::package_name(package.name()),
                            mkpm::style::package_extension(&String::from(".tar.gz")),
                            mkpm::style::remote_url(&remote),
                            mkpm::style::refspec(&refspec),
                            mkpm::style::refspec(&tag_refspec.replace("refs/tags/", "")),
                        );

                        Ok((repo, tag_refspec))
                    }
                    None => {
                        println!(
                            "  Found:\n    {}{}\n  in:\n    {}\n  at refspec:\n    {}",
                            mkpm::style::package_name(package.name()),
                            mkpm::style::package_extension(&String::from(".tar.gz")),
                            mkpm::style::remote_url(&remote),
                            mkpm::style::refspec(&refspec),
                        );

                        Ok((repo, refspec))
                    }
                },
                None => Err(CommandError::NoMatchingVersionError {
                    package: package.clone(),
                }),
            }
        }
        None => {
            debug!("no specific remote provided: searching");

            find_repo_by_package_and_revision(&package)
        }
    }
}

fn commit_to_tag_name(
    repo: &git2::Repository,
    commit_id: &git2::Oid,
) -> Result<Option<String>, git2::Error> {
    let tag_names = repo.tag_names(None)?;

    for tag_name in tag_names.iter() {
        let tag_name = tag_name.unwrap();
        let tag = repo.find_reference(&format!("refs/tags/{}", &tag_name))?;
        match tag.peel(git2::ObjectType::Commit) {
            Ok(c) => {
                if c.as_commit().unwrap().id() == *commit_id {
                    return Ok(Some(String::from(tag_name)));
                }
            }
            _ => continue,
        }
    }

    Ok(None)
}

fn diff_tree_has_path(path: &path::Path, repo: &git2::Repository, tree: &git2::Tree) -> bool {
    let mut found = false;
    let mut found_binary = false;
    let diff = repo
        .diff_tree_to_workdir_with_index(Some(&tree), None)
        .unwrap();
    // iterate over all the changes in the diff
    diff.foreach(
        &mut |a, _| {
            // when using LFS, the changed file is *not* a binary file
            if a.new_file().path().unwrap() == path {
                found = true;
            }
            true
        },
        Some(&mut |a, _| {
            // when *not* using LFS, the changed file *is* a binary file
            if a.new_file().path().unwrap() == path {
                found_binary = true;
            }
            true
        }),
        None,
        None,
    )
    .unwrap();

    return found || found_binary;
}

pub fn find_last_commit_id(
    path: &path::Path,
    repo: &git2::Repository,
) -> Result<git2::Oid, git2::Error> {
    let mut commit = repo.head()?.peel_to_commit()?;
    let mut previous_commit = commit.clone();

    loop {
        let tree = commit.tree().unwrap();

        if diff_tree_has_path(&path, &repo, &tree) {
            debug!("package last modified by commit {:?}", previous_commit);

            return Ok(previous_commit.id());
        }

        let parent = commit.parent(0)?;

        previous_commit = commit;
        commit = parent;
    }
}

pub fn find_repo_by_package_and_revision(
    package: &Package,
) -> Result<(git2::Repository, String), CommandError> {
    let dot_mkpm_dir = mkpm::file::get_or_init_dot_mkpm_dir().map_err(CommandError::IOError)?;
    let current_dir = env::current_dir()?;
    let source_file_path = dot_mkpm_dir.to_owned().join("sources.list");
    let mkpm_path = current_dir.join("mkpm.mk");
    let file = fs::File::open(source_file_path)?;
    let mut remotes = Vec::new();

    for line in io::BufReader::new(file).lines() {
        let line = String::from(line.unwrap().trim());

        remotes.push(line);
    }

    if mkpm_path.exists() {
        for source in get_sources_from_mkpm(mkpm_path)? {
            remotes.push(source);
        }
    }

    let pb = ProgressBar::new(remotes.len() as u64);
    pb.set_style(
        ProgressStyle::default_spinner().template("  [{elapsed_precise}] ({pos}/{len}) {msg}"),
    );
    pb.set_position(0);
    pb.enable_steady_tick(200);

    for remote in remotes {
        debug!("searching in repository {}", remote);

        let path = mkpm::git::remote_url_to_cache_path(&remote)?;
        let repo = git2::Repository::open(path).map_err(CommandError::GitError)?;

        pb.inc(1);
        pb.set_message(remote.clone());

        let mut builder = git2::build::CheckoutBuilder::new();
        builder.force();
        repo.set_head("refs/heads/master")?;
        repo.checkout_head(Some(&mut builder))?;

        match package.find(&repo) {
            Some(refspec) => {
                debug!("found with refspec {}", refspec);

                pb.finish();

                match find_package_tag(package, &repo, &refspec)? {
                    Some(tag_name) => {
                        println!(
                            "    Found:\n      {}{}\n    in:\n      {}\n    at refspec:\n      {}\n    tagged as:\n      {}",
                            mkpm::style::package_name(package.name()),
                            mkpm::style::package_extension(&String::from(".tar.gz")),
                            mkpm::style::remote_url(&remote),
                            mkpm::style::refspec(&refspec),
                            mkpm::style::refspec(&tag_name.replace("refs/tags/", "")),
                        );
                        return Ok((repo, tag_name));
                    }
                    None => {
                        println!(
                            "    Found:\n      {}{}\n    in:\n      {}\n    at refspec:\n      {}",
                            mkpm::style::package_name(package.name()),
                            mkpm::style::package_extension(&String::from(".tar.gz")),
                            mkpm::style::remote_url(&remote),
                            mkpm::style::refspec(&refspec),
                        );

                        return Ok((repo, refspec));
                    }
                }
            }
            None => {
                debug!("revision not found, skipping to next repository");
                continue;
            }
        };
    }

    debug!("all repositories have been searched");

    Err(CommandError::NoMatchingVersionError {
        package: package.clone(),
    })
}

fn find_package_tag(
    package: &Package,
    repo: &git2::Repository,
    refspec: &String,
) -> Result<Option<String>, CommandError> {
    let mut builder = git2::build::CheckoutBuilder::new();
    builder.force();
    repo.set_head(&refspec)?;
    repo.checkout_head(Some(&mut builder))?;

    if package.archive_is_in_repository(&repo) {
        debug!("package archive found in refspec {}", &refspec);

        let package_commit_id = find_last_commit_id(&package.get_archive_path(None), &repo)
            .map_err(CommandError::GitError)?;

        match commit_to_tag_name(&repo, &package_commit_id).map_err(CommandError::GitError)? {
            Some(tag_name) => {
                return Ok(Some(format!("refs/tags/{}", tag_name)));
            }
            // every published package version should be tagged, so this match should "never" happen...
            None => (),
        }
    }

    return Ok(None);
}

pub fn get_sources_from_mkpm(
    mkpm_path: std::path::PathBuf,
) -> Result<std::vec::Vec<String>, CommandError> {
    let mkpm_file = fs::File::open(mkpm_path)?;
    let mut sources_str = String::new();
    let sources_start_re = regex::Regex::new(r"^MKPM_SOURCES\s+:=(\s+|$)").unwrap();
    let line_wrap_re = regex::Regex::new(r"\\\s*$").unwrap();
    let mut sources_match = false;
    for line in io::BufReader::new(mkpm_file).lines() {
        let line = String::from(line.unwrap().trim());
        let mut sources_str_chunk = String::from(&line);
        if line_wrap_re.is_match(&line) {
            sources_str_chunk = String::from(line_wrap_re.replace(&line, "").trim());
        }
        if sources_start_re.is_match(&line) {
            sources_match = true;
            sources_str_chunk =
                String::from(sources_start_re.replace(&sources_str_chunk, "").trim());
            sources_str = String::from(
                [sources_str, String::from(" "), sources_str_chunk]
                    .concat()
                    .trim(),
            );
        } else if sources_match {
            match line.chars().last() {
                Some(c) => {
                    if c == '\\' {
                        sources_str = String::from(
                            [sources_str, String::from(" "), sources_str_chunk]
                                .concat()
                                .trim(),
                        );
                    } else {
                        sources_str = String::from(
                            [sources_str, String::from(" "), sources_str_chunk]
                                .concat()
                                .trim(),
                        );
                        sources_match = false;
                    }
                }
                None => sources_match = false,
            }
        }
    }
    let mut sources = std::vec::Vec::new();
    for source in sources_str.clone().split(" ") {
        sources.push(String::from(source));
    }
    Ok(sources)
}

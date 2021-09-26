use std::fs;
use std::io;
use std::path;

use std::io::prelude::*;

use tar::Archive;

use indicatif::{ProgressBar, ProgressStyle};

pub fn get_or_init_dot_gpm_dir() -> Result<path::PathBuf, io::Error> {
    let dot_gpm = dirs::home_dir().unwrap().join(".gpm");

    if !dot_gpm.exists() {
        return match fs::create_dir_all(&dot_gpm) {
            Ok(()) => Ok(dot_gpm),
            Err(e) => Err(e)
        }
    }

    Ok(dot_gpm)
}

pub fn get_or_init_cache_dir() -> Result<path::PathBuf, io::Error> {
    let dot_gpm = get_or_init_dot_gpm_dir()?;
    let cache = dot_gpm.join("cache");

    if !cache.exists() {
        return match fs::create_dir_all(&cache) {
            Ok(()) => Ok(cache),
            Err(e) => Err(e)
        }
    }

    Ok(cache)
}

pub fn extract_package(
    path : &path::Path,
    prefix : &path::Path,
    force : bool
) -> Result<(u32, u32), io::Error> {
    debug!("attempting to extract package archive {} in {}", path.display(), prefix.display());

    if !prefix.exists() && force {
        debug!("--force is used: creating missing path {:?}", prefix);
        fs::create_dir_all(prefix).expect("unable to create directory");
    }

    let pb = ProgressBar::new(0);
    pb.set_style(ProgressStyle::default_spinner()
        .template("{spinner:.green} [{elapsed_precise}] {wide_msg}"));
    pb.set_message("Decompressing archive...");
    pb.enable_steady_tick(200);

    let compressed_file = fs::File::open(&path)?;
    let mut file = tempfile::tempfile().unwrap();

    {
        let mut writer = io::BufWriter::new(&file);
        let reader = io::BufReader::new(&compressed_file);
        let mut decoder = flate2::read::GzDecoder::new(reader);

        debug!("start decoding {} in temporary file", path.display());

        io::copy(&mut decoder, &mut writer).unwrap();

        debug!("{} decoded", path.display());
    }

    pb.finish_with_message("Archive decompressed");

    debug!("start extracting archive into {}", prefix.display());

    file.seek(io::SeekFrom::Start(0))?;

    let mut num_extracted_files = 0;
    let mut num_files = 0;
    let reader = io::BufReader::new(&file);
    let mut ar = Archive::new(reader);
    let entries = ar.entries().unwrap();

    let pb = ProgressBar::new(num_files as u64);
    pb.set_style(ProgressStyle::default_spinner()
        .template("  [{elapsed_precise}] {pos} {wide_msg}"));
    pb.set_message("extracted files");
    pb.enable_steady_tick(200);

    for file in entries {
        let mut file = file.unwrap();
        let path = prefix.to_owned().join(file.path().unwrap());

        num_files += 1;

        if path.exists() {
            if !force {
                warn!(
                    "{:?} not extracted: path already exist, use --force to override\n",
                    path
                );
                continue;
            }

            debug!("{} already exists and --force in use: removing", &path.display());
            if path.is_dir() {
                fs::remove_dir_all(&path)?;
            } else {
                fs::remove_file(&path)?;
            }
        }

        file.unpack_in(prefix)?;

        debug!(
            "extracted file {} ({} bytes)",
            path.display(),
            file.header().size().unwrap(),
        );

        num_extracted_files += 1;

        pb.inc(1);
    }

    pb.set_style(ProgressStyle::default_spinner()
        .template("  [{elapsed_precise}] {wide_msg}"));
    pb.finish_with_message(format!("{}/{} extracted file(s)", num_extracted_files, num_files));

    // info!("extracted {}/{} file(s)", num_extracted_files, num_files);

    Ok((num_files, num_extracted_files))
}

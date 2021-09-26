/**
 * File: /build.rs
 * Project: mkpm
 * File Created: 26-09-2021 00:17:17
 * Author: Clay Risser
 * -----
 * Last Modified: 26-09-2021 00:27:46
 * Modified By: Clay Risser
 * -----
 * Copyright (c) 2018 Aerys
 *
 * MIT License
 */
extern crate anyhow;
extern crate vergen;

use anyhow::Result;
use vergen::{vergen, Config};

fn main() -> Result<()> {
  // Generate the default 'cargo:' instruction output
  vergen(Config::default())
}

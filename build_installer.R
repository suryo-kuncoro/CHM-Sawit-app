# build_installer.R
# Dijalankan di GitHub Actions (windows-latest) untuk membuat installer .exe
# yang membundel R portable + semua package yang dibutuhkan aplikasi Shiny.

if (!requireNamespace("RInno", quietly = TRUE)) {
  # Pasang dependency RInno lebih dulu agar resolusi dependency dari tarball lokal tidak gagal
  rinno_deps <- c(
    "curl", "glue", "httr", "installr", "jsonlite",
    "magrittr", "pkgbuild", "remotes", "rmarkdown", "shiny", "stringr"
  )
  missing_deps <- rinno_deps[!vapply(rinno_deps, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_deps) > 0) install.packages(missing_deps)

  # RInno dicabut dari CRAN per 2025-06-12, tapi versi arsipnya masih valid & terpasang baik.
  # Install langsung dari tarball arsip CRAN (menghindari GitHub API / rate limit).
  install.packages(
    "https://cran.r-project.org/src/contrib/Archive/RInno/RInno_1.0.1.tar.gz",
    repos = NULL,
    type  = "source"
  )
}

library(RInno)

# Pastikan Inno Setup terpasang di runner
install_inno()

create_app(
  app_name = "CHM Sawit",
  app_dir  = "app",
  dir_out  = "build_installer",
  pkgs = c(
    "shiny", "terra", "lidR", "sf", "rlas"
  ),
  include_R = TRUE,
  R_version = paste0(R.version$major, ".", R.version$minor),
  privilege = "lowest",
  info_text = "Kalkulator Tinggi Kanopi Sawit dari data LiDAR atau Fotogrametri. Dibuat oleh Suryo Kuncoro."
)

compile_iss()

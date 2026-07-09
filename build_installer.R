# build_installer.R
# Dijalankan di GitHub Actions (windows-latest) untuk membuat installer .exe
# yang membundel R portable + semua package yang dibutuhkan aplikasi Shiny.

if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("RInno", quietly = TRUE)) remotes::install_github("ficonsulting/RInno")

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

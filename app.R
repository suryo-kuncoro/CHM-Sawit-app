library(shiny)
library(terra)
library(lidR)

# ---- UI ----------------------------------------------------------------

ui <- fluidPage(
  titlePanel("Kalkulator Tinggi Kanopi Sawit — CHM Generator"),

  sidebarLayout(
    sidebarPanel(
      radioButtons(
        "mode", "Sumber Data",
        choices = c(
          "LiDAR (point cloud .las / .laz)" = "lidar",
          "Fotogrametri (DSM + DTM GeoTIFF)" = "foto"
        )
      ),

      conditionalPanel(
        condition = "input.mode == 'lidar'",
        fileInput("las_file", "Upload point cloud (.las / .laz)",
                   accept = c(".las", ".laz")),
        selectInput("ground_algo", "Algoritma klasifikasi ground",
                     choices = c("Cloth Simulation Filter (CSF)" = "csf",
                                 "Progressive Morphological Filter (PMF)" = "pmf")),
        numericInput("subcircle", "Subcircle radius CHM (m)", value = 0.15, min = 0, step = 0.05)
      ),

      conditionalPanel(
        condition = "input.mode == 'foto'",
        fileInput("dsm_file", "Upload DSM (GeoTIFF)", accept = c(".tif", ".tiff")),
        fileInput("dtm_file", "Upload DTM (GeoTIFF)", accept = c(".tif", ".tiff"))
      ),

      hr(),
      numericInput("res", "Resolusi CHM (meter/piksel)", value = 0.5, min = 0.1, step = 0.1),
      numericInput("max_height", "Batas tinggi maksimum wajar (m) — filter noise", value = 35, min = 1),
      numericInput("min_height", "Nilai di bawah ini dianggap tanah/noise (m)", value = 0.5, min = 0),

      hr(),
      actionButton("run", "Proses CHM", icon = icon("play"), class = "btn-primary"),

      hr(),
      uiOutput("download_ui")
    ),

    mainPanel(
      plotOutput("chm_plot", height = "520px"),
      verbatimTextOutput("log")
    )
  )
)

# ---- SERVER --------------------------------------------------------------

server <- function(input, output, session) {

  chm_result <- reactiveVal(NULL)
  log_text <- reactiveVal("Menunggu data diproses...")

  observeEvent(input$run, {

    result <- tryCatch({

      if (input$mode == "lidar") {

        req(input$las_file)
        log_text(paste0("Membaca point cloud: ", input$las_file$name, " ...\n"))

        las <- readLAS(input$las_file$datapath)
        if (is.empty(las)) stop("File LAS/LAZ kosong atau gagal dibaca.")

        log_text(paste0(log_text(), "Mengklasifikasikan titik tanah (", input$ground_algo, ") ...\n"))
        algo <- if (input$ground_algo == "csf") csf() else pmf(ws = 5, th = 3)
        las <- classify_ground(las, algo)

        log_text(paste0(log_text(), "Menormalisasi tinggi terhadap tanah (TIN) ...\n"))
        las_norm <- normalize_height(las, tin())

        log_text(paste0(log_text(), "Membuat raster CHM resolusi ", input$res, " m ...\n"))
        chm <- rasterize_canopy(
          las_norm,
          res = input$res,
          algorithm = p2r(subcircle = input$subcircle)
        )

        chm

      } else {

        req(input$dsm_file, input$dtm_file)
        log_text("Membaca DSM & DTM ...\n")

        dsm <- rast(input$dsm_file$datapath)
        dtm <- rast(input$dtm_file$datapath)

        if (crs(dsm) != crs(dtm)) {
          log_text(paste0(log_text(), "CRS DSM & DTM berbeda — DTM diproyeksikan ulang mengikuti DSM ...\n"))
          dtm <- project(dtm, dsm)
        }

        log_text(paste0(log_text(), "Menyamakan grid DTM terhadap DSM (resample) ...\n"))
        dtm_r <- resample(dtm, dsm, method = "bilinear")

        log_text(paste0(log_text(), "Menghitung CHM = DSM - DTM ...\n"))
        chm <- dsm - dtm_r

        target_res <- input$res
        if (target_res > res(chm)[1]) {
          log_text(paste0(log_text(), "Resampling CHM ke resolusi ", target_res, " m ...\n"))
          fact <- target_res / res(chm)[1]
          chm <- aggregate(chm, fact = fact, fun = "mean")
        }

        chm
      }

    }, error = function(e) {
      log_text(paste0(log_text(), "\nGAGAL: ", conditionMessage(e)))
      NULL
    })

    if (!is.null(result)) {
      chm <- result
      names(chm) <- "CHM"

      # bersihkan nilai tidak wajar
      chm[chm < input$min_height] <- 0
      chm[chm > input$max_height] <- NA

      chm_result(chm)
      log_text(paste0(
        log_text(),
        "\nSelesai. Tinggi rata-rata: ", round(as.numeric(global(chm, "mean", na.rm = TRUE)), 2), " m",
        " | Tinggi maksimum: ", round(as.numeric(global(chm, "max", na.rm = TRUE)), 2), " m"
      ))
    }
  })

  output$log <- renderText({ log_text() })

  output$chm_plot <- renderPlot({
    req(chm_result())
    plot(chm_result(), main = "Canopy Height Model (CHM)", col = terrain.colors(50))
  })

  output$download_ui <- renderUI({
    req(chm_result())
    downloadButton("download_chm", "Unduh CHM (GeoTIFF)", class = "btn-success")
  })

  output$download_chm <- downloadHandler(
    filename = function() paste0("CHM_sawit_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".tif"),
    content = function(file) {
      writeRaster(chm_result(), file, overwrite = TRUE, filetype = "GTiff")
    }
  )
}

shinyApp(ui, server)

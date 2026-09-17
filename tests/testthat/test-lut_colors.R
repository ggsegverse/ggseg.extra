colourless_lut <- function(labels, idx = seq_along(labels)) {
  n <- length(labels)
  data.frame(
    idx = as.integer(idx),
    label = labels,
    R = rep(0L, n),
    G = rep(0L, n),
    B = rep(0L, n),
    A = rep(0L, n),
    stringsAsFactors = FALSE
  )
}

lut_hex <- function(lut) {
  grDevices::rgb(lut$R, lut$G, lut$B, maxColorValue = 255)
}

describe("lut_generate_colors()", {
  it("fills every colour channel and leaves alpha at zero", {
    lut <- lut_generate_colors(colourless_lut(c("A_left", "B_left")))

    expect_false(any(lut$R == 0L & lut$G == 0L & lut$B == 0L))
    expect_equal(lut$A, rep(0L, 2))
    expect_equal(lut$label, c("A_left", "B_left"))
  })

  it("gives a structure's two hemispheres the same colour", {
    lut <- lut_generate_colors(
      colourless_lut(c(
        "Hippocampus_left",
        "Hippocampus_right",
        "Amygdala_left",
        "Amygdala_right"
      ))
    )
    hex <- lut_hex(lut)

    expect_equal(hex[1], hex[2])
    expect_equal(hex[3], hex[4])
    expect_false(hex[1] == hex[3])
  })

  it("recognises the hemisphere spellings FreeSurfer's own tables use", {
    pairs <- list(
      c("Left-Hippocampus", "Right-Hippocampus"),
      c("ctx-lh-bankssts", "ctx-rh-bankssts"),
      c("wm_lh_precentral", "wm_rh_precentral"),
      c("lh_superiorfrontal", "rh_superiorfrontal"),
      c("Caudate_LEFT", "Caudate_RIGHT"),
      c("Putamen-lh", "Putamen-rh")
    )

    for (pair in pairs) {
      hex <- lut_hex(lut_generate_colors(colourless_lut(pair)))
      expect_equal(hex[1], hex[2], info = pair[1])
    }
  })

  it("leaves a label with no hemisphere marker as a structure of its own", {
    hex <- lut_hex(lut_generate_colors(colourless_lut(c("Brain-Stem", "CSF"))))

    expect_false(hex[1] == hex[2])
  })

  it("does not let the first and last hue collide", {
    n <- 4L
    lut <- lut_generate_colors(
      colourless_lut(paste0("s", seq_len(n))),
      luminance = c(45, 65, 82)
    )
    hex <- lut_hex(lut)

    expect_equal(length(unique(hex)), n)
    expect_false(hex[1] == hex[n])
  })

  it("cycles luminance so that neighbouring hues separate", {
    lut <- lut_generate_colors(
      colourless_lut(paste0("s", 1:6)),
      luminance = c(45, 65, 82)
    )
    luminances <- grDevices::convertColor(
      t(grDevices::col2rgb(lut_hex(lut))) / 255,
      from = "sRGB",
      to = "Lab"
    )[, "L"]

    expect_equal(as.numeric(luminances), rep(c(45, 65, 82), 2), tolerance = 0.5)
  })

  it("gives each `by` group the whole colour circle", {
    lut <- colourless_lut(paste0("s", 1:4))
    lut$type <- c("cortical", "cortical", "subcortical", "subcortical")

    grouped <- lut_hex(lut_generate_colors(lut, by = "type"))
    ungrouped <- lut_hex(lut_generate_colors(lut))

    expect_equal(grouped[1:2], grouped[3:4])
    expect_equal(anyDuplicated(ungrouped), 0L)
  })

  it("catches the colours hcl() clips out of gamut without saying so", {
    many <- colourless_lut(paste0("s", seq_len(500)))

    expect_error(
      lut_generate_colors(many),
      "Cannot give 500 structures a colour of its own"
    )
    expect_error(lut_generate_colors(many), "clips out-of-gamut")
    expect_equal(
      anyDuplicated(lut_hex(lut_generate_colors(many, chroma = 40))),
      0L
    )
  })

  it("leaves the background row alone", {
    lut <- colourless_lut(
      c("Unknown", "Hippocampus_left", "Hippocampus_right"),
      idx = c(0L, 1L, 2L)
    )
    coloured <- lut_generate_colors(lut)
    channels <- c("R", "G", "B", "A")

    expect_equal(coloured[1, channels], lut[1, channels])
    expect_false(any(coloured[2:3, c("R", "G", "B")] == 0L))
  })

  it("does not ask the background row for a `by` group", {
    lut <- colourless_lut(c("Unknown", "Hippocampus"), idx = c(0L, 1L))
    lut$type <- c(NA_character_, "subcortical")

    expect_no_error(lut_generate_colors(lut, by = "type"))
  })

  it("hands back a table of nothing but background unchanged", {
    lut <- colourless_lut("Unknown", idx = 0L)

    expect_equal(lut_generate_colors(lut), lut)
  })

  it("errors on a table that is not a lookup table", {
    expect_error(
      lut_generate_colors(data.frame(x = 1)),
      "must be a lookup table"
    )
  })

  it("errors when `by` does not name a column", {
    expect_error(
      lut_generate_colors(colourless_lut("a"), by = "type"),
      "must name a column"
    )
  })

  it("validates `by` even when there is nothing to colour", {
    expect_error(
      lut_generate_colors(colourless_lut("Unknown", idx = 0L), by = "type"),
      "must name a column"
    )
  })

  it("errors when a structure has no group", {
    lut <- colourless_lut(c("a", "b"))
    lut$type <- c("cortical", NA_character_)

    expect_error(lut_generate_colors(lut, by = "type"), "missing values")
  })

  it("errors on a row with no label", {
    lut <- colourless_lut(c("a", NA_character_))

    expect_error(lut_generate_colors(lut), "no label")
  })

  it("errors on chroma or luminance outside the range hcl() accepts", {
    lut <- colourless_lut("a")

    expect_error(lut_generate_colors(lut, chroma = c(1, 2)), "single number")
    expect_error(lut_generate_colors(lut, chroma = -300), "between 0 and 360")
    expect_error(lut_generate_colors(lut, chroma = Inf), "between 0 and 360")
    expect_error(
      lut_generate_colors(lut, luminance = c(-50, 400)),
      "between 0 and 100"
    )
    expect_error(
      lut_generate_colors(lut, luminance = NA_real_),
      "between 0 and 100"
    )
  })
})

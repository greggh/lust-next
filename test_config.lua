return {
  parallel = {
    workers = 2,
    timeout = 30,
    verbose = true
  },
  format = {
    use_color = false,
    default_format = "dot"
  },
  async = {
    timeout = 2000
  },
  coverage = {
    threshold = 90,
    discover_uncovered = true,
    debug = false
  },
  quality = {
    level = 3,
    strict = true
  }
}

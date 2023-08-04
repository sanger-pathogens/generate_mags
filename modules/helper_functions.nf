def validate_parameters () {
    if (!params.manifest) {
        log.error("Please specify a manifest using the --manifest option")
    }
}
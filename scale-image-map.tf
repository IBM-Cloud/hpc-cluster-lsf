# This mapping file has entries for scale storage node images.
locals {
  scale_image_region_map = {
    "hpcc-scale5151-rhel84" = {
      "eu-de"    = "r010-628122a3-a86d-4963-9095-a18744a69ce0"
      "us-east"  = "r014-0a08b24d-c104-44da-891d-79ee7e2b1094"
      "us-south" = "r006-1b6dfe5d-d931-4c2a-857f-0e77b9113def"
      "jp-tok"   = "r022-ec1909f5-c451-4bcc-967e-354ce287b351"
      "eu-gb"    = "r018-df9491c5-329c-49ba-b95c-29b643fa175a"
      "jp-osa"   = "r034-e61a3415-6dea-4595-a7a3-cccce2c75855"
      "ca-tor"   = "r038-22c92687-b8d5-4fc5-b5b9-335db41f85e4"
      "au-syd"   = "r026-bb754d5d-7461-4b0e-a43b-f9d2834e03a9"
      "br-sao"   = "r042-df7f7ed8-3424-450f-a9a9-539454831ac6"
    }
  }
}
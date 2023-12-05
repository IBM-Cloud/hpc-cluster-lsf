# This mapping file has entries for scale storage node images.
locals {
  scale_image_region_map = {
    "hpcc-scale5190-rhel88" = {
      "eu-gb"    = "r018-c5ae35fb-0c03-4321-a8b0-f8059ac85958"
      "eu-de"    = "r010-648cdd71-864c-44a3-9f89-f7e2016ee03b"
      "us-east"  = "r014-c4e311f4-e456-4150-a6b4-2801276f3621"
      "us-south" = "r006-03d541b0-9036-4bf2-a8c5-588b7415742b"
      "jp-tok"   = "r022-91e379ad-17e8-415b-b9db-029149e03460"
      "jp-osa"   = "r034-ea039080-885b-44cb-8665-244e8bce9d6a"
      "au-syd"   = "r026-d282afc4-5dfd-41e5-a859-e84b49641531"
      "br-sao"   = "r042-799c1df2-b966-481a-a100-17727be19328"
      "ca-tor"   = "r038-17499e7e-3a7a-4c9e-85ab-149ff604c66f"
    }
  }
}
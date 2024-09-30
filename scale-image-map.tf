# This mapping file has entries for scale storage node images.
locals {
  scale_image_region_map = {
    "hpcc-scale5201-rhel88" = {
      "eu-gb"     = "r018-a557df4a-549f-4000-bd4c-56fa8f5512dc"
      "eu-de"     = "r010-c5dec858-162f-43dd-80b0-6c9bd5add75c"
      "us-east"   = "r014-1be5173b-cc5a-4381-9f41-05e408268a7d"
      "us-south"  = "r006-25f14ed9-04c2-4f44-8501-1b44c6a7017d"
      "jp-tok"    = "r022-26f9f53e-ff97-43dc-a9f3-f2751f5e1ca9"
      "jp-osa"    = "r034-54eb476b-b3eb-4ab5-9021-b0c28ce6b029"
      "au-syd"    = "r026-5d849a3c-d5a8-417f-b446-c73448e2dc25"
      "br-sao"    = "r042-2a70e75b-8096-4935-9807-3481cd40dd67"
      "ca-tor"    = "r038-d7f70caf-4c95-4faa-8b2f-8f9b9c7f5713"
    }
  }
}